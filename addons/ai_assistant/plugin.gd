## AI Assistant Plugin Entry Point - Watcher Active Check
## Registers the dock, initialises core services, and wires everything together.
@tool
extends EditorPlugin

const MainDock = preload("res://addons/ai_assistant/ui/MainDock.gd")

var _dock: Control = null


func _enter_tree() -> void:
	_dock = MainDock.new()
	_dock.name = "AI Assistant"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)
	_dock.initialize(get_editor_interface())
	print("[AI Assistant] Plugin loaded.")


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	print("[AI Assistant] Plugin unloaded.")
