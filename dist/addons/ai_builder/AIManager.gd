@tool
extends Node

var current_provider: Object = null
var provider_id: String = "openrouter"

signal ai_response_received(structured_data)
signal ai_error(message)
signal usage_updated(requests, tokens, latency_ms)
signal models_fetched(models)
signal stream_chunk_received(token: String)
signal stream_completed(full_text: String)
signal autonomous_steps_ready(steps: Array)
signal autonomous_step_completed(index: int, total: int, task: String)
signal key_validation_completed(is_valid, message)

var _is_initialized: bool = false

var request_start_time: int = 0
var total_requests: int = 0
var estimated_tokens: int = 0
var _retry_attempts = 0
var max_retries = 2
var _last_failed_prompt = ""
var conversation_manager: Node = null

var fallback_enabled: bool = true
var smart_routing_enabled: bool = true
var hybrid_mode: bool = true  # Try free providers first, fall to paid if unavailable
var fallback_order = ["ollama", "openrouter", "gemini", "huggingface", "custom"]
var _free_providers = ["ollama"]
var _paid_providers = ["openrouter", "gemini", "huggingface", "custom"]

var streaming_enabled: bool = true
var step_by_step_autonomous: bool = false
var _is_waiting_approval: bool = false
var current_role: String = "Architect"
var available_roles = {
	"Architect": "Master Game Architect. Focuses on Scene Tree structure and node relationships.",
	"Logic Engineer": "Senior GDScript Developer. Focuses on robust, typed, and optimized code.",
	"Visual Designer": "Art and UI Specialist. Focuses on materials, shaders, and layout_presets.",
	"QA Lead": "Tester and Polisher. Focuses on game loops, signals, and edge cases."
}

var _api_keys = {
	"openrouter": "",
	"gemini": "",
	"huggingface": "",
	"custom": ""
}

var _key_indexes = {
	"openrouter": 0,
	"gemini": 0,
	"huggingface": 0,
	"custom": 0
}

var _endpoints = {
	"ollama": "http://127.0.0.1:11434/api/generate",
	"custom": "https://your-api.com/v1/chat/completions"
}

var _models = {
	"openrouter": "openai/gpt-4-turbo",
	"ollama": "llama3",
	"gemini": "gemini-1.5-pro",
	"huggingface": "mistralai/Mixtral-8x7B-Instruct-v0.1",
	"custom": "custom-model"
}

var _settings_path = "user://ai_builder_settings.cfg"
var _crypto_key = "GodotAIBu1ld3rS3cr3t!"

func _ready():
	load_settings()
	_switch_provider(provider_id)
	
	conversation_manager = load("res://addons/ai_builder/ConversationManager.gd").new()
	if conversation_manager:
		conversation_manager.load_history()
		
	# Connect to Executor for Auto-Fix
	var executor = get_node_or_null("/root/AIExecutor")
	if executor:
		if not executor.script_validation_failed.is_connected(_on_script_failed):
			executor.script_validation_failed.connect(_on_script_failed)
	_is_initialized = true

func _switch_provider(p_id: String):
	if current_provider != null and current_provider.request_completed.is_connected(_on_provider_completed):
		current_provider.request_completed.disconnect(_on_provider_completed)
	
	provider_id = p_id
	match provider_id:
		"openrouter":
			current_provider = load("res://addons/ai_builder/providers/OpenRouterProvider.gd").new()
			current_provider.api_key = _get_active_key("openrouter")
			current_provider.model_name = _models["openrouter"]
		"ollama":
			current_provider = load("res://addons/ai_builder/providers/OllamaProvider.gd").new()
			current_provider.endpoint_url = _endpoints["ollama"]
			current_provider.model_name = _models["ollama"]
		"gemini":
			current_provider = load("res://addons/ai_builder/providers/GeminiProvider.gd").new()
			current_provider.api_key = _get_active_key("gemini")
			current_provider.model_name = _models["gemini"]
		"huggingface":
			current_provider = load("res://addons/ai_builder/providers/HuggingFaceProvider.gd").new()
			current_provider.api_key = _get_active_key("huggingface")
			current_provider.model_name = _models["huggingface"]
		"custom":
			current_provider = load("res://addons/ai_builder/providers/CustomProvider.gd").new()
			current_provider.api_key = _get_active_key("custom")
			current_provider.endpoint_url = _endpoints["custom"]
			current_provider.model_name = _models["custom"]
		_:
			ai_error.emit("Unknown provider ID: " + provider_id)
			return
			
	current_provider.request_completed.connect(_on_provider_completed)
	current_provider.models_fetched.connect(_on_models_fetched)
	if current_provider.has_signal("stream_chunk_received"):
		current_provider.stream_chunk_received.connect(_on_stream_chunk)

