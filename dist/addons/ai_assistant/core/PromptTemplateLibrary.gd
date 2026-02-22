## PromptTemplateLibrary — built-in and user-defined prompt templates.
@tool
class_name PromptTemplateLibrary
extends RefCounted

const USER_TEMPLATES_PATH := "user://ai_assistant_templates.json"

## Built-in templates — never modified.
const BUILT_IN: Array = [
	{ "name": "2D Player",          "prompt": "Create a CharacterBody2D named 'Player'. Add CollisionShape2D and Sprite2D children. Write a complete GDScript for WASD movement, jump, and gravity. Use the write_script action." },
	{ "name": "3D Environment",     "prompt": "Generate a full 3D environment using batch action: Camera3D named 'MainCamera', DirectionalLight3D named 'Sun', StaticBody3D named 'Ground' with a MeshInstance3D child." },
	{ "name": "Main Menu UI",       "prompt": "Generate a main menu UI with batch action: CanvasLayer root, Panel background, VBoxContainer, 'Start' Button, 'Options' Button, 'Quit' Button. Connect Quit.pressed to quit the game." },
	{ "name": "Enemy State Machine","prompt": "Write a GDScript state machine for an enemy NPC with IDLE, PATROL, CHASE, and ATTACK states. Save to res://scripts/enemy_ai.gd." },
	{ "name": "Tilemap Generator",  "prompt": "Using create_node and batch actions, build a Node2D scene with a TileMapLayer named 'LevelMap', a Camera2D named 'MainCamera', and a DirectionalLight2D named 'WorldLight'." },
	{ "name": "Explain Script",     "prompt": "Analyse the active script in my context. List potential bugs, memory leaks, and performance optimisations. Use the explain action." },
	{ "name": "Refactor Script",    "prompt": "Read the active script. Refactor it for GDScript best practices, clean architecture, and Godot 4 idioms. Use write_script to overwrite it." },
	{ "name": "Add Comments",       "prompt": "Read the active script. Add comprehensive docstrings and inline comments. Use write_script to overwrite." },
	{ "name": "Generate Unit Tests","prompt": "Read the active script. Generate a GUT (Godot Unit Test) test suite. Save to res://tests/test_[script_name].gd." },
	{ "name": "Generate README",    "prompt": "Read the active script and scene tree. Generate a comprehensive markdown README for this feature. Use generate_docs." },
	{ "name": "NPC Balancing",      "prompt": "Act as a game systems designer. Using the active script context, generate a JSON balance table for enemy stats across 10 difficulty levels. Use explain." },
	{ "name": "Debug Analysis",     "prompt": "Analyse the active script for potential null reference errors, unchecked signals, and missing @export annotations. Use explain." },
]

var _user_templates: Array = []


func setup() -> void:
	_load_user()


func get_all() -> Array:
	return BUILT_IN + _user_templates


func get_names() -> Array:
	return get_all().map(func(t): return t["name"])


func get_prompt(name: String) -> String:
	for t in get_all():
		if t["name"] == name: return t["prompt"]
	return ""


func add_user_template(name: String, prompt: String) -> void:
	_user_templates.append({ "name": name, "prompt": prompt })
	_save_user()


func remove_user_template(name: String) -> void:
	_user_templates = _user_templates.filter(func(t): return t["name"] != name)
	_save_user()


func _load_user() -> void:
	if not FileAccess.file_exists(USER_TEMPLATES_PATH): return
	var f := FileAccess.open(USER_TEMPLATES_PATH, FileAccess.READ)
	if not f: return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK:
		var d = json.get_data()
		if typeof(d) == TYPE_ARRAY: _user_templates = d


func _save_user() -> void:
	var f := FileAccess.open(USER_TEMPLATES_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(_user_templates, "\t"))
