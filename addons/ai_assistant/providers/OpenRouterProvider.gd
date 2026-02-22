## OpenRouterProvider — routes to hundreds of models via openrouter.ai
@tool
class_name OpenRouterProvider
extends BaseProvider

func get_provider_name()  -> String: return "OpenRouter"
func supports_tools()     -> bool:   return true
func supports_streaming() -> bool:   return true
func get_default_endpoint()-> String: return "https://openrouter.ai/api/v1/chat/completions"
func get_default_model()   -> String: return "openai/gpt-4o"


func send_chat(messages: Array, node: Node) -> void:
	if api_key.strip_edges() == "":
		_emit_failure("OpenRouter: API key is empty.")
		return

	var http := _make_http(node)
	http.request_completed.connect(_on_chat_completed.bind(http))

	var body := JSON.stringify(_build_openai_body(messages))
	var heads := [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
		"HTTP-Referer: https://godotengine.org",
		"X-Title: Godot AI Assistant"
	]

	var err := http.request(get_default_endpoint(), heads, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_emit_failure("OpenRouter: Request start failed (err %d)." % err)


func _on_chat_completed(_result, code: int, _headers, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code != 200:
		_emit_failure("OpenRouter HTTP %d: %s" % [code, body.get_string_from_utf8()], code)
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_emit_failure("OpenRouter: JSON parse error.")
		return
	var data: Dictionary = json.get_data()
	if data.has("error"):
		_emit_failure("OpenRouter error: " + str(data["error"]))
		return
	_emit_success(_extract_openai_text(data))


func fetch_models(node: Node) -> void:
	var http := _make_http(node)
	http.request_completed.connect(_on_models_completed.bind(http))
	http.request("https://openrouter.ai/api/v1/models",
		["Authorization: Bearer " + api_key])


func _on_models_completed(_result, code: int, _headers, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code != 200: models_loaded.emit([]); return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK: models_loaded.emit([]); return
	var ids: Array = []
	var d = json.get_data()
	if typeof(d) == TYPE_DICTIONARY and d.has("data"):
		for m in d["data"]: ids.append(m.get("id", ""))
	models_loaded.emit(ids)
