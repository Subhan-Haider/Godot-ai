@tool
extends EditorPlugin

var dock

func _enter_tree():
	print("AI Builder: Initializing Plugin...")
	add_autoload_singleton("AIManager", "res://addons/ai_builder/AIManager.gd")
	add_autoload_singleton("AIExecutor", "res://addons/ai_builder/AIExecutor.gd")
	
	dock = preload("res://addons/ai_builder/UI/AIBuilderDock.gd").new()
	add_control_to_dock(DOCK_SLOT_LEFT_BR, dock)
	print("AI Builder: Dock added to Editor.")

func _exit_tree():
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
	
	remove_autoload_singleton("AIManager")
	remove_autoload_singleton("AIExecutor")
