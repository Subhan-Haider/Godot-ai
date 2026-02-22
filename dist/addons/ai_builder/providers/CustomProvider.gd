# class_name CustomProvider
extends AIProvider

func _init():
	endpoint_url = "https://your-custom-api.com/v1/chat/completions"
	model_name = "custom-model"
	supports_tools = true
	supports_images = false

func generate_text(system_prompt: String, user_prompt: String, node: Node):
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request_completed.connect(_on_response.bind(http))

	var data = {
		"model": model_name,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": user_prompt}
		],
		"stream": false
	}

	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json"
	]
	
	var err = http.request(
		endpoint_url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)
	
	if err != OK:
		_emit_error("Failed to start Custom HTTP Request.")

func _on_response(result, response_code, headers, body, http_node):
	http_node.queue_free()
	
	if response_code != 200:
		_emit_error("Custom API Error " + str(response_code) + ": " + body.get_string_from_utf8())
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_emit_error("Failed to parse Custom JSON.")
		return
		
	var data = json.get_data()
	if data.has("choices") and data.get("choices").size() > 0:
		var response_text = data["choices"][0].get("message", {}).get("content", "")
		_emit_success(response_text)
	elif data.has("response"):
		# Ollama style fallback
		_emit_success(data["response"])
	else:
		_emit_error("Invalid Custom API choices format.")

func send_chat(messages: Array, node: Node):
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request_completed.connect(_on_response.bind(http))

	var data = {
		"model": model_name,
		"messages": messages,
		"stream": false
	}

	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json"
	]
	
	var err = http.request(endpoint_url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	if err != OK: _emit_error("Failed to start Custom chat request.")
