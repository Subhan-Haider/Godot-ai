@tool
extends Node

signal script_validation_failed(path, code, error_msg)
signal action_completed(action_name, result_data)

var pending_command: Dictionary = {}
var confirmation_dialog: AcceptDialog = null
var preview_label: RichTextLabel = null

var safe_mode: bool = false
var permissions = {
	"can_create_nodes": true,
	"can_delete_nodes": true,
	"can_modify_properties": true,
	"can_write_scripts": true,
	"can_attach_scripts": true,
	"can_instance_scenes": true,
	"can_fetch_external": true
}
var _last_written_scripts = []

func _ready():
	if Engine.is_editor_hint():
		call_deferred("_setup_dialog")

func _setup_dialog():
	confirmation_dialog = AcceptDialog.new()
	confirmation_dialog.title = "AI Action Preview"
	confirmation_dialog.ok_button_text = "Apply"
	confirmation_dialog.add_cancel_button("Cancel")
	confirmation_dialog.confirmed.connect(_on_dialog_confirmed)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	preview_label = RichTextLabel.new()
	preview_label.custom_minimum_size = Vector2(700, 400)
	preview_label.bbcode_enabled = true
	vbox.add_child(preview_label)
	
	confirmation_dialog.add_child(vbox)
	
	var base_control = EditorInterface.get_base_control()
	if base_control:
		base_control.add_child(confirmation_dialog)

func execute_command(command: Dictionary):
	if typeof(command) != TYPE_DICTIONARY:
		print("Invalid command format.")
		return
		
	var action = command.get("action", "")
	if action == "noop":
		print("AI elected to do nothing.")
		return
		
	pending_command = command
	
	if action == "explain":
		# Safe action, no dialog needed for just talking
		var text = command.get("text", "")
		print("[AI Assistant]:\\n", text)
		_on_dialog_confirmed()
		return
	
	var preview_text = "[b]AI Action:[/b] " + action + "\n"
	if command.has("name"): preview_text += "[b]Target:[/b] " + command.get("name") + "\n"
	if command.has("path"): preview_text += "[b]Path:[/b] " + command.get("path") + "\n"
	
	if action == "write_script": 
		var code = command.get("code", "")
		var path = command.get("path", "")
		if not path.begins_with("res://"): path = "res://" + path
		var old_code = ""
		if FileAccess.file_exists(path):
			var f = FileAccess.open(path, FileAccess.READ)
			if f: old_code = f.get_as_text()
			
		preview_text += "\n[b]Diff Preview:[/b]\n[code]"
		preview_text += _generate_simple_diff(old_code, code) + "[/code]"
	if action == "batch_execute":
		preview_text += "Commands Count: " + str(command.get("commands", []).size()) + "\n"
		
	if safe_mode:
		preview_text = "[color=yellow][SAFE MODE ACTIVE][/color]\n" + preview_text
		
	if confirmation_dialog:
		preview_label.text = preview_text
		confirmation_dialog.popup_centered()
	else:
		_on_dialog_confirmed() # Fallback if dialog failed

func _generate_simple_diff(old_text: String, new_text: String) -> String:
	if old_text == "":
		return "[color=green]" + new_text.replace("[", "\\[") + "[/color]"
	var old_lines = old_text.split("\n")
	var new_lines = new_text.split("\n")
	
	var diff_str = ""
	var max_l = max(old_lines.size(), new_lines.size())
	for i in range(max_l):
		if i < old_lines.size() and i < new_lines.size():
			if old_lines[i] != new_lines[i]:
				diff_str += "[color=red]- " + old_lines[i].replace("[", "\\[") + "[/color]\n"
				diff_str += "[color=green]+ " + new_lines[i].replace("[", "\\[") + "[/color]\n"
			else:
				diff_str += old_lines[i].replace("[", "\\[") + "\n"
		elif i < old_lines.size():
			diff_str += "[color=red]- " + old_lines[i].replace("[", "\\[") + "[/color]\n"
		else:
			diff_str += "[color=green]+ " + new_lines[i].replace("[", "\\[") + "[/color]\n"
	return diff_str


