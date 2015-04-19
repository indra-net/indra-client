$ = require 'jquery'
Bacon = require 'baconjs'

##
##    YOU HAVE TO `RY` BEFORE YOU CAN `DRY`
##
#
# --- config
config = 
	## network
	localServerUrl: 'http://localhost:5000'
	timeServerUrl: 'http://indra.webfactional.com/'
	dataCollectionServerUrl: 'http://indra.webfactional.com/collect/'
	## time
	updateTimeInterval: 3000 # how often we want to check our time against server time
	pollLocalClockInterval: 300 # how often we poll our local clock
	tryToPairInterval: 20000 # ms to wait before we try to pair again
	signalFreshnessThreshold: 3 # seconds to wait, after receiving our last reading, before we decide that our mindwave signal has gone stale


sockets = require './lib/sockets.coffee'
login_view = require './lib/login_view.coffee'
statusView = require './lib/status_view.coffee'
clockView = require './lib/clock_view.coffee'
getMindwaveStatusProperty = require './lib/getMindwaveStatusProperty.coffee'
getIndraTimeProperty = require './lib/getIndraTimeProperty.coffee'
postJson = require './lib/postJson.coffee'


isValue = (v, value) -> if v == value then true else false
isTruthy = (item) -> if item then true else false
isFalsy = (item) -> if !item then true else false

setupUserIdView = (id, $idDiv) ->
	# store the user ID in a backbone model
	$idDiv.html(id)

incrementPostCounter = (currentPostCount) ->
	postCount = currentPostCount+1
	$('#postCounter').html(postCount)
	postCount


# starts pairing with device
# shows the main, status interface
setId = (id) ->
	# set user ID (model+view)
	setupUserIdView(id, $('#userId'))

init = ->


	#
	# local mwm device communications
	#

	# socket with the local python server
	localServerSocket = sockets.setup(config.localServerUrl)
	# dataStream is a Bacon stream of mindwave data
	# we get the data over a websocket connction to the server.
	mindwaveDataStream = Bacon.fromEventTarget(localServerSocket, 'data')
	# a stream of the local server's attempts to pair with the mindwave
	localServerMessages = Bacon.fromEventTarget(localServerSocket, 'pairing')

	# make a property representing the current status of the local MWM server
	mindwaveStatusProperty = getMindwaveStatusProperty(mindwaveDataStream, localServerMessages, config.signalFreshnessThreshold)
		# (skip duplicate statuses)
		.skipDuplicates()
	mindwaveStatusProperty.log('mindwave status: ')

	

	#
	# synchronised 'indra time'
	#

	# this (moment.js) property updates on pollClockInterval
	# before we hear anything from the server, it is `null`
	# (before we've synced with indra, this value is null)
	indraTimeProperty = getIndraTimeProperty(
		config.timeServerUrl
		, config.updateTimeInterval
		, config.pollLocalClockInterval)
		# ignore null values
		.filter(isTruthy)

	# update the clock
	indraTimeProperty
		.onValue(clockView.setup)



	#
	# 'login'/join interface
	#

	# display the status screen
	$statusDiv = $('#statusDiv')
	statusView.setup(mindwaveStatusProperty, $statusDiv)
	# but hide it for now
	$statusDiv.hide()

	# initialially, the view is the login view
	$loginDiv = $('#loginDiv')
	idSubmissionStream = login_view.setup($loginDiv)

	# on submit button click, 
	idSubmissionStream
		# set the user's id
		# and show the mw status screen
		.onValue((id) -> 
			setId(id)
			$loginDiv.hide()
			$statusDiv.show())


	# property represetning the user's id choice
	userIdProp = idSubmissionStream.toProperty(null)



	#
	# sending 'pair' messages to mwm
	#

	pairRequests = new Bacon.Bus()

	pairRequests.onValue((v)->
		console.log('pairing to device now')
		# request that the local server pair with the device
		localServerSocket.emit('pair'))

	# whenever we get a 'not paired' status
	mindwaveStatusProperty.filter((v)->isValue(v,'notPaired'))
		.onValue(()-> 
			# send a pair request
			pairRequests.push(1)
			# and send a pair request every tryToPairInterval
			# , until we get a good signal
			Bacon.interval(config.tryToPairInterval)
				.takeWhile(
					# take while status == 'pairing'
					mindwaveStatusProperty.map((v) -> isValue(v,'pairing')))
				# if we're still 'pairing' by now, re-emit pair request
				.onValue(()->pairRequests.push(1)))



	#
	# posting mwm data to collection server
	#

	postCount = 0

	dataToPost = Bacon.combineTemplate({
 		id: userIdProp
 		reading: mindwaveDataStream })

	dataToPost
		.sampledBy(mindwaveDataStream)
		.onValue((data) -> 
			# post json to to server
			postJson(
				data
				, config.dataCollectionServerUrl
				# success cb
				, ()->console.log 'posted ok')
			# update our counter of post requests made
			# side effect: update counter view
			postCount = incrementPostCounter(postCount))


# launch the app
$(document).ready(() ->
	init()
	console.log 'app launched ok')