func _on_stream_chunk(token: String):
	stream_chunk_received.emit(token)

func _on_script_failed(path: String, code: String, error: String):
	print("Auto-Correction Triggered for: ", path)
	var fix_prompt = "The script you just generated at '" + path + "' has the following error: " + error + ".\n"
	fix_prompt += "Here is the code you wrote:\n```gdscript\n" + code + "\n```\n"
	fix_prompt += "Please fix the error and return only the corrected JSON 'write_script' action.\n"
	fix_prompt += "IMPORTANT: Do NOT explain the fix, just provide the JSON. Use the 'Architect' persona only if node changes are also needed."
	
	# Small delay to avoid infinite loops or UI freezing
	await get_tree().create_timer(1.0).timeout
	send_prompt(fix_prompt, "QA Lead")

func fetch_models():
	if current_provider:
		current_provider.fetch_models(self)

func _on_models_fetched(models: Array, err_msg: String):
	if err_msg != "":
		ai_error.emit(err_msg)
	else:
		models_fetched.emit(models)

func _get_active_key(p_id: String) -> String:
	var keys_str = _api_keys.get(p_id, "")
	if keys_str == "": return ""
	var keys = keys_str.split(",")
	if keys.size() == 0: return ""
	var idx = _key_indexes.get(p_id, 0)
	if idx >= keys.size():
		idx = 0
		_key_indexes[p_id] = 0
	return keys[idx].strip_edges()

func _cycle_key(p_id: String) -> bool:
	var keys_str = _api_keys.get(p_id, "")
	var keys = keys_str.split(",")
	if keys.size() <= 1: return false
	_key_indexes[p_id] = (_key_indexes.get(p_id, 0) + 1) % keys.size()
	if current_provider and provider_id == p_id:
		current_provider.api_key = _get_active_key(p_id)
	return true

func set_api_key(key: String):
	_api_keys[provider_id] = key
	if current_provider:
		current_provider.api_key = _get_active_key(provider_id)
	save_settings()

func set_endpoint(url: String):
	_endpoints[provider_id] = url
	if current_provider:
		current_provider.endpoint_url = url
	save_settings()

func set_model(model: String):
	_models[provider_id] = model
	if current_provider:
		current_provider.model_name = model
	save_settings()

func save_settings():
	var config = ConfigFile.new()
	for p_id in _api_keys.keys(): config.set_value("api_keys", p_id, _api_keys[p_id])
	for p_id in _endpoints.keys(): config.set_value("endpoints", p_id, _endpoints[p_id])
	for p_id in _models.keys(): config.set_value("models", p_id, _models[p_id])
	config.save_encrypted_pass(_settings_path, _crypto_key)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load_encrypted_pass(_settings_path, _crypto_key)
	if err == OK:
		for p_id in _api_keys.keys():
			_api_keys[p_id] = config.get_value("api_keys", p_id, _api_keys[p_id])
		for p_id in _endpoints.keys():
			_endpoints[p_id] = config.get_value("endpoints", p_id, _endpoints[p_id])
		for p_id in _models.keys():
			_models[p_id] = config.get_value("models", p_id, _models[p_id])
	
	# Ensure Ollama defaults if somehow cleared
	if _endpoints["ollama"] == "": _endpoints["ollama"] = "http://127.0.0.1:11434/api/generate"
	if _models["ollama"] == "": _models["ollama"] = "llama3"