func _on_dialog_confirmed():
	var action = pending_command.get("action", "")
	if action == "batch_execute":
		for cmd in pending_command.get("commands", []):
			_execute_action_blind(cmd)
	else:
		_execute_action_blind(pending_command)
			
	if Engine.is_editor_hint():
		var _manager = get_node_or_null("/root/AIManager")
		if _manager and _manager._is_autonomous_mode:
			_manager.report_autonomous_step_completed()

func _execute_action_blind(cmd: Dictionary):
	var action = cmd.get("action", "")
	match action:
		"create_node":
			if not permissions["can_create_nodes"]: 
				print("Permission denied: Cannot create nodes.")
				return
			var node_type = cmd.get("type", "Node")
			var node_name = cmd.get("name", "GeneratedNode")
			var node_parent = cmd.get("parent", "")
			var node_props = cmd.get("properties", {})
			_create_node(node_type, node_name, node_parent, node_props)
		"write_script":
			if not permissions["can_write_scripts"] or safe_mode: 
				print("Permission denied / Safe Mode: Cannot write scripts.")
				return
			var path = cmd.get("path", "")
			var code = cmd.get("code", "")
			_write_script(path, code)
		"attach_script":
			if not permissions["can_attach_scripts"]: 
				print("Permission denied: Cannot attach scripts.")
				return
			var target = cmd.get("name", "")
			var path = cmd.get("path", "")
			_attach_script(target, path)
		"instance_scene":
			if not permissions["can_instance_scenes"]:
				print("Permission denied: Cannot instance scenes.")
				return
			var path = cmd.get("path", "")
			var node_name = cmd.get("name", "InstancedScene")
			var parent = cmd.get("parent", "")
			_instance_scene(path, node_name, parent)
		"save_branch_as_scene":
			var target = cmd.get("name", "")
			var path = cmd.get("path", "")
			_save_branch_as_scene(target, path)
		"generate_docs":
			var path = cmd.get("path", "")
			var text = cmd.get("text", "")
			_generate_docs(path, text)
		"download_image":
			if not permissions["can_fetch_external"]: return
			var prompt = cmd.get("image_prompt", "")
			var name = cmd.get("name", "generated_image")
			_download_image(prompt, name)
		"download_audio":
			if not permissions["can_fetch_external"]: return
			var prompt = cmd.get("audio_prompt", "")
			var name = cmd.get("name", "generated_audio")
			_download_audio(prompt, name)
		"check_project_health":
			_run_project_health_check(cmd)
		"create_animation":
			if not permissions["can_modify_properties"]: return
			var anim = cmd.get("anim_name", "new_anim")
			var target = cmd.get("node_name", "")
			var prop = cmd.get("property", "")
			var keys = cmd.get("keyframes", [])
			_create_animation(anim, target, prop, keys)
		"delete_node":
			if not permissions["can_delete_nodes"] or safe_mode: 
				print("Permission denied / Safe Mode: Cannot delete nodes.")
				return
			var target = cmd.get("name", "")
			_delete_node(target)
		"modify_property":
			if not permissions["can_modify_properties"]: return
			var target = cmd.get("name", "")
			if target == "": target = cmd.get("names", [])
			var prop = cmd.get("property", "")
			var val = cmd.get("value", "")
			_modify_property(target, prop, val)
		"rename_node":
			if not permissions["can_modify_properties"]: return
			var target = cmd.get("name", "")
			var new_name = cmd.get("new_name", "")
			_rename_node(target, new_name)
		"reparent_node":
			if not permissions["can_modify_properties"]: return
			var target = cmd.get("name", "")
			var new_parent = cmd.get("new_parent_name", "")
			_reparent_node(target, new_parent)
		"connect_signal":
			if not permissions["can_modify_properties"]: return
			var target = cmd.get("name", "")
			var sig = cmd.get("signal_name", "")
			var tgt = cmd.get("target_name", "")
			var method = cmd.get("method_name", "")
			_connect_signal(target, sig, tgt, method)
		"batch_execute":
			for c in cmd.get("commands", []):
				_execute_action_blind(c)
		"explain":
			pass
		_:
			print("Unknown AI Action: ", action)
			
	if Engine.is_editor_hint():
		var _manager = get_node_or_null("/root/AIManager")
		if _manager and _manager._is_autonomous_mode:
			_manager.report_autonomous_step_completed()

