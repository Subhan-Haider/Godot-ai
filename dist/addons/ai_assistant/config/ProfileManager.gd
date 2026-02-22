## ProfileManager - saves and loads provider configuration profiles.
## Profiles are stored as JSON in user://ai_assistant_profiles/
@tool
class_name ProfileManager
extends RefCounted

const PROFILE_DIR  := "user://ai_assistant_profiles/"
const DEFAULT_NAME := "default"

var _logger: AILogger = null


func setup(logger: AILogger) -> void:
	_logger = logger
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists(PROFILE_DIR):
		dir.make_dir_recursive(PROFILE_DIR)


## Returns the default config dict (merged with defaults for missing keys).
func load_profile(name: String = DEFAULT_NAME) -> Dictionary:
	var path := PROFILE_DIR + name + ".json"
	var defaults := _defaults()

	if not FileAccess.file_exists(path):
		return defaults

	var f := FileAccess.open(path, FileAccess.READ)
	if not f: return defaults

	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		if _logger: _logger.warn("ProfileManager", "Could not parse profile '%s'." % name)
		return defaults

	var d = json.get_data()
	if typeof(d) != TYPE_DICTIONARY: return defaults

	# Merge with defaults to ensure all keys exist
	for k in defaults:
		if not d.has(k): d[k] = defaults[k]
	return d


func save_profile(config: Dictionary, name: String = DEFAULT_NAME) -> void:
	var path := PROFILE_DIR + name + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		if _logger: _logger.error("ProfileManager", "Could not write profile '%s'." % name)
		return
	f.store_string(JSON.stringify(config, "\t"))
	if _logger: _logger.info("ProfileManager", "Profile '%s' saved." % name)


func list_profiles() -> Array:
	var dir := DirAccess.open(PROFILE_DIR)
	if not dir: return [DEFAULT_NAME]
	var out: Array = []
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if item.ends_with(".json"):
			out.append(item.get_basename())
		item = dir.get_next()
	return out


func _defaults() -> Dictionary:
	return {
		"active_provider": "openai",
		"api_keys": {
			"openai": "", "openrouter": "", "gemini": "",
			"grok": "", "huggingface": "", "custom": ""
		},
		"models": {
			"openai": "gpt-4o", "openrouter": "openai/gpt-4o",
			"gemini": "gemini-1.5-pro", "grok": "grok-2-latest",
			"huggingface": "mistralai/Mistral-7B-Instruct-v0.3",
			"ollama": "llama3", "custom": ""
		},
		"endpoints": {
			"ollama": "http://localhost:11434/api/chat", "custom": ""
		},
		"temperature": 0.7,
		"max_tokens":  2048,
		"streaming":   false,
		"safe_mode":   false,
		"hybrid_mode": true,
		"cache_enabled": true,
		"permissions": {
			"create_nodes":  true,
			"delete_nodes":  true,
			"write_scripts": true,
			"fetch_external": true
		}
	}
