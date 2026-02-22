## ContextCollector — gathers scene tree, script list, assets, project settings.
## Produces a compact string injected into every system prompt.
@tool
class_name ContextCollector
extends RefCounted

var _editor: EditorInterface = null


func setup(editor: EditorInterface) -> void:
	_editor = editor


## Returns a formatted context block for prompt injection.
func collect() -> String:
	var parts: Array = []

	parts.append(_scene_context())
	parts.append(_script_context())
	parts.append(_asset_context())
	parts.append(_settings_context())

	return (parts.filter(func(p): return p != "")).join("\n\n")


# ---------------------------------------------------------------------------
# Scene tree summary
# ---------------------------------------------------------------------------

func _scene_context() -> String:
	if not _editor: return ""
	var root := _editor.get_edited_scene_root()
	if not root: return "No scene currently open."

	var lines: Array = ["=== Scene Tree ==="]
	lines.append("Root: %s (%s)" % [root.name, root.get_class()])
	_append_children(root, lines, 1, 0, 4)
	return "\n".join(lines)


func _append_children(node: Node, lines: Array, depth: int, count: int, max_depth: int) -> int:
	if depth > max_depth: return count
	for child in node.get_children():
		lines.append("  ".repeat(depth) + "- %s (%s)" % [child.name, child.get_class()])
		count += 1
		if count >= 60:
			lines.append("  ".repeat(depth) + "... (truncated)")
			return count
		count = _append_children(child, lines, depth + 1, count, max_depth)
	return count


# ---------------------------------------------------------------------------
# Open script
# ---------------------------------------------------------------------------

func _script_context() -> String:
	if not _editor: return ""
	var se := _editor.get_script_editor()
	if not se: return ""
	var script := se.get_current_script()
	if not script: return ""

	var code: String = script.source_code
	# Truncate very large scripts to avoid blowing context
	const MAX_CHARS := 3000
	if code.length() > MAX_CHARS:
		code = code.substr(0, MAX_CHARS) + "\n... (truncated)"

	return "=== Active Script: %s ===\n```gdscript\n%s\n```" % [script.resource_path, code]


# ---------------------------------------------------------------------------
# Asset index (first 40 files under res://)
# ---------------------------------------------------------------------------

func _asset_context() -> String:
	var dir := DirAccess.open("res://")
	if not dir: return ""
	var files: Array = []
	_scan_dir(dir, "res://", files, 0)
	return "=== Project Assets (sample) ===\n" + "\n".join(files)


func _scan_dir(dir: DirAccess, path: String, out: Array, depth: int) -> void:
	if depth > 3 or out.size() >= 40: return
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "" and out.size() < 40:
		if item.begins_with("."): item = dir.get_next(); continue
		var full := path.path_join(item)
		if dir.current_is_dir():
			var sub := DirAccess.open(full)
			if sub: _scan_dir(sub, full, out, depth + 1)
		else:
			if not item.ends_with(".import"):
				out.append(full)
		item = dir.get_next()


# ---------------------------------------------------------------------------
# Project settings snapshot
# ---------------------------------------------------------------------------

func _settings_context() -> String:
	var lines: Array = ["=== Project Settings ==="]
	var viewport_w = ProjectSettings.get_setting("display/window/size/viewport_width", 1280)
	var viewport_h = ProjectSettings.get_setting("display/window/size/viewport_height", 720)
	var main_scene = ProjectSettings.get_setting("application/run/main_scene", "")
	var proj_name  = ProjectSettings.get_setting("application/config/name", "")

	lines.append("Name: " + str(proj_name))
	lines.append("Viewport: %dx%d" % [viewport_w, viewport_h])
	lines.append("Main scene: " + str(main_scene))
	return "\n".join(lines)
