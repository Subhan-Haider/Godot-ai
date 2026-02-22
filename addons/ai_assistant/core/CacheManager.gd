## CacheManager - simple on-disk JSON cache keyed by prompt hash.
@tool
class_name CacheManager
extends RefCounted

const CACHE_PATH := "user://ai_assistant_cache.json"
const MAX_ENTRIES := 200

var _cache: Dictionary = {}
var _enabled: bool     = true


func setup() -> void:
	_load()


func set_enabled(v: bool) -> void:
	_enabled = v


func get(prompt: String):
	if not _enabled: return null
	var key := _hash(prompt)
	return _cache.get(key, null)


func store(prompt: String, response: String) -> void:
	if not _enabled: return
	var key := _hash(prompt)
	_cache[key] = response
	# Evict oldest entries if over limit
	while _cache.size() > MAX_ENTRIES:
		_cache.erase(_cache.keys()[0])
	_save()


func clear() -> void:
	_cache.clear()
	_save()


func _hash(s: String) -> String:
	return str(s.hash())


func _load() -> void:
	if not FileAccess.file_exists(CACHE_PATH): return
	var f := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not f: return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK:
		var d = json.get_data()
		if typeof(d) == TYPE_DICTIONARY:
			_cache = d


func _save() -> void:
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_cache))
