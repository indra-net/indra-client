$ = require 'jquery'
Bacon = require 'baconjs'

config = 

	## network
	localSocketServerUrl: 'http://localhost:5000'
	timeServerUrl: 'http://indra.webfactional.com/timeserver'
	dataCollectionServerUrl: 'http://indra.webfactional.com/'
	# adminStatusServerURL: 'http://indra.webfactional.com/status'

	## time
	updateTimeInterval: 3000 # how often we want to check our time against server time
	pollLocalClockInterval: 300 # how often we poll our local clock
	tryToPairInterval: 20000 # ms to wait before we try to pair again
	signalFreshnessThreshold: 3 # seconds to wait, after receiving our last reading, before we decide that our mindwave signal has gone stale


localSocketServer = require './lib/localSocketServer.coffee'
login_view = require './lib/login_view.coffee'
statusView = require './lib/status_view.coffee'
clockView = require './lib/clock_view.coffee'
getMindwaveStatusProperty = require './lib/getMindwaveStatusProperty.coffee'
syncedTime = require './lib/syncedTime.coffee'
postJson = require './lib/postJson.coffee'


isValue = (v, value) -> if v == value then true else false
isTruthy = (item) -> if item then true else false
isFalsy = (item) -> if !item then true else false
count = (acc, curr) -> acc + 1


setupUserIdView = (id, $idDiv) ->
	# store the user ID in a backbone model
	$idDiv.html(id)


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
	localServerSocket = localSocketServer.setup(config.localSocketServerUrl)
	# dataStream is a Bacon stream of mindwave data
	# we get the data over a websocket connction to the server.
	mindwaveDataStream = Bacon.fromEventTarget(localServerSocket, 'data')
	# a stream of the local server's attempts to pair with the mindwave
	localServerMessages = Bacon.fromEventTarget(localServerSocket, 'pairing')
	# make a property representing the current status of the local MWM server
	mindwaveStatusProperty = getMindwaveStatusProperty(mindwaveDataStream, localServerMessages, config.signalFreshnessThreshold)
		# (skip duplicate statuses)
		.skipDuplicates()

	# debug
	# mindwaveStatusProperty.log('mindwave status: ') 

	

	#
	# synchronised 'indra time'
	#

	# a stream of time differences 
	# TODO: sank.getTimeDiffStream
	timeDiffStream = syncedTime.getTimeDiffStream(
		config.timeServerUrl
		, config.updateTimeInterval)
		# (before we've synced with indra, this value is null)
		.filter(isTruthy)

	# this (moment.js) property updates on pollClockInterval
	# TODO: sank.getSynchronisedTime
	indraTimeProperty = syncedTime.getSynchronisedTimeProperty(
		timeDiffStream
		, config.pollLocalClockInterval)

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
	userIdProp = idSubmissionStream.toProperty('unnamed')
	userIdProp.onValue((v) -> id = v)



	#
	# sending 'pair' messages to mwm
	#

	pairRequests = new Bacon.Bus()

	pairRequests.onValue((v)->
		# debug
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

	dataToPost = Bacon.combineTemplate({
 		user_id: userIdProp
 		type: "mindwave"
 		# our best guess at the server's time
 		indra_time: indraTimeProperty
 		# the last observed latency (difference between our clock and indra)
 		browser_latency: timeDiffStream
 		# the mindwave data
 		reading: mindwaveDataStream })

	#post the data whenever there's a mindave data event
	
	#NB: we post things without checking if time, user ID, or reading are ok
	#if time is null, user id is null, they can figure that out later! log everything!
	dataToPost
		.sampledBy(mindwaveDataStream.filter(isTruthy))
		.onValue((data) -> 
			# post json to to server
			console.log 'posting', data
			postJson(
				data
				, config.dataCollectionServerUrl
				# success cb
				, ()->console.log 'posted ok' ))

	# update our counter of post requests made
	postCount = dataToPost
		.sampledBy(mindwaveDataStream.filter(isTruthy))
		.scan(0, count)
	# + update counter view
	postCount.onValue((count) -> $('#postCounter').html(count))


	#
	# teardown
	#
	# watch out for the sneaky user trying to close the window and leave our app ever
	window.onbeforeunload = (e) ->
		e = e || window.event
		# for IE / Firefox prior to version 4
		if (e)
		    e.returnValue = 'Sure?'
		# for Safari
		return 'Sure?'

# launch the app
$(document).ready(() ->
	init()
	console.log 'app launched ok')