func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found = _find_node_by_name(child, target_name)
		if found: return found
	return null

func _delete_node(target_name: String):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	var node = _find_node_by_name(root, target_name)
	if node:
		node.queue_free()
		print("Deleted node: ", target_name)
	else:
		print("Could not find node to delete: ", target_name)

func _modify_property(target_names_var, property: String, value: String):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	
	var targets = []
	if typeof(target_names_var) == TYPE_ARRAY:
		targets = target_names_var
	elif typeof(target_names_var) == TYPE_STRING:
		targets = [target_names_var]
		
	if Engine.is_editor_hint(): EditorInterface.get_selection().clear()
		
	for target_name in targets:
		var node = _find_node_by_name(root, target_name)
		if node:
			var expr = Expression.new()
			var err = expr.parse(value)
			if err == OK:
				var evaluated = expr.execute()
				if not expr.has_execute_failed():
					node.set(property, evaluated)
					print("Modified property ", property, " on ", target_name, " to ", evaluated)
				else:
					print("Failed to execute parsed expression: ", value)
			else:
				node.set(property, value)
				print("Modified scalar property ", property, " on ", target_name)
				
			if Engine.is_editor_hint(): EditorInterface.get_selection().add_node(node)
		else:
			print("Could not find node to modify: ", target_name)

func _rename_node(target_name: String, new_name: String):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	var node = _find_node_by_name(root, target_name)
	if node:
		node.name = new_name
		print("Renamed ", target_name, " to ", new_name)
	else:
		print("Could not find node to rename: ", target_name)

func _reparent_node(target_name: String, new_parent_name: String):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	var node = _find_node_by_name(root, target_name)
	var parent = _find_node_by_name(root, new_parent_name)
	if node and parent:
		node.get_parent().remove_child(node)
		parent.add_child(node)
		node.owner = root
		print("Reparented ", target_name, " to ", new_parent_name)
	else:
		print("Could not find node or parent for reparenting.")

func _connect_signal(target_name: String, sig: String, connect_to: String, method: String):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	var node = _find_node_by_name(root, target_name)
	var tgt = _find_node_by_name(root, connect_to)
	if node and tgt:
		if node.has_signal(sig):
			node.connect(sig, Callable(tgt, method))
			print("Connected signal ", sig, " from ", target_name, " to ", connect_to, "::", method)
		else:
			print("Signal ", sig, " not found on ", target_name)
	else:
		print("Could not find nodes for signal connection.")

func _download_image(prompt: String, file_name: String):
	if prompt == "": return
	
	var encoded_prompt = prompt.uri_encode()
	var url = "https://image.pollinations.ai/prompt/" + encoded_prompt + "?width=512&height=512&nologo=true"
	
	print("Downloading AI Image from: ", url)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_image_downloaded.bind(http, file_name))
	http.request(url)

func _download_audio(prompt: String, file_name: String):
	# Currently a stub for a TTS or SFX API like ElevenLabs or Freesound
	print("Audio Generation Stub Invoked: ", prompt)
	print("To implement real audio generation, wire this hook to an API endpoint.")

func _create_animation(anim_name: String, target_name: String, property: String, keyframes: Array):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	
	var target = _find_node_by_name(root, target_name)
	var anim_player = _find_node_by_name(root, "AnimationPlayer")
	
	if not anim_player:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		root.add_child(anim_player)
		anim_player.owner = root
		print("Created missing AnimationPlayer.")
		
	var library: AnimationLibrary
	if anim_player.has_animation_library(""):
		library = anim_player.get_animation_library("")
	else:
		library = AnimationLibrary.new()
		anim_player.add_animation_library("", library)
	
	var anim: Animation
	if library.has_animation(anim_name):
		anim = library.get_animation(anim_name)
	else:
		anim = Animation.new()
		library.add_animation(anim_name, anim)
		
	var track_path = String(root.get_path_to(target)) + ":" + property if target else ":" + property
	var track_idx = anim.find_track(track_path, Animation.TYPE_VALUE)
	if track_idx == -1:
		track_idx = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_idx, track_path)
		
	for kf in keyframes:
		if typeof(kf) == TYPE_DICTIONARY and kf.has("time") and kf.has("value"):
			var time = float(kf["time"])
			var val_str = str(kf["value"])
			
			var expr = Expression.new()
			if expr.parse(val_str) == OK:
				var evaluated = expr.execute()
				if not expr.has_execute_failed():
					anim.track_insert_key(track_idx, time, evaluated)
				else:
					anim.track_insert_key(track_idx, time, val_str)
			else:
				anim.track_insert_key(track_idx, time, val_str)
				
	print("Created/updated animation track: ", anim_name, " for ", track_path)

