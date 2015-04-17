$ = require 'jquery'
_ = require 'lodash'

connectingTemplate = ->
	_.template('''
		<h1>connecting to device...</h1>
		<img src="static/assets/wand.gif">
		<p>make sure the deivce is turned on + on your head</p>
		''')()

setup = ->
	$('body').html(connectingTemplate())