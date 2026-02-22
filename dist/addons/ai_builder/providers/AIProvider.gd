class_name AIProvider
extends RefCounted

var api_key: String = ""
var endpoint_url: String = ""
var model_name: String = ""

var supports_images: bool = false
var supports_tools: bool = false
var supports_stream: bool = true

signal request_completed(response: String, error: String)
signal models_fetched(models: Array, error_msg: String)
signal stream_chunk_received(chunkText: String)

func generate_text(system_prompt: String, user_prompt: String, node: Node):
	push_error("AIProvider: generate_text must be implemented by subclass.")

func send_chat(messages: Array, node: Node):
	push_error("AIProvider: send_chat must be implemented by subclass.")

func fetch_models(node: Node):
	push_warning("fetch_models not implemented for this provider.")
	models_fetched.emit([], "Not implemented")

func _emit_success(response: String):
	request_completed.emit(response, "")

func _emit_error(error_msg: String):
	request_completed.emit("", error_msg)
