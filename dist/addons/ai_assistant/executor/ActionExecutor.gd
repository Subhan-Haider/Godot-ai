## ActionExecutor - dispatches structured AI responses into real editor operations.
##
## Every action is:
##   1. Validated
##   2. Previewed (confirmation dialog)
##   3. Executed
##   4. Registered with UndoManager for undo support
##   5. Backed up (for scripts)
@tool
class_name ActionExecutor
extends Node

signal action_completed(action: String, detail: String)
signal action_failed(action: String, reason: String)

var _editor:     EditorInterface = null
var _logger:     AILogger        = null
var _undo_redo:  EditorUndoRedoManager = null
var _dialog:     AcceptDialog    = null
var _diff_label: RichTextLabel   = null
var _pending:    Dictionary      = {}
var _backup_stack: Array         = []

## Permissions dict (mirrors ProfileManager defaults)
var permissions: Dictionary = {
	"create_nodes":   true,
	"delete_nodes":   true,
	"write_scripts":  true,
	"fetch_external": true
}
var safe_mode: bool = false


func setup(editor: EditorInterface, logger: AILogger) -> void:
	_editor   = editor
	_logger   = logger
	_undo_redo = editor.get_editor_undo_redo()
	call_deferred("_build_dialog")


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

## Validate, preview, then execute the structured dict from AIOrchestrator.
func execute(data: Dictionary) -> void:
	var action: String = data.get("action", "noop")

	if action == "noop":
		_logger.info("Executor", "Action: noop - nothing to do.")
		return

	if action == "explain":
		var text: String = data.get("explanation", data.get("code", ""))
		_logger.info("Executor", "AI explanation:\n%s" % text)
		action_completed.emit("explain", text)
		return

	# Safety gate
	if not _permission_check(action):
		var reason := "Permission denied for action '%s'." % action
		_logger.warn("Executor", reason)
		action_failed.emit(action, reason)
		return

	_pending = data
	_show_preview(data)


# ---------------------------------------------------------------------------
# Dialog
# ---------------------------------------------------------------------------

func _build_dialog() -> void:
	_dialog = AcceptDialog.new()
	_dialog.title = "AI Action Preview"
	_dialog.ok_button_text = "[OK] Apply"
	_dialog.add_cancel_button("[X] Cancel")
	_dialog.confirmed.connect(_on_confirmed)

	var vbox := VBoxContainer.new()
	_diff_label = RichTextLabel.new()
	_diff_label.bbcode_enabled = true
	_diff_label.custom_minimum_size = Vector2(720, 440)
	vbox.add_child(_diff_label)
	_dialog.add_child(vbox)

	var base := _editor.get_base_control()
	if base: base.add_child(_dialog)


func _show_preview(data: Dictionary) -> void:
	if not _dialog:
		_on_confirmed()
		return

	var action: String = data.get("action", "")
	var text := "[b]Action:[/b] %s\n" % action

	if data.has("nodes") and not data["nodes"].is_empty():
		for n in data["nodes"]:
			text += "  Node: [b]%s[/b] (%s)\n" % [n.get("name","?"), n.get("type","?")]

	if action == "write_script" or action == "generate_docs":
		var path  := _node_path(data)
		var code  := str(data.get("code", ""))
		var old   := _read_file(path)
		text += "\n[b]Path:[/b] %s\n" % path
		text += "\n[b]Diff:[/b]\n[code]%s[/code]" % _diff(old, code)

	if action == "batch":
		text += "Sub-commands: [b]%d[/b]\n" % data.get("commands",[]).size()

	if safe_mode:
		text = "[color=yellow][SAFE MODE][/color]\n" + text

	_diff_label.text = text
	_dialog.popup_centered()


func _on_confirmed() -> void:
	var action: String = _pending.get("action", "noop")
	match action:
		"batch":         _exec_batch(_pending)
		"create_node":   _exec_create(_pending)
		"delete_node":   _exec_delete(_pending)
		"modify_node":   _exec_modify(_pending)
		"reparent_node": _exec_reparent(_pending)
		"connect_signal":_exec_connect(_pending)
		"write_script":  _exec_write_script(_pending)
		"generate_docs": _exec_generate_docs(_pending)
		"attach_script": _exec_attach_script(_pending)
		_:               _logger.warn("Executor", "Unknown action '%s'." % action)

	action_completed.emit(action, "")
	_logger.info("Executor", "Action '%s' applied." % action)


# ---------------------------------------------------------------------------
# Action implementations
# ---------------------------------------------------------------------------

func _exec_batch(data: Dictionary) -> void:
	for cmd in data.get("commands", []):
		var sub_action: String = cmd.get("action","")
		if sub_action == "explain": continue
		if not _permission_check(sub_action): continue
		_dispatch_single(cmd)


