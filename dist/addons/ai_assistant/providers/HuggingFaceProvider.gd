## HuggingFaceProvider — Inference API for hosted HuggingFace models
@tool
class_name HuggingFaceProvider
extends BaseProvider

func get_provider_name()   -> String: return "HuggingFace"
func get_default_endpoint()-> String: return "https://api-inference.huggingface.co/models"
func get_default_model()   -> String: return "mistralai/Mistral-7B-Instruct-v0.3"


func send_chat(messages: Array, node: Node) -> void:
	if api_key.strip_edges() == "":
		_emit_failure("HuggingFace: API key is empty.")
		return

	var model := model_name if model_name != "" else get_default_model()
	var url   := "https://api-inference.huggingface.co/models/" + model + "/v1/chat/completions"
	var http  := _make_http(node)
	http.request_completed.connect(_on_chat_completed.bind(http))

	var body := JSON.stringify({
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens,
		"stream": false
	})
	var heads := [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]

	var err := http.request(url, heads, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_emit_failure("HuggingFace: Request start failed (err %d)." % err)


func _on_chat_completed(_result, code: int, _headers, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code != 200:
		_emit_failure("HuggingFace HTTP %d: %s" % [code, body.get_string_from_utf8()], code)
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_emit_failure("HuggingFace: JSON parse error.")
		return
	var data = json.get_data()
	# HF inference can return array or dict depending on model type
	if typeof(data) == TYPE_ARRAY and not data.is_empty():
		var text = data[0].get("generated_text", str(data[0]))
		_emit_success(text)
	elif typeof(data) == TYPE_DICTIONARY:
		if data.has("choices"):
			_emit_success(_extract_openai_text(data))
		else:
			_emit_success(str(data))
	else:
		_emit_failure("HuggingFace: Unexpected response format.")
