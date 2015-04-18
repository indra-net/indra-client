_ = require 'lodash'
$ = require 'jquery'

clockTemplate = (timeString) ->
	_.template('indra time <%= time %>')(time: timeString)

setup = (momentTime) ->
	$('#clock').html(
		clockTemplate(
			momentTime.format('MMMM Do YYYY, H:mm:ss:SSS')))

exports.setup = setup