func _dispatch_single(cmd: Dictionary) -> void:
	match cmd.get("action",""):
		"create_node":   _exec_create(cmd)
		"delete_node":   _exec_delete(cmd)
		"modify_node":   _exec_modify(cmd)
		"reparent_node": _exec_reparent(cmd)
		"connect_signal":_exec_connect(cmd)
		"write_script":  _exec_write_script(cmd)
		"attach_script": _exec_attach_script(cmd)


func _exec_create(data: Dictionary) -> void:
	if not permissions["create_nodes"]: return
	var root := _edited_root()
	if not root: return

	var nodes_to_create: Array = data.get("nodes", [])
	if nodes_to_create.is_empty():
		# Backwards-compat: single node described at top level
		nodes_to_create = [{ "type": data.get("type","Node"), "name": data.get("name","NewNode"), "parent": "" }]

	_undo_redo.create_action("AI: Create nodes")
	for spec in nodes_to_create:
		var type_name: String = spec.get("type", "Node")
		var node_name: String = spec.get("name", "NewNode")
		var par_name:  String = spec.get("parent", "")
		var props:     Dictionary = spec.get("properties", {})

		if not ClassDB.can_instantiate(type_name):
			_logger.warn("Executor", "Cannot instantiate type '%s'." % type_name)
			continue

		var node := ClassDB.instantiate(type_name)
		node.name = node_name

		var parent: Node = root
		if par_name != "":
			var p := _find_node(root, par_name)
			if p: parent = p

		_undo_redo.add_do_method(parent, "add_child", node)
		_undo_redo.add_do_method(node,   "set_owner", root)
		_undo_redo.add_undo_method(parent,"remove_child", node)

		parent.add_child(node)
		node.owner = root

		# Apply initial properties
		for prop in props:
			var expr := Expression.new()
			if expr.parse(str(props[prop])) == OK:
				var v = expr.execute()
				if not expr.has_execute_failed():
					node.set(prop, v)
				else:
					node.set(prop, props[prop])

		_logger.info("Executor", "Created %s '%s' under '%s'." % [type_name, node_name, parent.name])

		if Engine.is_editor_hint():
			_editor.get_selection().clear()
			_editor.get_selection().add_node(node)

	_undo_redo.commit_action()


func _exec_delete(data: Dictionary) -> void:
	if not permissions["delete_nodes"] or safe_mode: return
	var root := _edited_root()
	if not root: return
	var target_name: String = data.get("name", "")
	var node := _find_node(root, target_name)
	if not node:
		_logger.warn("Executor", "Delete: node '%s' not found." % target_name)
		return
	_undo_redo.create_action("AI: Delete node")
	_undo_redo.add_do_method(node.get_parent(), "remove_child", node)
	_undo_redo.add_undo_method(node.get_parent(), "add_child", node)
	_undo_redo.commit_action()
	node.queue_free()
	_logger.info("Executor", "Deleted node '%s'." % target_name)


func _exec_modify(data: Dictionary) -> void:
	var root := _edited_root()
	if not root: return
	var name: String = data.get("name","")
	var props: Dictionary = data.get("properties", {})
	var node := _find_node(root, name)
	if not node: return

	_undo_redo.create_action("AI: Modify node")
	for prop in props:
		var old_val = node.get(prop)
		var expr := Expression.new()
		var new_val = props[prop]
		if expr.parse(str(new_val)) == OK:
			var v = expr.execute()
			if not expr.has_execute_failed(): new_val = v

		_undo_redo.add_do_property(node, prop, new_val)
		_undo_redo.add_undo_property(node, prop, old_val)
		node.set(prop, new_val)
	_undo_redo.commit_action()
	_logger.info("Executor", "Modified node '%s'." % name)


func _exec_reparent(data: Dictionary) -> void:
	var root := _edited_root()
	if not root: return
	var node   := _find_node(root, data.get("name",""))
	var parent := _find_node(root, data.get("parent",""))
	if not node or not parent: return

	var old_parent := node.get_parent()
	_undo_redo.create_action("AI: Reparent node")
	_undo_redo.add_do_method(old_parent, "remove_child", node)
	_undo_redo.add_do_method(parent,     "add_child",    node)
	_undo_redo.add_undo_method(parent,    "remove_child", node)
	_undo_redo.add_undo_method(old_parent,"add_child",    node)
	_undo_redo.commit_action()
	old_parent.remove_child(node)
	parent.add_child(node)
	node.owner = root
	_logger.info("Executor", "Reparented '%s' -> '%s'." % [node.name, parent.name])


func _exec_connect(data: Dictionary) -> void:
	var root := _edited_root()
	if not root: return
	var src := _find_node(root, data.get("name",""))
	var tgt := _find_node(root, data.get("target",""))
	if not src or not tgt: return
	var sig    : String = data.get("signal","")
	var method : String = data.get("method","")
	if src.has_signal(sig) and not src.is_connected(sig, Callable(tgt, method)):
		src.connect(sig, Callable(tgt, method))
		_logger.info("Executor", "Connected %s.%s -> %s.%s" % [src.name, sig, tgt.name, method])