func validate_current_keys():
	var keys_str = _api_keys.get(provider_id, "")
	if keys_str == "":
		key_validation_completed.emit(false, "No keys to validate.")
		return
		
	var keys = keys_str.split(",")
	var valid_count = 0
	for k in keys:
		if k.strip_edges().length() > 5:
			valid_count += 1
			
	if valid_count > 0:
		key_validation_completed.emit(true, "Found " + str(valid_count) + " formatted keys.")
	else:
		key_validation_completed.emit(false, "Keys appear invalid or too short.")

func check_provider_health(p_id: String) -> bool:
	if p_id == "ollama" or p_id == "custom":
		return _endpoints.get(p_id, "") != ""
	else:
		return _api_keys.get(p_id, "") != ""

func _predict_best_provider(prompt: String) -> String:
	if not smart_routing_enabled: return provider_id
	
	# Hybrid mode: attempt free providers first to minimize cost
	if hybrid_mode:
		for free_p in _free_providers:
			if check_provider_health(free_p):
				print("Hybrid Mode: Routing to free provider -> ", free_p)
				return free_p
		print("Hybrid Mode: No free providers healthy, falling to paid.")
	
	var is_complex = prompt.findn("architecture") != -1 or prompt.findn("script") != -1 or prompt.findn("complex") != -1
	var has_openrouter = check_provider_health("openrouter")
	var has_gemini = check_provider_health("gemini")
	var has_ollama = check_provider_health("ollama")
	
	if is_complex:
		if has_openrouter: return "openrouter"
		if has_gemini: return "gemini"
	else:
		if has_ollama: return "ollama"
		
	return provider_id

