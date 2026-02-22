@tool
extends VBoxContainer

var prompt_input: TextEdit
var provider_btn: OptionButton
var generate_btn: Button
var log_label: RichTextLabel
var api_key_input: LineEdit
var endpoint_input: LineEdit
var model_input: LineEdit
var template_btn: OptionButton
var usage_label: Label
var safe_mode_btn: CheckButton
var stats_label: Label
var roadmap_container: VBoxContainer
var roadmap_progress: ProgressBar
var roadmap_list: VBoxContainer
var approve_btn: Button
var header: Label

var ai_manager: Node = null
var ai_executor: Node = null
var _session_stats = { "requests": 0, "errors": 0, "tokens": 0 }

func _enter_tree():
	name = "AI Builder"
	print("AI Builder Dock: Entering Tree...")
	call_deferred("_initialize_ui")

func _ready():
	print("AI Builder Dock: Ready.")

func _initialize_ui():
	for child in get_children():
		child.queue_free()
		
	ai_manager = get_node_or_null("/root/AIManager")
	ai_executor = get_node_or_null("/root/AIExecutor")
	
	var header_hbox = HBoxContainer.new()
	header = Label.new()
	header.text = "Godot AI Architect"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header)
	
	var refresh_btn = Button.new()
	refresh_btn.text = "🔄"
	refresh_btn.tooltip_text = "Sync with AI Manager"
	refresh_btn.pressed.connect(_initialize_ui) # Re-init to find nodes
	header_hbox.add_child(refresh_btn)
	add_child(header_hbox)
	
	var prov_lbl = Label.new()
	prov_lbl.text = "Provider:"
	add_child(prov_lbl)
	
	provider_btn = OptionButton.new()
	provider_btn.add_item("openrouter", 0)
	provider_btn.add_item("ollama", 1)
	provider_btn.add_item("gemini", 2)
	provider_btn.add_item("huggingface", 3)
	provider_btn.add_item("custom", 4)
	provider_btn.item_selected.connect(_on_provider_changed)
	add_child(provider_btn)
	
	var key_lbl = Label.new()
	key_lbl.text = "API Key:"
	add_child(key_lbl)
	
	api_key_input = LineEdit.new()
	api_key_input.secret = true
	add_child(api_key_input)
	
	var endpt_lbl = Label.new()
	endpt_lbl.text = "Endpoint URL / Model:"
	add_child(endpt_lbl)
	
	var hbox = HBoxContainer.new()
	endpoint_input = LineEdit.new()
	endpoint_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(endpoint_input)
	model_input = LineEdit.new()
	model_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(model_input)
	
	var fetch_btn = Button.new()
	fetch_btn.text = "Fetch..."
	fetch_btn.pressed.connect(_on_fetch_pressed)
	hbox.add_child(fetch_btn)
	add_child(hbox)
	
	var prmpt_lbl = Label.new()
	prmpt_lbl.text = "Prompt:"
	add_child(prmpt_lbl)
	
	var template_hbox = HBoxContainer.new()
	var temp_lbl = Label.new()
	temp_lbl.text = "Template:"
	template_hbox.add_child(temp_lbl)
	
	template_btn = OptionButton.new()
	template_btn.add_item("Custom (Empty)", 0)
	template_btn.add_item("Build 2D Scene & TileMap", 1)
	template_btn.add_item("Build 3D Env (Camera+Light)", 2)
	template_btn.add_item("Build Main Menu UI", 3)
	template_btn.add_item("Generate Spawner Code", 4)
	template_btn.add_item("Brainstorm Game Ideas", 5)
	template_btn.add_item("Explain Active Script", 6)
	template_btn.add_item("Refactor & Optimize Script", 7)
	template_btn.add_item("Add Code Comments", 8)
	template_btn.add_item("Generate Unit Tests", 9)
	template_btn.add_item("Balance Game Economy/Stats", 10)
	template_btn.add_item("Analyze Level Flow", 11)
	template_btn.add_item("Generate NPC Behavior Tree", 12)
	template_btn.add_item("🚀 Full 2D Game: Platformer (Auto)", 13)
	template_btn.add_item("🚀 Full 3D Game: Space Shooter (Auto)", 14)
	template_btn.add_item("🛠 Auto-FIX Active Script", 15)
	template_btn.add_item("🔍 Scan & Fix Project Errors", 16)
	template_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	template_btn.item_selected.connect(_on_template_selected)
	template_hbox.add_child(template_btn)
	
	var role_hbox = HBoxContainer.new()
	var role_lbl = Label.new()
	role_lbl.text = "Active Role:"
	role_hbox.add_child(role_lbl)
	
	var role_dropdown = OptionButton.new()
	role_dropdown.add_item("Architect", 0)
	role_dropdown.add_item("Logic Engineer", 1)
	role_dropdown.add_item("Visual Designer", 2)
	role_dropdown.add_item("QA Lead", 3)
	role_dropdown.item_selected.connect(_on_role_selected)
	role_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_hbox.add_child(role_dropdown)
	
	var stream_toggle = CheckButton.new()
	stream_toggle.text = "Stream"
	stream_toggle.button_pressed = true
	stream_toggle.toggled.connect(func(p): if ai_manager: ai_manager.streaming_enabled = p)
	role_hbox.add_child(stream_toggle)
	
	var step_toggle = CheckButton.new()
	step_toggle.text = "Step-By-Step"
	step_toggle.toggled.connect(func(p): if ai_manager: ai_manager.step_by_step_autonomous = p)
	role_hbox.add_child(step_toggle)
	
	add_child(template_hbox)
	add_child(role_hbox)
	
	prompt_input = TextEdit.new()
	prompt_input.custom_minimum_size = Vector2(0, 150)
	prompt_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(prompt_input)
	
	var btn_hbox = HBoxContainer.new()
	generate_btn = Button.new()
	generate_btn.text = "Generate Blueprint"
	generate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_btn.pressed.connect(_on_generate_pressed)
	btn_hbox.add_child(generate_btn)
	
	var auto_btn = Button.new()
	auto_btn.text = "Autonomous Mode"
	auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_btn.pressed.connect(_on_autonomous_pressed)
	btn_hbox.add_child(auto_btn)
	
	# Safety Controls Row
	var safety_hbox = HBoxContainer.new()

	var safe_lbl = Label.new()
	safe_lbl.text = "Safe Mode:"
	safety_hbox.add_child(safe_lbl)

	safe_mode_btn = CheckButton.new()
	safe_mode_btn.text = "Off"
	safe_mode_btn.toggled.connect(_on_safe_mode_toggled)
	safety_hbox.add_child(safe_mode_btn)

	var rollback_btn = Button.new()
	rollback_btn.text = "⟲ Rollback Script"
	rollback_btn.pressed.connect(_on_rollback_pressed)
	rollback_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	safety_hbox.add_child(rollback_btn)

	var export_btn = Button.new()
	export_btn.text = "⬆ Export Templates"
	export_btn.pressed.connect(_on_export_templates_pressed)
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var clear_btn = Button.new()
	clear_btn.text = "🗑 Clear Chat"
	clear_btn.pressed.connect(_on_clear_chat_pressed)
	safety_hbox.add_child(clear_btn)

	add_child(safety_hbox)
	add_child(btn_hbox)
	
	# Studio Roadmap Panel
	var roadmap_panel = PanelContainer.new()
	roadmap_panel.visible = false
	var roadmap_vbox = VBoxContainer.new()
	roadmap_vbox.add_theme_constant_override("separation", 5)
	
	var roadmap_title = Label.new()
	roadmap_title.text = "🏗 Studio Build Roadmap"
	roadmap_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roadmap_title.add_theme_color_override("font_color", Color.CYAN)
	roadmap_vbox.add_child(roadmap_title)
	
	roadmap_progress = ProgressBar.new()
	roadmap_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roadmap_vbox.add_child(roadmap_progress)
	
	roadmap_list = VBoxContainer.new()
	roadmap_vbox.add_child(roadmap_list)
	
	approve_btn = Button.new()
	approve_btn.text = "✅ Approve & Run Next Step"
	approve_btn.visible = false
	approve_btn.pressed.connect(_on_approve_step_pressed)
	roadmap_vbox.add_child(approve_btn)
	
	roadmap_panel.add_child(roadmap_vbox)
	roadmap_container = roadmap_vbox
	add_child(roadmap_panel)
	
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(0, 150)
	add_child(log_label)
	
	usage_label = Label.new()
	usage_label.text = "Session Usage: 0 requests | ~0 tokens"
	usage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	usage_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(usage_label)
	
	if ai_manager:
		if not ai_manager.ai_response_received.is_connected(_on_ai_response):
			ai_manager.ai_response_received.connect(_on_ai_response)
		if not ai_manager.ai_error.is_connected(_on_ai_error):
			ai_manager.ai_error.connect(_on_ai_error)
		if not ai_manager.usage_updated.is_connected(_on_usage_updated):
			ai_manager.usage_updated.connect(_on_usage_updated)
		if not ai_manager.models_fetched.is_connected(_on_models_fetched):
			ai_manager.models_fetched.connect(_on_models_fetched)
		if not ai_manager.stream_chunk_received.is_connected(_on_stream_chunk):
			ai_manager.stream_chunk_received.connect(_on_stream_chunk)
		if not ai_manager.autonomous_steps_ready.is_connected(_on_autonomous_steps):
			ai_manager.autonomous_steps_ready.connect(_on_autonomous_steps)
		if not ai_manager.autonomous_step_completed.is_connected(_on_autonomous_progress):
			ai_manager.autonomous_step_completed.connect(_on_autonomous_progress)
		_sync_ui_to_provider()
		_load_chat_history()
	else:
		_log("[color=red]Warning: AIManager singleton not found. Please click 🔄 to retry or Enable Plugin in Project Settings.[/color]")

