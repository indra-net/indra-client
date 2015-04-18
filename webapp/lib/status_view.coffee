$ = require 'jquery'
_ = require 'lodash'
Bacon = require 'baconjs'
Bacon$ = require 'bacon.jquery'
BaconModel = require 'bacon.model'

isValue = (v, value) -> if v == value then true else false

setClass = ($element, cssClass) -> 
	$element.removeClass()
	$element.addClass(cssClass)

notPairedMessage = 'No connection with your Neurosky right now. About to connect... '
pairingMessage = 'No connection with your Neurosky right now. Pairing with device.....'
pairedMessage = "<b>Everything is ok</b>"
poorSignalQualityMessage = "<b>We're getting a suboptimal signal from your device.</b> Try adjusting it on your head until this message goes away."

statusPageTemplate = () ->
	_.template('''
		<div id = "statusContainer">
			<div id = "statusCircle"></div>
			<div id = "statusMessage"></div>
		</div>
		''')()

setStatus = (cssClass, message) ->
	# we change #statusCircle by setting its class
	setClass($('#statusCircle'), cssClass)
	$('#statusMessage').html(message)


setup = (statusProperty, pairAgainRequestStream) ->

	# set up the page
	$('#content').html(statusPageTemplate())

	#  statusProperty sets the Status UI
	#
	# statusProperty can have the following values:
	# 'notPaired', 'paired', 'pairing' 'poorSignalQuality', 'cannotPair'
	#
	statusProperty
		.filter((v) -> isValue(v, 'notPaired'))
		.onValue(() -> 
			setStatus('notPaired',notPairedMessage))

	statusProperty
		.filter((v) -> isValue(v, 'pairing'))
		.onValue(() -> 
			setStatus('pairing', pairingMessage))

	statusProperty
		.filter((v) -> isValue(v, 'paired'))
		.onValue(() -> 
			setStatus('paired', pairedMessage))

	statusProperty
		.filter((v) -> isValue(v, 'poorSignalQuality'))
		.onValue(() -> 
			setStatus('poorSignalQuality', poorSignalQualityMessage))

exports.setup = setup