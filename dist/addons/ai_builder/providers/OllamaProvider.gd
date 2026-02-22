# class_name OllamaProvider
extends AIProvider

func _init():
	endpoint_url = "http://127.0.0.1:11434/api/generate"
	model_name = "llama3"
	supports_tools = true
	supports_images = false

func _get_base_url() -> String:
	var base = endpoint_url
	if base == "" or base == null:
		base = "http://127.0.0.1:11434"
	
	if base.ends_with("/api/generate"):
		base = base.replace("/api/generate", "")
	elif base.ends_with("/api/chat"):
		base = base.replace("/api/chat", "")
	
	if not base.contains("://"):
		base = "http://" + base
		
	if base.ends_with("/"):
		base = base.left(base.length() - 1)
	
	if base == "http:": # Fallback if replace left us with nothing
		base = "http://127.0.0.1:11434"
		
	return base

func fetch_models(node: Node):
	print("[AI Builder] Querying ollama for available models...")
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request_completed.connect(_on_fetch_response.bind(http))
	
	var tags_url = _get_base_url() + "/api/tags"
	
	var err = http.request(tags_url)
	if err != OK:
		models_fetched.emit([], "Failed to start Ollama fetch request.")

func _on_fetch_response(result, response_code, headers, body, http_node):
	http_node.queue_free()
	if response_code != 200:
		models_fetched.emit([], "Ollama error " + str(response_code))
		return
		
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var data = json.get_data()
		var res_models = []
		if data.has("models"):
			for m in data["models"]:
				res_models.append(m.get("name", ""))
		models_fetched.emit(res_models, "")
	else:
		models_fetched.emit([], "Failed to parse Ollama tags JSON.")

func generate_text(system_prompt: String, user_prompt: String, node: Node):
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request_completed.connect(_on_response.bind(http))

	var full_prompt = system_prompt + "\n\nUser request:\n" + user_prompt

	var data = {
		"model": model_name,
		"prompt": full_prompt,
		"stream": false
	}

	var headers = ["Content-Type: application/json"]
	var gen_url = _get_base_url() + "/api/generate"
	var err = http.request(
		gen_url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)
	
	if err != OK:
		_emit_error("Failed to send Ollama request.")

func send_chat(messages: Array, node: Node):
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request_completed.connect(_on_chat_response.bind(http))

	# Ollama chat endpoint is usually /api/chat
	var chat_url = _get_base_url() + "/api/chat"
	
	var data = {
		"model": model_name,
		"messages": messages,
		"stream": false
	}

	var headers = ["Content-Type: application/json"]
	var err = http.request(
		chat_url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)
	
	if err != OK:
		_emit_error("Failed to send Ollama chat request.")

func _on_chat_response(result, response_code, headers, body, http_node):
	http_node.queue_free()
	if response_code != 200:
		_emit_error("Ollama chat error " + str(response_code))
		return
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var data = json.get_data()
		_emit_success(data.get("message", {}).get("content", ""))
	else:
		_emit_error("Failed to parse Ollama chat JSON.")


func send_chat_stream(messages: Array, node: Node):
	var client = HTTPClient.new()
	var url_parsed = endpoint_url.replace("http://", "").split(":")
	var host = "localhost"
	var port = 11434
	if url_parsed.size() >= 1: host = url_parsed[0].split("/")[0]
	if url_parsed.size() >= 2: port = int(url_parsed[1].split("/")[0])
	
	var err = client.connect_to_host(host, port)
	if err != OK:
		_emit_error("Failed to connect to Ollama for streaming.")
		return
		
	var timeout_start = Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		if Time.get_ticks_msec() - timeout_start > 5000:
			_emit_error("Ollama connection timeout (5s). Is Ollama running?")
			return
		client.poll()
		await node.get_tree().process_frame
		
	var data = {
		"model": model_name,
		"messages": messages,
		"stream": true
	}
	
	var headers = ["Content-Type: application/json"]
	err = client.request(HTTPClient.METHOD_POST, "/api/chat", headers, JSON.stringify(data))
	if err != OK:
		_emit_error("Failed to start Ollama stream request.")
		return
		
	timeout_start = Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		if Time.get_ticks_msec() - timeout_start > 10000:
			_emit_error("Ollama request timeout (10s).")
			return
		client.poll()
		await node.get_tree().process_frame
		
	var full_content = ""
	if client.has_response():
		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var chunk = client.read_response_body_chunk()
			if chunk.size() > 0:
				var text = chunk.get_string_from_utf8()
				var lines = text.split("\n", false) # Avoid empty lines
				for line in lines:
					var json = JSON.new()
					if json.parse(line) == OK:
						var dict = json.get_data()
						if dict.has("error"):
							_emit_error("Ollama Error: " + dict["error"])
							return
						var msg = dict.get("message", {})
						if msg.has("content"):
							var content = msg["content"]
							full_content += content
							stream_chunk_received.emit(content)
			await node.get_tree().process_frame
			
	_emit_success(full_content)
	client.close()

func _on_response(result, response_code, headers, body, http_node):
	http_node.queue_free()
	
	if response_code != 200:
		_emit_error("Ollama error " + str(response_code) + ": " + body.get_string_from_utf8())
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_emit_error("Failed to parse Ollama JSON.")
		return
		
	var data = json.get_data()
	_emit_success(data.get("response", ""))
