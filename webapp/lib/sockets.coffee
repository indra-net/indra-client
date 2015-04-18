io = require './socket.io.min.js'
Bacon = require 'baconjs'


# returns a bacon stream of the data
exports.setup = (localServer) ->

	socket = io.connect(localServer)

	# server messages to display on the console
	socket.on('server_says', (data) -> 
		console.log 'server says: ', data)

	# data from the mindwave mobile
	socket.on('data', (data) -> data)

	# status messages from the local server
	socket.on('pairing', (data) -> data)