func _sync_ui_to_provider():
	if ai_manager == null: return
	
	api_key_input.text = ai_manager._api_keys.get(ai_manager.provider_id, "")
	endpoint_input.text = ai_manager._endpoints.get(ai_manager.provider_id, "")
	model_input.text = ai_manager._models.get(ai_manager.provider_id, "")
	
	# Disable api key input if provider doesn't use it
	if ai_manager.provider_id == "ollama":
		api_key_input.editable = false
		api_key_input.text = "<Local API - No Key Required>"
	else:
		api_key_input.editable = true

func _on_provider_changed(index: int):
	if ai_manager:
		var provider_str = provider_btn.get_item_text(index).to_lower()
		ai_manager._switch_provider(provider_str)
		_sync_ui_to_provider()

func _on_template_selected(index: int):
	match index:
		0: prompt_input.text = ""
		1: prompt_input.text = "Generate a full 2D level. Use the 'batch_execute' action to instantly build: A TileMap named LevelTiles, a Camera2D named MainCamera, a DirectionalLight2D named SunLight, and a CharacterBody2D named Player. Parent them to the root."
		2: prompt_input.text = "Generate a full 3D environment. Use 'batch_execute' to instantly build: A Camera3D named World_Camera, a DirectionalLight3D named World_Sun, and a StaticBody3D named Ground with a MeshInstance3D child."
		3: prompt_input.text = "Generate a Main Menu UI layout. Use 'batch_execute' to spawn a Control named MainMenu, a ColorRect background, a VBoxContainer, and two layout-friendly Buttons inside it (StartGame, QuitGame)."
		4: prompt_input.text = "Create a Node2D named 'EnemySpawner'. Write a script that spawns a generic enemy procedurally. Then use 'attach_script' to attach it to the spawner."
		5: prompt_input.text = "Act as a game designer. Brainstorm 3 rapid-fire game ideas that use the unique features of my current project setup. Format as a single paragraph using the 'explain' action."
		6: prompt_input.text = "Using the active script in my context, find any potential bugs, memory leaks, or optimizations. Use the 'explain' action."
		7: prompt_input.text = "Read the heavily-coupled code in my Active Script context. Refactor it to be modular, optimize its performance, and fix any immediate GDScript errors. Use 'write_script' to overwrite it."
		8: prompt_input.text = "Read my active script and add comprehensive, professional GDScript docstrings and inline comments explaining complex logic. Overwrite the file using 'write_script'."
		9: prompt_input.text = "Read my active script. Generate a robust suite of unit tests for it. Use 'write_script' to save it as 'res://tests/test_[script_name]'"
		10: prompt_input.text = "Act as an expert Systems Designer. Read my active script/game logic. Output a detailed JSON/Markdown table scaling player damage vs enemy health across 10 levels to achieve a 60% win-rate curve. Use the 'explain' action."
		11: prompt_input.text = "Analyze my current Scene Tree structure. Look for potential flow issues, missing collision borders, or soft-locks. Use 'explain' to suggest level design improvements."
		12: prompt_input.text = "Generate a State Machine script for an NPC. Include 'IDLE', 'PATROL', and 'CHASE' states. Automatically handle switching based on player proximity. Use 'write_script' to save it as res://npc_ai.gd."
		13: prompt_input.text = "Build a complete 2D Side-Scrolling Platformer game. Create a Player with physics movement, a scrolling camera, a tilemap floor, and a Win-Condition flag. Connect everything and add a HUD for Timer."
		14: prompt_input.text = "Build a complete 3D Space Shooter. Create a Player ship with 6DOF movement, an enemy spawner logic, 3D laser projectiles, and a Game Over screen when 'hull_integrity' reaches 0."
		15: prompt_input.text = "Analyze my Active Script for any syntax errors or logic bugs. If you find any, use 'write_script' to provide a fixed version. Be meticulous. [QA Lead]"
		16: prompt_input.text = "Use the 'check_project_health' action on 'res://'. If any scripts have syntax errors, read their content and provide a fixed version for each using 'write_script'. [QA Lead]"

