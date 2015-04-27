$ = require 'jquery'

postJson = (data, url, successCb) ->

	$.ajax({
		type: 'POST'
		url: url
		data: JSON.stringify(data)
		contentType: 'application/json; charset=utf-8'
		dataType: 'application/json'
		success: successCb
	})

module.exports = postJson