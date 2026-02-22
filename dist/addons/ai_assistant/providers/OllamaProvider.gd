## OllamaProvider — Local Ollama server (http://localhost:11434)
@tool
class_name OllamaProvider
extends BaseProvider

func get_provider_name()   -> String: return "Ollama"
func supports_streaming()  -> bool:   return true
func get_default_endpoint()-> String: return "http://localhost:11434/api/chat"
func get_default_model()   -> String: return "llama3"


func send_chat(messages: Array, node: Node) -> void:
	var url  := endpoint_url if endpoint_url != "" else get_default_endpoint()
	var http := _make_http(node)
	http.request_completed.connect(_on_chat_completed.bind(http))

	var body := JSON.stringify({
		"model": model_name if model_name != "" else get_default_model(),
		"messages": messages,
		"stream": false,
		"options": { "temperature": temperature, "num_predict": max_tokens }
	})

	var err := http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_emit_failure("Ollama: Request start failed (err %d)." % err)


func _on_chat_completed(_result, code: int, _headers, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code != 200:
		_emit_failure("Ollama HTTP %d: %s" % [code, body.get_string_from_utf8()], code)
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_emit_failure("Ollama: JSON parse error.")
		return
	var data: Dictionary = json.get_data()
	var text: String = data.get("message", {}).get("content", "")
	if text == "":
		# Older generate endpoint fallback
		text = data.get("response", "")
	_emit_success(text)


func fetch_models(node: Node) -> void:
	var base = endpoint_url if endpoint_url != "" else "http://localhost:11434"
	if base.ends_with("/api/chat"): base = base.replace("/api/chat", "")
	if base.ends_with("/api/generate"): base = base.replace("/api/generate", "")
	if base.ends_with("/"): base = base.left(base.length() - 1)
	
	var http := _make_http(node)
	http.request_completed.connect(_on_models_completed.bind(http))
	http.request(base + "/api/tags")


func _on_models_completed(_result, code: int, _headers, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code != 200: models_loaded.emit([]); return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK: models_loaded.emit([]); return
	var ids: Array = []
	var d = json.get_data()
	if typeof(d) == TYPE_DICTIONARY and d.has("models"):
		for m in d["models"]: ids.append(m.get("name", ""))
	models_loaded.emit(ids)