func send_prompt(prompt: String, role_override: String = "assistant"):
	var best_provider = _predict_best_provider(prompt)
	if best_provider != provider_id:
		print("Smart Routing: Selecting best provider -> ", best_provider)
		_switch_provider(best_provider)
		
	if current_provider == null or not check_provider_health(provider_id):
		if fallback_enabled:
			print("Active provider unhealthy. Fallback routing...")
			for fallback_id in fallback_order:
				if check_provider_health(fallback_id):
					print("Fallback selected: ", fallback_id)
					_switch_provider(fallback_id)
					break
			
	if current_provider == null or not check_provider_health(provider_id):
		ai_error.emit("No valid or configured AI provider selected.")
		return
		
	var context_str = _get_scene_context() + "\n" + _get_project_context() + "\n" + _get_script_context() + "\n" + _get_project_settings_context()
		
	var role_desc = available_roles.get(current_role, role_override)
	var system = "You are the Godot AI Architect, a Senior Game Developer and AI Systems Expert.\n"
	system += "Specialized Role: " + current_role + " - " + role_desc + "\n\n"
	system += "CORE DIRECTIVES:\n"
	system += "1. ARCHITECTURE: Always prefer modular, signal-based decoupled logic. Use Autoloads for global state.\n"
	system += "2. QUALITY: Write production-ready GDScript with type hints, proper node references ($Child), and error handling.\n"
	system += "3. EFFICIENCY: Use 'batch_execute' for complex multi-step setups to minimize latency.\n"
	system += "4. SAFETY: Never delete critical nodes without user confirmation through the 'explain' action first.\n\n"
	system += "CONTEXT:\n" + context_str + "\n\n"
	system += "INSTRUCTION:\n"
	system += "You must respond with a VALID JSON object (no markdown, no preamble). Use the actions below to achieve the user's goal.\n"
	system += "Available Actions: \n"
	system += "- 'batch_execute': Array of commands for sequential execution.\n"
	system += "- 'create_node': { 'type', 'name', 'parent', 'properties' }. Use 'layout_preset' (0-15) for UI nodes.\n"
	system += "- 'modify_property': { 'name', 'property', 'value' }.\n"
	system += "- 'write_script': { 'path', 'code' }. Use professional GDScript 4 standards.\n"
	system += "- 'instance_scene': { 'path', 'parent' }. Spawn an existing .tscn file.\n"
	system += "- 'attach_script': { 'name', 'path' }. Attach an existing script to a node.\n"
	system += "- 'explain': { 'text' }. Provide feedback, reasoning, or suggestions.\n"
	system += "- 'save_branch_as_scene': { 'name', 'path' }. Serialize a node branch.\n"
	system += "- 'download_image': { 'image_prompt', 'name' }. Generate visual assets.\n"
	system += "- 'check_project_health': { 'directory' }. Recursively scan scripts for errors.\n"
	system += "- 'noop': {}. Do nothing.\n\n"
	system += "Format Example:\n"
	system += "{\n"
	system += "\t\"action\": \"batch_execute|create_node|delete_node|modify_property|rename_node|reparent_node|connect_signal|write_script|attach_script|instance_scene|save_branch_as_scene|download_image|download_audio|create_animation|explain|generate_docs|check_project_health|noop\",\n"
	system += "\t\"commands\": [ {} ],\n"
	system += "\t\"type\": \"NodeType (if creating)\",\n"
	system += "\t\"name\": \"NodeName (Target node)\",\n"
	system += "\t\"parent\": \"ParentName (if creating child)\",\n"
	system += "\t\"properties\": {\"modulate\": \"Color.GREEN\", \"layout_preset\": 15},\n"
	system += "\t\"new_name\": \"NewNodeName (if renaming)\",\n"
	system += "\t\"new_parent_name\": \"ParentNodeName (if reparenting)\",\n"
	system += "\t\"property\": \"position (if modifying)\",\n"
	system += "\t\"value\": \"Vector2(100, 100) (if modifying)\",\n"
	system += "\t\"signal_name\": \"pressed (if connecting)\",\n"
	system += "\t\"target_name\": \"TargetNode (if connecting)\",\n"
	system += "\t\"method_name\": \"_on_button_pressed (if connecting)\",\n"
	system += "\t\"path\": \"res://path/to/save.gd (if writing/docs)\",\n"
	system += "\t\"code\": \"GDScript or Shader code here (if writing)\",\n"
	system += "\t\"image_prompt\": \"Prompt for image generator (if downloading)\",\n"
	system += "\t\"audio_prompt\": \"Prompt for audio generator (if downloading)\",\n"
	system += "\t\"anim_name\": \"walk (if animating)\",\n"
	system += "\t\"keyframes\": [ {\"time\": 0.0, \"value\": \"Vector2(0,0)\"} ],\n"
	system += "\t\"text\": \"Your text here (if explaining/docs)\"\n"
	system += "}"

	_last_failed_prompt = prompt
	request_start_time = Time.get_ticks_msec()
	
	if conversation_manager:
		conversation_manager.add_message("user", prompt)
		
		var messages = []
		messages.append({ "role": "system", "content": system })
		for msg in conversation_manager.get_messages():
			messages.append(msg)
			
		if streaming_enabled and current_provider.has_method("send_chat_stream"):
			current_provider.send_chat_stream(messages, self)
		else:
			current_provider.send_chat(messages, self)
	else:
		current_provider.generate_text(system, prompt, self)

func _get_scene_context() -> String:
	if not Engine.is_editor_hint(): return "Not running in editor."
	var iface = EditorInterface
	if not iface: return "No EditorInterface."
	var root = iface.get_edited_scene_root()
	if not root: return "No active scene open."
	
	var ctx = "Scene Root: " + root.name + " (" + root.get_class() + ")\n"
	ctx += _build_tree_string(root, 1)
	return ctx

func _build_tree_string(node: Node, depth: int) -> String:
	if depth > 4: return "  ".repeat(depth) + "... (truncated)\n"
	var s = ""
	for child in node.get_children():
		s += "  ".repeat(depth) + "- " + child.name + " (" + child.get_class() + ")\n"
		s += _build_tree_string(child, depth + 1)
	return s

func _get_project_context() -> String:
	var ctx = "Project Files:\n"
	var dir = DirAccess.open("res://")
	if dir:
		ctx += _scan_dir(dir, "res://")
	return ctx

