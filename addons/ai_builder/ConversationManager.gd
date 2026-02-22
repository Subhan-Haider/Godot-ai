@tool
extends Node

## ConversationManager - Handles multi-turn chat history for AI Builder.
## Can save and load history to/from project local files.

class_name ConversationManager

var history: Array = [] # Array of { "role": string, "content": string }
var save_path: String = "user://ai_builder_history.json"

func add_message(role: String, content: String):
	history.append({
		"role": role,
		"content": content
	})
	_auto_save()

func get_messages() -> Array:
	return history

func clear():
	history.clear()
	_auto_save()

func _auto_save():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(history))
		file.close()

func load_history():
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			var test_json_conv = JSON.new()
			var err = test_json_conv.parse(file.get_as_text())
			if err == OK:
				history = test_json_conv.data
			file.close()
