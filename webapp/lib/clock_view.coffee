_ = require 'lodash'
$ = require 'jquery'

clockTemplate = (timeString) ->
	_.template('indra time <%= time %>')(time: timeString)

setup = (time) ->
	$('#clock').html(clockTemplate(time.format('MMMM Do YYYY, H:mm:ss:SSS')))

exports.setup = setup