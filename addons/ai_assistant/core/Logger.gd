## Logger — Centralised, levelled logging system.
## All plugin modules write through this. Emits signals so the debug UI can subscribe.
@tool
class_name AILogger
extends RefCounted

enum Level { DEBUG, INFO, WARN, ERROR }

signal log_entry_added(level: int, category: String, message: String, timestamp: float)

## Max entries kept in memory.
const MAX_ENTRIES := 500

var _entries: Array = []
var _min_level: int = Level.DEBUG


## Set minimum log level displayed (DEBUG/INFO/WARN/ERROR).
func set_min_level(level: int) -> void:
	_min_level = level


func debug(category: String, msg: String) -> void:
	_write(Level.DEBUG, category, msg)

func info(category: String, msg: String) -> void:
	_write(Level.INFO, category, msg)

func warn(category: String, msg: String) -> void:
	_write(Level.WARN, category, msg)

func error(category: String, msg: String) -> void:
	_write(Level.ERROR, category, msg)


func get_entries(level_filter: int = -1) -> Array:
	if level_filter == -1:
		return _entries.duplicate()
	return _entries.filter(func(e): return e["level"] >= level_filter)


func clear() -> void:
	_entries.clear()


func _write(level: int, category: String, msg: String) -> void:
	if level < _min_level:
		return

	var entry := {
		"level":     level,
		"category":  category,
		"message":   msg,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	_entries.append(entry)
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()

	var prefix := ["[DBG]", "[INF]", "[WRN]", "[ERR]"][level]
	print("[AI Assistant] %s [%s] %s" % [prefix, category, msg])
	log_entry_added.emit(level, category, msg, entry["timestamp"])
