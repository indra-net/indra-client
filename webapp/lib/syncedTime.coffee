$ = require 'jquery'
Bacon = require 'baconjs'
Bacon$ = require 'bacon.jquery'
baconmodel = require 'bacon.model'
moment = require 'moment'

timediff = (one, the_other) -> moment(the_other).diff(one)
getServerTime = (timeDiff) -> moment().utc().add(timeDiff)

getTimeDiffStream = (timeServerURL, updateTimeInterval) ->

	# ask for the time on an interval
	timeRequests = Bacon.interval(updateTimeInterval)
		.map(() -> return {url:timeServerURL})

	serverTimeResults = timeRequests.ajax()

	timeDiffStream = serverTimeResults
		.map((t) -> timediff(moment(t), moment()))

	timeDiffStream

getSynchronisedTimeProperty = (timeDiffStream, pollLocalClockInterval) ->
	# mutable value we use to calculate indra time
	timeDiff = null
	# on each response from the timeserver
	# set the diff between the servers time and ours
	timeDiffStream
		.onValue((t)-> timeDiff = t)

 	# asnyc polling to get local time
 	# we only get a timediff when we've heard from the server
	synchronisedTimeProperty = Bacon.fromPoll(
		pollLocalClockInterval, () -> 
			if timeDiff
				return getServerTime(timeDiff)
			else 
				return null)
		.toProperty()

	synchronisedTimeProperty
		.filter((v) -> if v then v)

exports.getTimeDiffStream = getTimeDiffStream
exports.getSynchronisedTimeProperty = getSynchronisedTimeProperty 