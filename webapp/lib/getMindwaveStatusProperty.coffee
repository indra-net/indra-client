Bacon = require 'baconjs'
moment = require 'moment'

isTruthy = (item) -> if item then true else false
isFalsy = (item) -> if !item then true else false

isSignalGood = (data) -> if data['signal_quality'] == 0 then true else false

differenceInSeconds = (earlier, later) -> moment(later).diff(earlier, 's')

# reading is 'stale' if we haven't gotten a reading in more than 5s
isSignalFresh = (reading_time, now) -> 
	reading_time = new Date(reading_time)
	# to be timezone-safe, lets set the day+hour of whatehver reading we get to our day+hour
	reading_time.setDate(now.getDate())
	reading_time.setHours(now.getHours())
	differenceInSeconds(reading_time, now) < 5 


# takes a socket , returns a status stream
# the stream's values can be:
#	notPaired
#	pairing
#	paired
#	poorSignalQuality

getMindwaveStatusProperty = (mindwaveDataStream, localServerMessages) -> 

	# mindwave data at any given time
	mindwaveDataProp = mindwaveDataStream.toProperty(false)

	# stream of bools epresenting whether or not the signal is good 
	# values: true (good signal) / false (bad signal)
	isSignalGoodStream = mindwaveDataStream.map(isSignalGood)

	# stream of bools representing whether or not the signal is fresh
	isSignalFreshStream = mindwaveDataProp
		.sampledBy(Bacon.interval(3000))
		.filter(isTruthy)
		.map((v) -> 
			isSignalFresh(
				v.reading_time
				, new Date()))

	signalIsStaleStream = isSignalFreshStream
		.filter(isFalsy)
		.map('notPaired')
	# TODO throttle this one so we don't drive the user crazy when theres a spotty connection?
	signalIsPoorQualityStream = isSignalGoodStream
		.filter(isFalsy)
		.map('poorSignalQuality')
	signalIsGoodQualityStream = isSignalGoodStream
		.filter(isTruthy)
		.map('paired')
	signalIsGoodStream = isSignalGoodStream
		.filter(isTruthy)
		.map('paired') 
	# a stream of the local server's attempts to pair with the mindwave
	localServerIsPairingStream = localServerMessages 
		.map('pairing') 

	# a stream of all device statuses:
	# either not paired, poorSignalQuality,paired 
	mindwaveStatusProperty = Bacon
		.mergeAll([
			localServerIsPairingStream
			, signalIsGoodStream
			, signalIsStaleStream
			, signalIsGoodQualityStream
			, signalIsPoorQualityStream ])
		.toProperty('notPaired')

	mindwaveStatusProperty

module.exports = getMindwaveStatusProperty