func _scan_dir(dir: DirAccess, path: String) -> String:
	var s = ""
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var count = 0
	while file_name != "" and count < 30: # Limit to 30 to avoid blowing up context
		if dir.current_is_dir() and file_name != "." and file_name != ".." and file_name != ".godot":
			var sub_dir = DirAccess.open(path.path_join(file_name))
			if sub_dir:
				s += _scan_dir(sub_dir, path.path_join(file_name))
		elif not dir.current_is_dir() and not file_name.ends_with(".import"):
			s += path.path_join(file_name) + "\n"
			count += 1
		file_name = dir.get_next()
	return s

func _get_script_context() -> String:
	if not Engine.is_editor_hint(): return ""
	var iface = EditorInterface
	if not iface: return ""
	var script_editor = iface.get_script_editor()
	if not script_editor: return ""
	var current_script = script_editor.get_current_script()
	if current_script:
		var code = current_script.source_code
		if code.length() > 4000:
			code = code.left(4000) + "\n... (truncated to save context)"
		return "Currently Open Script (" + current_script.resource_path + "):\n```gdscript\n" + code + "\n```\n"
	return ""

func _get_project_settings_context() -> String:
	var ctx = "Project Key Settings:\n"
	ctx += "Window Size: " + str(ProjectSettings.get_setting("display/window/size/viewport_width")) + "x" + str(ProjectSettings.get_setting("display/window/size/viewport_height")) + "\n"
	ctx += "Main Scene: " + str(ProjectSettings.get_setting("application/run/main_scene")) + "\n"
	return ctx

var _is_autonomous_mode = false
var _autonomous_steps = []
var _autonomous_current_step = 0

func start_autonomous_mode(goal: String):
	if current_provider == null:
		ai_error.emit("No valid AI provider selected.")
		return
		
	_is_autonomous_mode = true
	var system = "You are the Godot Master Architect. Your mission is to build a COMPLETE, functional game project based on a single user prompt.\n"
	system += "Break the user's high-level goal into a production-ready sequence of steps.\n"
	system += "You must use a multi-agent workflow:\n"
	system += "- 'Architect': Defines the full Scene Tree hierarchy and selects node types.\n"
	system += "- 'Logic Engineer': Writes robust GDScript/Shaders and connects signals.\n"
	system += "- 'Visual Designer': Generates assets, set up materials and lighting.\n"
	system += "- 'QA Lead': Validates logic, adds HUD elements, and ensures the game loop (Start/Restart) is functional.\n\n"
	system += "Guidelines:\n"
	system += "1. First step should always be 'Architect' to create the necessary nodes.\n"
	system += "2. Use 'Logic Engineer' to write the core scripts and attach them.\n"
	system += "3. Use 'QA Lead' for adding Game Over screens, HUDs, and overall polish.\n"
	system += "NEW DIRECTIVE: For every visual or audio element, include an 'asset_prompt' in the step description so the user can generate it using external tools.\n"
	system += "Maintain a consistent 'Studio Aesthetic'.\n\n"
	system += "Format:\n"
	system += "{\n"
	system += "\t\"steps\": [\n"
	system += "\t\t{\"role\": \"Architect\", \"task\": \"Plan the World. Create Level root and TileMap. [Prompt: Cyberpunk City texture]\"},\n"
	system += "\t\t{\"role\": \"Logic Engineer\", \"task\": \"Implement State Machine for Player. [Prompt: Neon Ninja sprite]\"},\n"
	system += "\t\t{\"role\": \"QA Lead\", \"task\": \"Add Post-Processing and UI. [Prompt: Glitch SFX]\"}\n"
	system += "\t]\n"
	system += "}"
	print("Generating Multi-Agent Production Plan for: ", goal)
	current_provider.generate_text(system, goal, self)

func _process_autonomous_plan(data: Dictionary):
	if data.has("steps") and typeof(data["steps"]) == TYPE_ARRAY:
		_autonomous_steps = data["steps"]
		_autonomous_current_step = 0
		autonomous_steps_ready.emit(_autonomous_steps)
		if step_by_step_autonomous:
			_is_waiting_approval = true
		else:
			_execute_next_autonomous_step()
	else:
		ai_error.emit("Failed to generate autonomous plan steps.")
		_is_autonomous_mode = false