func _on_fetch_pressed():
	if not ai_manager: return
	ai_manager.set_endpoint(endpoint_input.text)
	ai_manager.set_api_key(api_key_input.text)
	_log("Querying " + ai_manager.provider_id + " for available models...")
	ai_manager.fetch_models()

func _on_model_changed(model: String):
	_log("Model changed to: " + model)
	if ai_manager:
		ai_manager.set_model(model)

func _on_models_fetched(models: Array):
	if models.size() > 0:
		var popup = PopupMenu.new()
		for m in models: popup.add_item(m)
		popup.id_pressed.connect(func(id): model_input.text = models[id]; _on_model_changed(models[id]))
		add_child(popup)
		popup.popup_centered(Vector2(300, 400))
		_log("Fetched " + str(models.size()) + " models.")
	else:
		_log("Fetch complete, but no models found.")

func _on_usage_updated(reqs: int, tokens: int, lat: int):
	var cost_est = float(tokens) * 0.0000005
	_session_stats["requests"] = reqs
	_session_stats["tokens"] = tokens
	usage_label.text = "Requests: %d | Latency: %dms | Est Tokens: %d | Cost: ~$%.4f" % [reqs, lat, tokens, cost_est]

func _on_generate_pressed():
	if ai_manager == null: return
		
	var prompt = prompt_input.text
	if prompt.strip_edges() == "":
		_log("Please enter a prompt.")
		return
		
	ai_manager.set_api_key(api_key_input.text)
	if endpoint_input.text != "":
		ai_manager.set_endpoint(endpoint_input.text)
	if model_input.text != "":
		ai_manager.set_model(model_input.text)
		
	generate_btn.disabled = true
	generate_btn.text = "Waiting for " + ai_manager.provider_id + "..."
	_log("[color=white][b]USER:[/b][/color] " + prompt)
	prompt_input.text = "" # Clear for next message
	_first_stream_chunk = true
	ai_manager.send_prompt(prompt)

