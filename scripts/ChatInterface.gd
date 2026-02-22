extends Control

## Void Crawler: AI Architect Edition - In-Game Neural Link
## Toggle with TAB. Command the AI to reshape reality.

@onready var input_field: LineEdit = $Panel/Input
@onready var chat_log: RichTextLabel = $Panel/History

func _ready() -> void:
	hide()
	input_field.text_submitted.connect(_on_input_submitted)
	
	var manager = get_node_or_null("/root/AIManager")
	if manager:
		manager.ai_response_received.connect(_on_ai_response)
		manager.ai_error.connect(_on_ai_error)
		manager.stream_chunk_received.connect(_on_stream_chunk)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next"): # TAB key
		visible = !visible
		if visible:
			input_field.grab_focus()
			get_tree().paused = true # Optional: Pause while typing
		else:
			input_field.release_focus()
			get_tree().paused = false

func _on_input_submitted(new_text: String) -> void:
	if new_text.strip_edges() == "": return
	
	_log_message("USER", new_text)
	input_field.clear()
	
	var manager = get_node_or_null("/root/AIManager")
	if manager:
		_first_chunk = true
		manager.send_prompt(new_text)
	else:
		_log_message("ERROR", "AIManager singleton not found!")

var _first_chunk = true
func _on_stream_chunk(token: String):
	if _first_chunk:
		chat_log.append_text("[color=yellow][b]AI:[/b][/color] ")
		_first_chunk = false
	chat_log.append_text(token)

func _on_ai_response(data: Dictionary) -> void:
	chat_log.append_text("\n") # Newline after stream
	
	var executor = get_node_or_null("/root/AIExecutor")
	if executor:
		executor.execute_command(data)

func _on_ai_error(msg: String) -> void:
	_log_message("ERROR", msg)

func _log_message(sender: String, msg: String) -> void:
	var color = "cyan"
	match sender:
		"USER": color = "white"
		"AI": color = "yellow"
		"ERROR": color = "red"
		"SYSTEM": color = "gray"
	
	chat_log.append_text("[color=%s][b]%s:[/b][/color] %s\n" % [color, sender, msg])
