# class_name GeminiProvider
extends AIProvider

func _init():
	endpoint_url = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
	model_name = "gemini-1.5-pro"
	supports_tools = true
	supports_images = false

func generate_text(system_prompt: String, user_prompt: String, node: Node):
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request_completed.connect(_on_response.bind(http))

	var url = endpoint_url.replace("{model}", model_name) + "?key=" + api_key

	var data = {
		"system_instruction": {
			"parts": [{"text": system_prompt}]
		},
		"contents": [{
			"parts": [{"text": user_prompt}]
		}],
		"generationConfig": {
			"temperature": 0.2
		}
	}

	var headers = ["Content-Type: application/json"]
	
	var err = http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)
	
	if err != OK:
		_emit_error("Failed to start Gemini HTTP Request.")

func _on_response(result, response_code, headers, body, http_node):
	http_node.queue_free()
	
	if response_code != 200:
		_emit_error("Gemini Error " + str(response_code) + ": " + body.get_string_from_utf8())
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_emit_error("Failed to parse Gemini JSON.")
		return
		
	var data = json.get_data()
	var candidates = data.get("candidates", [])
	if candidates.size() > 0:
		var response_text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
		_emit_success(response_text)
	else:
		_emit_error("Invalid Gemini choices format.")

func send_chat(messages: Array, node: Node):
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request_completed.connect(_on_response.bind(http))

	var url = endpoint_url.replace("{model}", model_name) + "?key=" + api_key
	
	var gemini_msgs = []
	var system_instr = ""
	
	for m in messages:
		if m["role"] == "system":
			system_instr = m["content"]
		else:
			var g_role = "user" if m["role"] == "user" else "model"
			gemini_msgs.append({
				"role": g_role,
				"parts": [{"text": m["content"]}]
			})

	var data = {
		"contents": gemini_msgs,
		"generationConfig": {"temperature": 0.2}
	}
	
	if system_instr != "":
		data["system_instruction"] = {"parts": [{"text": system_instr}]}

	var headers = ["Content-Type: application/json"]
	var err = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	if err != OK: _emit_error("Failed to start Gemini chat request.")
