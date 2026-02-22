## GeminiProvider — Google Gemini via generativelanguage.googleapis.com
@tool
class_name GeminiProvider
extends BaseProvider

func get_provider_name()   -> String: return "Gemini"
func supports_streaming()  -> bool:   return false
func get_default_model()   -> String: return "gemini-1.5-pro"
func get_default_endpoint()-> String:
	return "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent" % get_default_model()


func send_chat(messages: Array, node: Node) -> void:
	if api_key.strip_edges() == "":
		_emit_failure("Gemini: API key is empty.")
		return

	var model := model_name if model_name != "" else get_default_model()
	var url := "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s" % [model, api_key]
	var http := _make_http(node)
	http.request_completed.connect(_on_chat_completed.bind(http))

	# Gemini uses "contents" with "parts" instead of OpenAI messages
	var contents: Array = []
	for msg in messages:
		var role = "user" if msg.get("role", "user") != "assistant" else "model"
		contents.append({ "role": role, "parts": [{ "text": msg.get("content", "") }] })

	var body := JSON.stringify({
		"contents": contents,
		"generationConfig": { "temperature": temperature, "maxOutputTokens": max_tokens }
	})

	var err := http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_emit_failure("Gemini: Request start failed (err %d)." % err)


func _on_chat_completed(_result, code: int, _headers, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code != 200:
		_emit_failure("Gemini HTTP %d: %s" % [code, body.get_string_from_utf8()], code)
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_emit_failure("Gemini: JSON parse error.")
		return
	var data: Dictionary = json.get_data()
	var candidates: Array = data.get("candidates", [])
	if candidates.is_empty():
		_emit_failure("Gemini: No candidates in response.")
		return
	var text: String = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
	_emit_success(text)
