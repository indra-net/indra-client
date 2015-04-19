$ = require 'jquery'

postJson = (data, url, successCb) ->
	
	# debug
	console.log 'here is a data i want to post', JSON.stringify(data) #debug

	$.ajax({
		type: 'POST'
		url: url
		data: JSON.stringify(data)
		contentType: 'application/json; charset=utf-8'
		dataType: 'application/json'
		success: successCb
	})

module.exports = postJson