func _exec_write_script(data: Dictionary) -> void:
	if not permissions["write_scripts"] or safe_mode: return

	var path: String = _node_path(data)
	if path == "": return

	var code: String = str(data.get("code", ""))
	if not path.begins_with("res://"): path = "res://" + path

	# Backup existing file
	if FileAccess.file_exists(path):
		var backup_path := path.get_basename() + "_backup.gd"
		var dir := DirAccess.open("res://")
		if dir:
			dir.copy(path, backup_path)
			_backup_stack.append({ "path": path, "backup": backup_path })
			_logger.info("Executor", "Backed up '%s' → '%s'." % [path, backup_path])

	var dir := DirAccess.open("res://")
	if dir:
		var base_dir := path.get_base_dir()
		if not dir.dir_exists(base_dir): dir.make_dir_recursive(base_dir)

	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		_logger.error("Executor", "Cannot open '%s' for writing." % path)
		return
	f.store_string(code)
	f.close()
	_logger.info("Executor", "Script written to '%s'." % path)

	if Engine.is_editor_hint():
		_editor.get_resource_filesystem().scan()


func _exec_generate_docs(data: Dictionary) -> void:
	var path: String = _node_path(data)
	if path == "": return
	if not path.ends_with(".md"): path = path.get_basename() + ".md"
	var content: String = str(data.get("code", data.get("explanation", "")))

	var dir := DirAccess.open("res://")
	if dir:
		var base := path.get_base_dir()
		if base != "" and not dir.dir_exists(base): dir.make_dir_recursive(base)

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		_logger.info("Executor", "Docs written to '%s'." % path)
		if Engine.is_editor_hint(): _editor.get_resource_filesystem().scan()


func _exec_attach_script(data: Dictionary) -> void:
	var root := _edited_root()
	if not root: return
	var n := _find_node(root, data.get("name",""))
	if not n: return

	var path: String = str(data.get("path", data.get("code","")))
	if not path.begins_with("res://"): path = "res://" + path
	var script = load(path)
	if script:
		n.set_script(script)
		_logger.info("Executor", "Attached '%s' to '%s'." % [path, n.name])
	else:
		_logger.warn("Executor", "Could not load script '%s'." % path)


## Undo the last script write.
func rollback_last_script() -> void:
	if _backup_stack.is_empty():
		_logger.info("Executor", "Nothing to roll back.")
		return
	var entry := _backup_stack.pop_back()
	var dir   := DirAccess.open("res://")
	if dir and FileAccess.file_exists(entry["backup"]):
		dir.copy(entry["backup"], entry["path"])
		_logger.info("Executor", "Rolled back '%s'." % entry["path"])
		if Engine.is_editor_hint(): _editor.get_resource_filesystem().scan()
	else:
		_logger.warn("Executor", "Backup not found: '%s'." % entry["backup"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _edited_root() -> Node:
	if not _editor: return null
	var root := _editor.get_edited_scene_root()
	if not root:
		_logger.warn("Executor", "No active scene.")
	return root


func _find_node(root: Node, name: String) -> Node:
	if name == "" or name == root.name: return root
	return _search(root, name)


func _search(node: Node, name: String) -> Node:
	if node.name == name: return node
	for c in node.get_children():
		var r := _search(c, name)
		if r: return r
	return null


func _permission_check(action: String) -> bool:
	if safe_mode and action in ["delete_node", "write_script"]: return false
	if action == "create_node" and not permissions.get("create_nodes", true): return false
	if action == "delete_node" and not permissions.get("delete_nodes", true): return false
	if action == "write_script" and not permissions.get("write_scripts", true): return false
	return true


## Extract the file path from data — checks nodes[0].path, then top-level "path".
func _node_path(data: Dictionary) -> String:
	var nodes: Array = data.get("nodes", [])
	if not nodes.is_empty():
		var p: String = nodes[0].get("path", "")
		if p != "": return p
	return data.get("path", "")


func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path): return ""
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


## Simple line-by-line diff returning BBCode string.
func _diff(old_text: String, new_text: String) -> String:
	if old_text == "":
		return "[color=green]" + new_text.replace("[","\\[") + "[/color]"
	var old_lines := old_text.split("\n")
	var new_lines := new_text.split("\n")
	var out := ""
	var lim  := maxi(old_lines.size(), new_lines.size())
	for i in range(mini(lim, 120)):  # cap diff at 120 lines for performance
		var ol := old_lines[i] if i < old_lines.size() else ""
		var nl := new_lines[i] if i < new_lines.size() else ""
		if ol != nl:
			out += "[color=red]- " + ol.replace("[","\\[")  + "[/color]\n"
			out += "[color=green]+ " + nl.replace("[","\\[") + "[/color]\n"
		else:
			out += nl.replace("[","\\[") + "\n"
	return out