func _on_image_downloaded(result, response_code, headers, body, http_node, file_name):
	http_node.queue_free()
	if response_code != 200:
		print("Failed to download image. Status: ", response_code)
		return
		
	var img = Image.new()
	var err = img.load_jpg_from_buffer(body)
	if err != OK: img.load_png_from_buffer(body) # fallback attempt
	
	var path = "res://assets/ai_generated/"
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(path):
		dir.make_dir_recursive(path)
	
	img.save_png(path + file_name + ".png")
	print("Image saved to: ", path + file_name + ".png")
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

func _create_node(type_name: String, node_name: String, parent_name: String = "", props: Dictionary = {}):
	if ClassDB.can_instantiate(type_name):
		var node = ClassDB.instantiate(type_name)
		node.name = node_name
		
		var iface = EditorInterface
		if iface and iface.get_edited_scene_root():
			var root = iface.get_edited_scene_root()
			var parent = root
			if parent_name != "":
				var p_found = _find_node_by_name(root, parent_name)
				if p_found: parent = p_found
				
			parent.add_child(node)
			node.owner = root
			
			# Apply properties
			for prop in props:
				if node is Control and prop == "layout_preset":
					node.set_anchors_and_offsets_preset(int(props[prop]))
				else:
					_set_node_property(node, prop, props[prop])
					
			print("Added node '", node_name, "' of type '", type_name, "' to scene under '", parent.name, "'.")
			
			if Engine.is_editor_hint():
				iface.get_selection().clear()
				iface.get_selection().add_node(node)
		else:
			print("No active edited scene to add node to.")
	else:
		print("Cannot instantiate Godot Class: ", type_name)


func _set_node_property(node: Node, property: String, value):
	var expr = Expression.new()
	var val_str = str(value)
	var err = expr.parse(val_str)
	if err == OK:
		var evaluated = expr.execute()
		if not expr.has_execute_failed():
			node.set(property, evaluated)
		else:
			node.set(property, value)
	else:
		node.set(property, value)

func _generate_docs(path: String, text: String):
	if not path.begins_with("res://"): path = "res://" + path
	var dir = DirAccess.open("res://")
	var base_dir = path.get_base_dir()
	if not dir.dir_exists(base_dir): dir.make_dir_recursive(base_dir)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)
		print("Documentation written to: ", path)
		if Engine.is_editor_hint(): EditorInterface.get_resource_filesystem().scan()

func _attach_script(target_name: String, path: String):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	var node = _find_node_by_name(root, target_name)
	if node:
		if not path.begins_with("res://"): path = "res://" + path
		var script = load(path)
		if script:
			node.set_script(script)
			print("Attached script ", path, " to ", target_name)
		else:
			print("Failed to load script: ", path)
	else:
		print("Could not find node to attach script: ", target_name)


func _instance_scene(path: String, node_name: String, parent_name: String = ""):
	if not path.begins_with("res://"): path = "res://" + path
	if not FileAccess.file_exists(path):
		print("Error: Scene file does not exist: ", path)
		return
		
	var scene = load(path)
	if scene is PackedScene:
		var instance = scene.instantiate()
		instance.name = node_name
		
		var iface = EditorInterface
		var root = iface.get_edited_scene_root()
		var parent = root
		if parent_name != "":
			var p_found = _find_node_by_name(root, parent_name)
			if p_found: parent = p_found
			
		parent.add_child(instance)
		instance.owner = root
		print("Instanced scene '", path, "' as '", node_name, "'.")
		
		if Engine.is_editor_hint():
			iface.get_selection().clear()
			iface.get_selection().add_node(instance)
	else:
		print("Error: Loaded resource is not a PackedScene: ", path)