func _on_autonomous_pressed():
	if ai_manager == null: return
		
	var goal = prompt_input.text
	if goal.strip_edges() == "":
		_log("Please enter a high-level goal for Auto Mode.")
		return
		
	ai_manager.set_api_key(api_key_input.text)
	if endpoint_input.text != "":
		ai_manager.set_endpoint(endpoint_input.text)
	if model_input.text != "":
		ai_manager.set_model(model_input.text)
		
	generate_btn.disabled = true
	generate_btn.text = "Running Autonomous Agent..."
	_log("Agent Planning Goal: " + goal)
	ai_manager.start_autonomous_mode(goal)

func _on_ai_response(data: Dictionary):
	generate_btn.disabled = false
	generate_btn.text = "Generate Blueprint"
	
	if not ai_manager.streaming_enabled:
		var action = data.get("action", "")
		var expl = data.get("explanation", data.get("text", ""))
		
		if expl != "":
			_log("[color=yellow][b]AI Builder:[/b][/color] " + expl)
		
		if action != "explain" and action != "noop" and action != "":
			var detail = ""
			if data.has("name"): detail += " target: " + str(data["name"])
			if data.has("path"): detail += " path: " + str(data["path"])
			_log("[color=green][i]System: Executing " + action + detail + "[/i][/color]")
	else:
		log_label.append_text("\n") # End of stream line
	
	if ai_executor == null:
		ai_executor = get_node_or_null("/root/AIExecutor")
		
	if ai_executor:
		_log("Executing AI Command...")
		ai_executor.execute_command(data)
		_log("Execution complete.")

func _on_ai_error(msg: String):
	generate_btn.disabled = false
	generate_btn.text = "Generate Blueprint"
	_session_stats["errors"] += 1
	_log("ERROR: " + msg)

func _on_safe_mode_toggled(pressed: bool):
	if ai_executor == null:
		ai_executor = get_node_or_null("/root/AIExecutor")
	if ai_executor:
		ai_executor.safe_mode = pressed
		safe_mode_btn.text = "ON" if pressed else "Off"
		_log("Safe Mode: " + ("ENABLED. Destructive actions blocked." if pressed else "Disabled."))

