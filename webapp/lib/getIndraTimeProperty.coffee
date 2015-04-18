$ = require 'jquery'
Bacon = require 'baconjs'
Bacon$ = require 'bacon.jquery'
baconmodel = require 'bacon.model'
moment = require 'moment'

timediff = (one, the_other) -> moment(the_other).diff(one)
getServerTime = (timeDiff) -> moment().utc().add(timeDiff)

getIndraTimeProperty = (timeServerURL, updateTimeInterval, pollLocalClockInterval) ->

	# a timediff var that mutates everytime we fetch time from the timeserver
	timeDiffStream = new Bacon.Bus()

	# ask for the time on an interval
	timeRequests = Bacon.interval(updateTimeInterval)
		.map(() -> return {url:timeServerURL})

	serverTimeResults = timeRequests.ajax()

	timeDiff = null
	# on each response from the timeserver
	# set the diff between the servers time and ours
	serverTimeResults
		.onValue((t)-> 
			timeDiff = timediff(moment(t), moment()))

 	# asnyc polling to get local time
 	# we only get a timediff when we've heard from the server
	indraTimeProperty = Bacon.fromPoll(
		pollLocalClockInterval, () -> 
			if timeDiff
				return getServerTime(timeDiff)
			else 
				return null)
		.toProperty()

	indraTimeProperty

module.exports = getIndraTimeProperty