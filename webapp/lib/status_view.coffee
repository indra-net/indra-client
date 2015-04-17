$ = require 'jquery'
_ = require 'lodash'

recorder_screen_template = () ->
	_.template('''
		<i>cool status template</i>
		''')()

setup = ->
	$('body').html(statusTemplate())

exports.setup = setup