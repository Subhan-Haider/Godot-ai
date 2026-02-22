## BaseProvider - Abstract interface all AI providers must implement.
##
## Every adapter must extend this class and override the virtual methods.
## Signals are the primary communication channel back to the orchestrator.
@tool
class_name BaseProvider
extends RefCounted

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a complete (non-streaming) response arrives.
signal response_completed(result: Dictionary)

## Emitted for each incremental chunk during streaming.
signal stream_chunk(text: String)

## Emitted on any error (network, auth, parse).
signal request_failed(error: String, code: int)

## Emitted when a model list fetch completes.
signal models_loaded(models: Array)

# ---------------------------------------------------------------------------
# Configuration — set by ProviderRouter before each call
# ---------------------------------------------------------------------------

var api_key:      String = ""
var endpoint_url: String = ""
var model_name:   String = ""
var temperature:  float  = 0.7
var max_tokens:   int    = 2048
var streaming:    bool   = false

# ---------------------------------------------------------------------------
# Provider metadata — subclasses override these constants
# ---------------------------------------------------------------------------

## Human-readable provider name shown in the UI.
func get_provider_name() -> String:
	return "BaseProvider"

## Whether this provider supports tool / function calling.
func supports_tools() -> bool:
	return false

## Whether this provider supports streamed responses.
func supports_streaming() -> bool:
	return false

## Whether this provider can generate images.
func supports_images() -> bool:
	return false

## Return a default endpoint URL (used if user leaves field empty).
func get_default_endpoint() -> String:
	return ""

## Return the default model name for this provider.
func get_default_model() -> String:
	return ""

# ---------------------------------------------------------------------------
# Virtual methods — must be overridden
# ---------------------------------------------------------------------------

## Send a chat completion request.
## @messages  Array of {role, content} dictionaries.
## @node      Godot Node to attach HTTPRequest child to.
func send_chat(messages: Array, node: Node) -> void:
	push_error("BaseProvider.send_chat() not implemented by %s" % get_provider_name())


## Fetch available models from the provider's API.
func fetch_models(node: Node) -> void:
	models_loaded.emit([])


## Optional image generation.
func generate_image(prompt: String, node: Node) -> void:
	request_failed.emit("Image generation not supported by %s" % get_provider_name(), 0)

# ---------------------------------------------------------------------------
# Helpers shared by all providers
# ---------------------------------------------------------------------------

## Build a standard HTTPRequest child, attach it to node, return it.
func _make_http(node: Node) -> HTTPRequest:
	var http := HTTPRequest.new()
	http.timeout = 60.0
	node.add_child(http)
	return http


## Convert the messages array into an OpenAI-style JSON body dict.
func _build_openai_body(messages: Array) -> Dictionary:
	return {
		"model": model_name,
		"messages": messages,
		"temperature": temperature,
		"max_tokens": max_tokens,
		"stream": streaming
	}


## Extract the assistant text from a standard OpenAI choices response.
func _extract_openai_text(data: Dictionary) -> String:
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		return ""
	return choices[0].get("message", {}).get("content", "")


## Emit a normalised response_completed signal.
func _emit_success(text: String) -> void:
	response_completed.emit({ "text": text, "error": "" })


## Emit a normalised failure.
func _emit_failure(msg: String, code: int = 0) -> void:
	request_failed.emit(msg, code)
