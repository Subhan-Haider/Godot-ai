## CustomProvider — Generic OpenAI-compatible REST endpoint.
## User supplies endpoint URL, model name, and optional api key.
@tool
class_name CustomProvider
extends BaseProvider

func get_provider_name()   -> String: return "Custom"
func get_default_endpoint()-> String: return "https://your-api.com/v1/chat/completions"
func get_default_model()   -> String: return "custom-model"


func send_chat(messages: Array, node: Node) -> void:
	var url := endpoint_url if endpoint_url != "" else get_default_endpoint()
	var http := _make_http(node)
	http.request_completed.connect(_on_chat_completed.bind(http))

	var body  := JSON.stringify(_build_openai_body(messages))
	var heads := ["Content-Type: application/json"]
	if api_key.strip_edges() != "":
		heads.append("Authorization: Bearer " + api_key)

	var err := http.request(url, heads, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_emit_failure("Custom: Request start failed (err %d)." % err)


func _on_chat_completed(_result, code: int, _headers, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code < 200 or code >= 300:
		_emit_failure("Custom HTTP %d: %s" % [code, body.get_string_from_utf8()], code)
		return
	var raw: String = body.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(raw) != OK:
		# Some endpoints return plain text
		_emit_success(raw)
		return
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("choices"):
			_emit_success(_extract_openai_text(data))
		elif data.has("content"):
			_emit_success(str(data["content"]))
		else:
			_emit_success(str(data))
	else:
		_emit_success(str(data))
