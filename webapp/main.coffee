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
	console.log('incrementing')
	postCount = currentPostCount+1
	$('#postCounter').html(postCount)
	postCount



# starts pairing with device
# shows the main, status interface
logInToLocalServer = (localServerSocket, id, mindwaveStatusProperty) ->

	# request that the local server pair with the device
	localServerSocket.emit('pair', id)

	# set user ID (model+view)
	setupUserIdView(id, $('#userId'))

	# display the status screen
	# we pass it a Bacon Bus (pairAgain..)
	# pushing to this will pair us with mindwave again
	statusView.setup(mindwaveStatusProperty)

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
	mindwaveStatusProperty = getMindwaveStatusProperty(mindwaveDataStream, localServerMessages)
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

	loginAndPairFn = (userId) -> 
		console.log 'starting pairing routine!', userId
		logInToLocalServer(
			localServerSocket
			, userId
			, mindwaveStatusProperty)

	# initialially, the view is the login view
	idSubmissionStream = login_view.setup()
	# on submit button click, 
	idSubmissionStream
		.onValue((id) -> 
			loginAndPairFn(id))

	# property represetning the user's id choice
	userIdProp = idSubmissionStream.toProperty(null)



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