func _save_branch_as_scene(target_name: String, path: String):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	var node = _find_node_by_name(root, target_name)
	if not node:
		print("Error: Node not found for saving as scene: ", target_name)
		return
		
	if not path.begins_with("res://"): path = "res://" + path
	if not path.ends_with(".tscn"): path += ".tscn"
	
	var packed = PackedScene.new()
	var err = packed.pack(node)
	if err == OK:
		ResourceSaver.save(packed, path)
		print("Saved node '", target_name, "' as scene: ", path)
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()
	else:
		print("Error packing scene: ", err)

func _write_script(path: String, code: String):
	if path == "":
		print("Error: Empty path for write_script.")
		return
		
	if not path.begins_with("res://"):
		path = "res://" + path
		
	# Security/Safety: Auto Backup existing files
	if FileAccess.file_exists(path):
		var backup_path = path.get_base_dir() + "/" + path.get_file().get_basename() + "_backup.gd"
		var dir = DirAccess.open("res://")
		if dir:
			dir.copy(path, backup_path)
			print("Created automatic safety backup at: ", backup_path)
			_last_written_scripts.append({"path": path, "backup": backup_path})
		
	var dir = DirAccess.open("res://")
	var base_dir = path.get_base_dir()
	if not dir.dir_exists(base_dir):
		dir.make_dir_recursive(base_dir)
		
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("Error opening file for write: ", path)
		return
		
	f.store_string(code)
	f.close()
	print("Script written to: ", path)
	
	# Validation Step for Auto-Fix
	var validation_error = _validate_script(code)
	if validation_error != "":
		print("Warning: Generated script has parse errors: ", validation_error)
		script_validation_failed.emit(path, code, validation_error)
	
	if Engine.is_editor_hint():
		# Refresh editor filesystem to show the new script
		EditorInterface.get_resource_filesystem().scan()

func rollback_last_script():
	if _last_written_scripts.size() == 0:
		print("No scripts to rollback.")
		return
	
	var last = _last_written_scripts.pop_back()
	var path = last["path"]
	var backup = last["backup"]
	
	var dir = DirAccess.open("res://")
	if dir and FileAccess.file_exists(backup):
		dir.copy(backup, path)
		print("Rollback successful. Restored ", path, " from ", backup)
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()
	else:
		print("Failed to rollback. Backup not found: ", backup)

func _validate_script(code: String) -> String:
	var script = GDScript.new()
	script.source_code = code
	var err = script.reload()
	if err != OK:
		return "Syntax Error. Code: " + str(err)
	return ""
func _run_project_health_check(command: Dictionary):
	var dir_path = command.get("directory", "res://")
	var results = []
	var dir = DirAccess.open(dir_path)
	if dir:
		_scan_and_validate(dir, dir_path, results)
	
	var report = "Project Health Report for " + dir_path + ":\n"
	if results.size() == 0:
		report += "[OK] All scripts are syntax-error free!"
	else:
		report += "[ERR] Found " + str(results.size()) + " scripts with errors:\n"
		for res in results:
			report += "- " + res["path"] + ": " + res["error"] + "\n"
	
	print(report)
	action_completed.emit("check_project_health", {"report": report, "errors": results})

func _scan_and_validate(dir: DirAccess, path: String, results: Array):
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and file_name != "." and file_name != ".." and file_name != ".godot":
			var sub_dir = DirAccess.open(path.path_join(file_name))
			if sub_dir:
				_scan_and_validate(sub_dir, path.path_join(file_name), results)
		elif not dir.current_is_dir() and file_name.ends_with(".gd"):
			var full_path = path.path_join(file_name)
			var code = FileAccess.get_file_as_string(full_path)
			var err = _validate_script(code)
			if err != "":
				results.append({"path": full_path, "error": err})
		file_name = dir.get_next()
