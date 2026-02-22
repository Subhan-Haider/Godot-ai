## GrokProvider — xAI Grok via api.x.ai (OpenAI-compatible)
@tool
class_name GrokProvider
extends BaseProvider

func get_provider_name()   -> String: return "Grok"
func supports_tools()      -> bool:   return true
func supports_streaming()  -> bool:   return true
func get_default_endpoint()-> String: return "https://api.x.ai/v1/chat/completions"
func get_default_model()   -> String: return "grok-2-latest"


func send_chat(messages: Array, node: Node) -> void:
	if api_key.strip_edges() == "":
		_emit_failure("Grok: API key is empty.")
		return
	var url  := endpoint_url if endpoint_url != "" else get_default_endpoint()
	var http := _make_http(node)
	http.request_completed.connect(_on_chat_completed.bind(http))
	var body  := JSON.stringify(_build_openai_body(messages))
	var heads := ["Content-Type: application/json", "Authorization: Bearer " + api_key]
	var err   := http.request(url, heads, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_emit_failure("Grok: Request start failed (err %d)." % err)


func _on_chat_completed(_result, code: int, _headers, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code != 200:
		_emit_failure("Grok HTTP %d: %s" % [code, body.get_string_from_utf8()], code)
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_emit_failure("Grok: JSON parse error.")
		return
	var data: Dictionary = json.get_data()
	if data.has("error"):
		_emit_failure("Grok API error: " + str(data["error"]))
		return
	_emit_success(_extract_openai_text(data))