func _on_rollback_pressed():
	if ai_executor == null:
		ai_executor = get_node_or_null("/root/AIExecutor")
	if ai_executor:
		_log("Attempting rollback of last AI script change...")
		ai_executor.rollback_last_script()
	else:
		_log("AIExecutor not found for rollback.")

func _on_export_templates_pressed():
	# Export current session templates + prompts as a shareable JSON profile
	var profile = {
		"version": "1.0",
		"provider": ai_manager.provider_id if ai_manager else "",
		"model": model_input.text,
		"session_stats": _session_stats,
		"templates": [
			{"name": "2D Level", "prompt": "Generate a full 2D level with TileMap, Camera2D, Light and Player."},
			{"name": "3D Env", "prompt": "Generate a full 3D environment with Camera3D, Light, Ground."},
			{"name": "Main Menu UI", "prompt": "Generate a main menu with VBoxContainer containing Start/Quit buttons."},
			{"name": "NPC State Machine", "prompt": "Generate an NPC state machine with IDLE, PATROL, CHASE states."},
			{"name": "Unit Tests", "prompt": "Generate unit tests for the currently open script."}
		]
	}
	var json_str = JSON.stringify(profile, "\t")
	var path = "user://ai_builder_team_profile.json"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(json_str)
		f.close()
		_log("Team profile exported to: " + path)
	else:
		_log("Failed to export profile.")

func _on_role_selected(idx: int):
	var roles = ["Architect", "Logic Engineer", "Visual Designer", "QA Lead"]
	if ai_manager:
		ai_manager.current_role = roles[idx]
		_log("[i]System: Role switched to " + roles[idx] + "[/i]")

func _on_stream_chunk(token: String):
	if _first_stream_chunk:
		log_label.append_text("[color=yellow][b]AI:[/b][/color] ")
		_first_stream_chunk = false
	log_label.append_text(token)

var _first_stream_chunk = true

func _log(msg: String):
	log_label.append_text(msg + "\n")
	print("[AI Builder] " + msg)

func _on_autonomous_steps(steps: Array):
	roadmap_container.get_parent().visible = true
	roadmap_progress.max_value = steps.size()
	roadmap_progress.value = 0
	for child in roadmap_list.get_children(): child.queue_free()
	
	for i in range(steps.size()):
		var step_lbl = Label.new()
		var task = steps[i].get("task", "Planning...")
		step_lbl.text = "[ ] Step %d: %s" % [i+1, task.left(50) + "..."]
		step_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		roadmap_list.add_child(step_lbl)
	
	if ai_manager and ai_manager.step_by_step_autonomous and steps.size() > 0:
		approve_btn.visible = true
		approve_btn.text = "✅ Approve Step 1: " + steps[0].get("task", "").left(30) + "..."

func _on_autonomous_progress(idx: int, total: int, task: String):
	roadmap_progress.value = idx + 1
	if idx < roadmap_list.get_child_count():
		var lbl = roadmap_list.get_child(idx)
		lbl.text = "[✓] Step %d Complete" % [idx+1]
		lbl.add_theme_color_override("font_color", Color.GREEN)
	
	if ai_manager and ai_manager.step_by_step_autonomous and idx + 1 < total:
		approve_btn.visible = true
		approve_btn.text = "✅ Approve Step %d: %s" % [idx + 2, ai_manager._autonomous_steps[idx+1].get("task", "Next").left(20) + "..."]
	else:
		approve_btn.visible = false
	
	if idx + 1 == total:
		_log("[color=cyan][b]Studio Build Successful![/b][/color]")
		# Keep panel visible for a few seconds then hide? 
		# Or just let it stay.

func _on_approve_step_pressed():
	approve_btn.visible = false
	if ai_manager: ai_manager.approve_next_step()

func _load_chat_history():
	if not ai_manager or not ai_manager.conversation_manager: return
	log_label.clear()
	for msg in ai_manager.conversation_manager.get_messages():
		var sender = "USER" if msg["role"] == "user" else "AI"
		var color = "white" if sender == "USER" else "yellow"
		log_label.append_text("[color=%s][b]%s:[/b][/color] %s\n" % [color, sender, msg["content"]])

func _on_clear_chat_pressed():
	if ai_manager and ai_manager.conversation_manager:
		ai_manager.conversation_manager.clear()
		log_label.clear()
		_log("[i]System: Conversation history cleared.[/i]")