func _execute_next_autonomous_step():
	if _autonomous_current_step >= _autonomous_steps.size():
		print("Autonomous Multi-Agent Build Completed!")
		_is_autonomous_mode = false
		ai_response_received.emit({"action": "noop", "_msg": "Autonomous Mode Complete"})
		autonomous_step_completed.emit(_autonomous_steps.size(), _autonomous_steps.size(), "Completed")
		return
		
	if _is_waiting_approval: return

	var step_obj = _autonomous_steps[_autonomous_current_step]
	var role = "assistant"
	var task = ""
	
	if typeof(step_obj) == TYPE_DICTIONARY:
		role = step_obj.get("role", "assistant")
		task = step_obj.get("task", "")
	else:
		task = str(step_obj)
		
	autonomous_step_completed.emit(_autonomous_current_step, _autonomous_steps.size(), task)
	print("Executing Autonomous Step [", (_autonomous_current_step + 1), "/", _autonomous_steps.size(), "]: ", task)
		
	print("Executing Autonomous Step ", _autonomous_current_step + 1, "/", _autonomous_steps.size(), " [Role: ", role, "]")
	print("Task: ", task)
	
	send_prompt(task, role)

func report_autonomous_step_completed():
	if _is_autonomous_mode:
		_autonomous_current_step += 1
	if step_by_step_autonomous:
		_is_waiting_approval = true
	else:
		_execute_next_autonomous_step()

func approve_next_step():
	_is_waiting_approval = false
	_execute_next_autonomous_step()

func _on_provider_completed(response: String, error_msg: String):
	if error_msg != "":
		# Rate limit monitor / free-tier detector 
		if error_msg.find("429") != -1 or error_msg.findn("rate limit") != -1 or error_msg.findn("quota") != -1:
			print("Rate Limit/Quota Detected on " + provider_id + ". Cycling API Key...")
			if _cycle_key(provider_id):
				print("Successfully cycled to alternative API key. Retrying...")
				call_deferred("send_prompt", _last_failed_prompt)
				return
			else:
				print("No alternative keys available for " + provider_id + ".")
				
		if _retry_attempts < max_retries:
			_retry_attempts += 1
			print("AI Provider Error! Retrying... (Attempt ", _retry_attempts, ")")
			call_deferred("send_prompt", _last_failed_prompt)
			return
		elif fallback_enabled:
			_retry_attempts = 0
			print("Max retries reached. Attempting fallback routing...")
			var current_idx = fallback_order.find(provider_id)
			var found_fallback = false
			if current_idx != -1:
				for i in range(1, fallback_order.size()):
					var next_id = fallback_order[(current_idx + i) % fallback_order.size()]
					if check_provider_health(next_id):
						print("Fallback routing to next provider: ", next_id)
						_switch_provider(next_id)
						call_deferred("send_prompt", _last_failed_prompt)
						found_fallback = true
						break
			if not found_fallback:
				ai_error.emit(error_msg + " (All fallbacks failed)")
			return
		else:
			_retry_attempts = 0
			ai_error.emit(error_msg)
			return
			
	_retry_attempts = 0
	total_requests += 1
	var latency_ms = Time.get_ticks_msec() - request_start_time
	var approx_tokens = response.length() / 4
	estimated_tokens += approx_tokens
	usage_updated.emit(total_requests, estimated_tokens, latency_ms)

	# Robust JSON extraction
	var clean_text = response.strip_edges()
	var start_idx = clean_text.find("{")
	var end_idx = clean_text.rfind("}")
	if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
		clean_text = clean_text.substr(start_idx, end_idx - start_idx + 1)
	
	clean_text = clean_text.strip_edges()

	var json = JSON.new()
	var err = json.parse(clean_text)
	if err != OK:
		ai_error.emit("AI returned invalid JSON: " + json.get_error_message() + "\\nRaw: " + clean_text)
		return
		
	var structured = json.get_data()
	
	if conversation_manager:
		var ai_text = structured.get("text", structured.get("explanation", "Action: " + structured.get("action", "")))
		conversation_manager.add_message("assistant", ai_text)
	
	if _is_autonomous_mode and structured.has("steps"):
		_process_autonomous_plan(structured)
	else:
		ai_response_received.emit(structured)
