# class_name HuggingFaceProvider
extends AIProvider

func _init():
	endpoint_url = "https://api-inference.huggingface.co/models/"
	model_name = "mistralai/Mixtral-8x7B-Instruct-v0.1"
	supports_tools = false
	supports_images = false

func generate_text(system_prompt: String, user_prompt: String, node: Node):
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request_completed.connect(_on_response.bind(http))

	var url = endpoint_url + model_name
	var full_prompt = "<s>[INST] " + system_prompt + "\\n\\n" + user_prompt + " [/INST]"

	var data = {
		"inputs": full_prompt,
		"parameters": {"return_full_text": false, "temperature": 0.1, "max_new_tokens": 1024}
	}

	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json"
	]
	
	var err = http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)
	
	if err != OK:
		_emit_error("Failed to start HuggingFace HTTP Request.")

func _on_response(result, response_code, headers, body, http_node):
	http_node.queue_free()
	
	if response_code != 200:
		_emit_error("HuggingFace Error " + str(response_code) + ": " + body.get_string_from_utf8())
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_emit_error("Failed to parse HuggingFace JSON.")
		return
		
	var data = json.get_data()
	if typeof(data) == TYPE_ARRAY and data.size() > 0:
		var response_text = data[0].get("generated_text", "")
		_emit_success(response_text)
	else:
		_emit_error("Invalid HuggingFace choices format.")

func send_chat(messages: Array, node: Node):
	var prompt = ""
	for m in messages:
		if m["role"] == "system":
			prompt += "<s>[SYSTEM] " + m["content"] + " [/SYSTEM]\n"
		elif m["role"] == "user":
			prompt += "[INST] " + m["content"] + " [/INST]"
		else:
			prompt += " " + m["content"] + "</s>\n"
	
	generate_text("", prompt, node) # Reuse the logic with flattened prompt
