## ConversationHistory — rolling window of messages for multi-turn conversations.
@tool
class_name ConversationHistory
extends RefCounted

const MAX_TURNS := 12  # keep last N user+assistant pairs

var _messages: Array = []


func add(role: String, content: String) -> void:
	_messages.append({ "role": role, "content": content })
	# Trim to window: keep system messages + last MAX_TURNS * 2 messages
	var non_system := _messages.filter(func(m): return m["role"] != "system")
	while non_system.size() > MAX_TURNS * 2:
		# Remove oldest non-system pair
		for i in range(_messages.size()):
			if _messages[i]["role"] != "system":
				_messages.remove_at(i)
				break
		non_system = _messages.filter(func(m): return m["role"] != "system")


## Returns messages suitable for injection INTO the messages array (no system msg).
func get_messages() -> Array:
	return _messages.filter(func(m): return m["role"] != "system")


func clear() -> void:
	_messages.clear()


func size() -> int:
	return _messages.size()
