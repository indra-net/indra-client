$ = require 'jquery'
Bacon = require 'baconjs'
moment = require 'moment'

sockets = require './lib/sockets.coffee'
userData = require('./lib/models.coffee').userData()
login_view = require './lib/login_view.coffee'
statusView = require './lib/status_view.coffee'
connectingView = require './lib/connecting_view.coffee'

isTruthy = (item) -> if (item) then true else false
isSignalGood = (data) -> if data['signal_quality'] == 0 then true else false
differenceInSeconds = (earlier, later) -> moment(later).diff(earlier, 's')
# reading is 'stale' if we haven't gotten a reading in more than 15s
isSignalFresh = (reading_time, now) -> 
	reading_time = new Date(reading_time)
	# to be timezone-safe, lets set the day+hour of whatehver reading we get to our day+hour
	reading_time.setDate(now.getDate())
	reading_time.setHours(now.getHours())
	differenceInSeconds(reading_time, now) < 15

init = ->

	socket = sockets.setup()

	# dataStream is a Bacon stream of mindwave data
	# we get the data over a websocket connction to the server.
	dataStream = Bacon.fromEventTarget(socket, 'data')

	# initialially, the view is the login view
	idSubmissionStream = login_view.setup()
	# on submit button click, 
	idSubmissionStream.onValue((v) ->
			# send a message to the server to connect to mindwave
			socket.emit('connect', v)
			# store the user ID and electrode position in our backbone model
			userDataModel.setUserId(v)
			# display the connection screen
			connectingView.setup())

	# as soon as we get our first mwm data,
	# switch to recorder view 
	dataStream
		.take(1)
		.onValue(() -> statusView.setup())

	# current mindwave data at any given time
	mindwaveDataProp = dataStream.toProperty(false)

	# stream of bools epresenting whether or not the signal is good 
	# values: true (good signal) / false (bad signal)
	isSignalGoodStream = dataStream.map(isSignalGood)

	# stream of bools representing whether or not the signal is fresh
	isSignalFreshStream = mindwaveDataProp
		.sampledBy(Bacon.interval(1000))
		.filter((v) -> 
			isTruthy(v))
		.map((v) -> 
			isSignalFresh(
				v.reading_time
				, new Date()))
		

	console.log 'app launched.'

# launch the app
$(document).ready(() ->
	init() )