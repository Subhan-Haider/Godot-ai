# class_name OpenRouterProvider
extends AIProvider

func _init():
	endpoint_url = "https://openrouter.ai/api/v1/chat/completions"
	model_name = "openai/gpt-4-turbo"
	supports_tools = true
	supports_images = false # Varies by sub-model, default false for chat

func fetch_models(node: Node):
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request_completed.connect(_on_fetch_response.bind(http))
	
	var err = http.request("https://openrouter.ai/api/v1/models")
	if err != OK:
		models_fetched.emit([], "Failed to start OpenRouter fetch request.")

func _on_fetch_response(result, response_code, headers, body, http_node):
	http_node.queue_free()
	if response_code != 200:
		models_fetched.emit([], "OpenRouter fetch error " + str(response_code))
		return
		
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var data = json.get_data()
		var res_models = []
		if typeof(data) == TYPE_DICTIONARY and data.has("data"):
			for m in data["data"]:
				res_models.append(m.get("id", ""))
		models_fetched.emit(res_models, "")
	else:
		models_fetched.emit([], "Failed to parse OpenRouter models JSON.")

func generate_text(system_prompt: String, user_prompt: String, node: Node):
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request_completed.connect(_on_response.bind(http))

	var data = {
		"model": model_name,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": user_prompt}
		]
	}
	
	if supports_tools: 
		# Basic adapter format to match typical tool usage schemas logic
		pass

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
		"HTTP-Referer: https://godotengine.org",
		"X-Title: Godot AI Architect"
	]
	
	var err = http.request(
		endpoint_url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)
	
	if err != OK:
		_emit_error("Failed to start OpenRouter HTTP Request.")

func send_chat(messages: Array, node: Node):
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request_completed.connect(_on_response.bind(http))

	var data = {
		"model": model_name,
		"messages": messages
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
		"HTTP-Referer: https://godotengine.org",
		"X-Title: Godot AI Architect"
	]
	
	var err = http.request(
		endpoint_url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)
	
	if err != OK:
		_emit_error("Failed to start OpenRouter Chat Request.")

func _on_response(result, response_code, headers, body, http_node):
	http_node.queue_free()
	
	if response_code != 200:
		_emit_error("OpenRouter Error " + str(response_code) + ": " + body.get_string_from_utf8())
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_emit_error("Failed to parse OpenRouter JSON.")
		return
		
	var data = json.get_data()
	var choices = data.get("choices", [])
	if choices.size() > 0:
		var response_text = choices[0].get("message", {}).get("content", "")
		_emit_success(response_text)
	else:
		_emit_error("Invalid OpenRouter choices format.")


func send_chat_stream(messages: Array, node: Node):
	# Using HTTPClient for true streaming in Godot
	var client = HTTPClient.new()
	var err = client.connect_to_host("https://openrouter.ai", 443)
	if err != OK:
		_emit_error("Failed to connect to OpenRouter for streaming.")
		return
		
	# Polling wait for connection
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		await node.get_tree().process_frame
		
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		_emit_error("Failed to establish OpenRouter stream connection.")
		return

	var data = {
		"model": model_name,
		"messages": messages,
		"stream": true
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
		"X-Title: Godot AI Architect"
	]
	
	err = client.request(HTTPClient.METHOD_POST, "/api/v1/chat/completions", headers, JSON.stringify(data))
	if err != OK:
		_emit_error("Failed to start OpenRouter stream request.")
		return
		
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		await node.get_tree().process_frame
		
	var full_content = ""
	if client.has_response():
		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var chunk = client.read_response_body_chunk()
			if chunk.size() > 0:
				var text = chunk.get_string_from_utf8()
				var lines = text.split("\n")
				for line in lines:
					if line.begins_with("data: "):
						var raw_json = line.substr(6).strip_edges()
						if raw_json == "[DONE]": 
							break
						var json = JSON.new()
						if json.parse(raw_json) == OK:
							var delta = json.data.get("choices", [{}])[0].get("delta", {})
							if delta.has("content"):
								var content = delta["content"]
								full_content += content
								stream_chunk_received.emit(content)
			await node.get_tree().process_frame
			
	_emit_success(full_content)
	client.close()
