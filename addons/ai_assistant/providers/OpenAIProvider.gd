## OpenAIProvider — Adapter for OpenAI and any OpenAI-compatible endpoint.
##
## Compatible with: OpenAI, Together.ai, Groq, Mistral, LM Studio, etc.
@tool
class_name OpenAIProvider
extends BaseProvider

func get_provider_name() -> String: return "OpenAI"
func supports_tools()     -> bool:   return true
func supports_streaming() -> bool:   return true
func get_default_endpoint()-> String: return "https://api.openai.com/v1/chat/completions"
func get_default_model()   -> String: return "gpt-4o"


func send_chat(messages: Array, node: Node) -> void:
	if api_key.strip_edges() == "":
		_emit_failure("OpenAI: API key is empty.")
		return

	var url := endpoint_url if endpoint_url != "" else get_default_endpoint()
	var http := _make_http(node)
	http.request_completed.connect(_on_chat_completed.bind(http))

	var body  := JSON.stringify(_build_openai_body(messages))
	var heads := [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]

	var err := http.request(url, heads, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_emit_failure("OpenAI: HTTPRequest failed to start (code %d)." % err)


func _on_chat_completed(_result, code: int, _headers, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if code != 200:
		_emit_failure("OpenAI HTTP %d: %s" % [code, body.get_string_from_utf8()], code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_emit_failure("OpenAI: Failed to parse response JSON.")
		return

	var data: Dictionary = json.get_data()
	if data.has("error"):
		_emit_failure("OpenAI API error: " + str(data["error"].get("message", data["error"])))
		return

	_emit_success(_extract_openai_text(data))


func fetch_models(node: Node) -> void:
	if api_key.strip_edges() == "":
		models_loaded.emit([])
		return

	var http := _make_http(node)
	http.request_completed.connect(_on_models_completed.bind(http))

	var base := endpoint_url.get_base_dir() if endpoint_url != "" else "https://api.openai.com"
	http.request(base + "/v1/models", ["Authorization: Bearer " + api_key])


func _on_models_completed(_result, code: int, _headers, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code != 200:
		models_loaded.emit([])
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		models_loaded.emit([])
		return

	var ids: Array = []
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY and data.has("data"):
		for m in data["data"]:
			ids.append(m.get("id", ""))
	models_loaded.emit(ids)
