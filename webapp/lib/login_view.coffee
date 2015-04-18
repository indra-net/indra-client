$ = require 'jquery'
_ = require 'lodash'
bacon$ = require 'bacon.jquery'
baconModel = require 'bacon.model'
utils = require './utils.coffee'

loginTemplate = ->
	_.template('''
		User ID: <input type="text" id="userIdInput"/>
		<br>
		<button id="connectButton">Connect!</button>
		''')()

setup = ->

	# render the login template in html body
	$('#content').html(loginTemplate())

	$userIdInput = $('#userIdInput')
	$connectButton = $('#connectButton')

	userIdInputProperty = bacon$.textFieldValue($userIdInput)
		.debounce(25)
		.skipDuplicates()

	# disable the connect button until a username is entered
	userIdInputProperty.map(utils.nonEmpty)
		.assign(utils.setEnabled, $connectButton)

	connectButtonStream = $connectButton.asEventStream('click')

	# whatever username the person has entered
	# sampled by a click of the button
	idSubmissionStream = userIdInputProperty
		.sampledBy(connectButtonStream)

	# export a stream of id submissions
	return idSubmissionStream


exports.setup = setup
