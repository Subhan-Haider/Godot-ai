## MainDock - Root UI container. Wires all services together (DI hub).
## Composited from sub-panels; each panel only knows about the services it uses.
@tool
extends VBoxContainer

# ---------------------------------------------------------------------------
# Service instances (created here, passed by reference to sub-panels)
# ---------------------------------------------------------------------------
var _logger:    AILogger              = null
var _profile:   ProfileManager        = null
var _router:    ProviderRouter         = null
var _context:   ContextCollector      = null ## ContextCollector - gathers scene tree, script list, assets, project settings.
var _history:   ConversationHistory   = null
var _estimator: TokenEstimator        = null
var _cache:     CacheManager          = null
var _orchestrator: AIOrchestrator     = null
var _executor:  ActionExecutor        = null ## ActionExecutor - dispatches structured AI responses into real editor operations.
var _templates: PromptTemplateLibrary = null

var _config:    Dictionary = {}
var _editor:    EditorInterface = null

# ---------------------------------------------------------------------------
# UI references
# ---------------------------------------------------------------------------
var _provider_opt:  OptionButton
var _model_input:   LineEdit
var _fetch_btn:     Button
var _api_key_input: LineEdit
var _endpoint_input: LineEdit
var _temp_slider:   HSlider
var _temp_label:    Label
var _tokens_spin:   SpinBox
var _stream_check:  CheckBox
var _hybrid_check:  CheckBox
var _safe_check:    CheckButton
var _profile_opt:   OptionButton
var _template_opt:  OptionButton
var _prompt_edit:   TextEdit
var _send_btn:      Button
var _auto_btn:      Button
var _rollback_btn:  Button
var _export_btn:    Button
var _clear_hist_btn:Button
var _log_rtl:       RichTextLabel
var _status_lbl:    Label
var _stats_lbl:     Label
var _tab_container: TabContainer


func initialize(editor: EditorInterface) -> void:
	_editor = editor
	_boot_services()
	_build_ui()
	_connect_wires()
	_refresh_ui_from_config()
	_logger.info("MainDock", "UI ready.")


# ---------------------------------------------------------------------------
# Service bootstrap
# ---------------------------------------------------------------------------

func _boot_services() -> void:
	_logger    = AILogger.new()

	_profile   = ProfileManager.new()
	_profile.setup(_logger)
	_config    = _profile.load_profile()

	_router    = ProviderRouter.new()
	_router.setup(_config, _logger)

	_context   = ContextCollector.new()
	_context.setup(_editor)

	_history   = ConversationHistory.new()
	_estimator = TokenEstimator.new()
	_estimator.set_provider(_config.get("active_provider","openai"))

	_cache     = CacheManager.new()
	_cache.setup()
	_cache.set_enabled(_config.get("cache_enabled", true))

	_templates = PromptTemplateLibrary.new()
	_templates.setup()

	_orchestrator = AIOrchestrator.new()
	_orchestrator.name = "AIOrchestrator"
	add_child(_orchestrator)
	_orchestrator.logger    = _logger
	_orchestrator.router    = _router
	_orchestrator.context   = _context
	_orchestrator.history   = _history
	_orchestrator.estimator = _estimator
	_orchestrator.cache     = _cache

	_executor = ActionExecutor.new()
	_executor.name = "ActionExecutor"
	add_child(_executor)
	_executor.setup(_editor, _logger)
	_executor.safe_mode   = _config.get("safe_mode", false)
	_executor.permissions = _config.get("permissions", {})


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	custom_minimum_size = Vector2(320, 600)

	# Header
	var header := Label.new()
	header.text = "AI Assistant"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	add_child(header)

	# Tab container
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tab_container)

	_build_main_tab()
	_build_settings_tab()
	_build_debug_tab()

	# Status bar
	_status_lbl = Label.new()
	_status_lbl.text = "Ready"
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status_lbl)

	_stats_lbl = Label.new()
	_stats_lbl.text = "Requests: 0 | Tokens: ~0 | Cost: $0.0000"
	_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	add_child(_stats_lbl)


func _build_main_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Main"
	_tab_container.add_child(tab)

	# ---- Provider row ----
	var prow := HBoxContainer.new()
	var plbl := Label.new(); plbl.text = "Provider:"
	prow.add_child(plbl)

	_provider_opt = OptionButton.new()
	_provider_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for pid in ProviderRouter.PROVIDERS.keys():
		_provider_opt.add_item(pid)
	prow.add_child(_provider_opt)
	tab.add_child(prow)

	# ---- API key ----
	var klbl := Label.new(); klbl.text = "API Key:"
	tab.add_child(klbl)
	_api_key_input = LineEdit.new()
	_api_key_input.secret = true
	_api_key_input.placeholder_text = "sk-..."
	tab.add_child(_api_key_input)

	# ---- Model + fetch ----
	var mrow := HBoxContainer.new()
	var mlbl := Label.new(); mlbl.text = "Model:"
	mrow.add_child(mlbl)
	_model_input = LineEdit.new()
	_model_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(_model_input)
	_fetch_btn = Button.new(); _fetch_btn.text = "R"
	mrow.add_child(_fetch_btn)
	tab.add_child(mrow)

	# ---- Endpoint ----
	var elbl := Label.new(); elbl.text = "Endpoint (leave empty for default):"
	tab.add_child(elbl)
	_endpoint_input = LineEdit.new()
	_endpoint_input.placeholder_text = "https://..."
	tab.add_child(_endpoint_input)

	# ---- Template selector ----
	var tlbl := Label.new(); tlbl.text = "Template:"
	tab.add_child(tlbl)
	_template_opt = OptionButton.new()
	_template_opt.add_item("- none -", 0)
	for i in range(_templates.get_names().size()):
		_template_opt.add_item(_templates.get_names()[i], i + 1)
	tab.add_child(_template_opt)

	# ---- Prompt ----
	var plbl2 := Label.new(); plbl2.text = "Prompt:"
	tab.add_child(plbl2)
	_prompt_edit = TextEdit.new()
	_prompt_edit.custom_minimum_size = Vector2(0, 120)
	_prompt_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	tab.add_child(_prompt_edit)

	# ---- Action buttons ----
	var brow := HBoxContainer.new()
	_send_btn = Button.new()
	_send_btn.text = "Send"
	_send_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(_send_btn)

	_auto_btn = Button.new()
	_auto_btn.text = "Auto"
	_auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(_auto_btn)
	tab.add_child(brow)

	# ---- Safety row ----
	var srow := HBoxContainer.new()
	var slbl := Label.new(); slbl.text = "Safe Mode:"
	srow.add_child(slbl)
	_safe_check = CheckButton.new()
	srow.add_child(_safe_check)

	_rollback_btn = Button.new()
	_rollback_btn.text = "Rollback"
	_rollback_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(_rollback_btn)

	_export_btn = Button.new()
	_export_btn.text = "Export"
	_export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(_export_btn)
	tab.add_child(srow)

	# ---- Log ----
	var llbl := Label.new(); llbl.text = "Response Log:"
	tab.add_child(llbl)
	_log_rtl = RichTextLabel.new()
	_log_rtl.custom_minimum_size = Vector2(0, 130)
	_log_rtl.bbcode_enabled = true
	_log_rtl.scroll_following = true
	tab.add_child(_log_rtl)

	_clear_hist_btn = Button.new()
	_clear_hist_btn.text = "Clear History"
	tab.add_child(_clear_hist_btn)


func _build_settings_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Settings"
	_tab_container.add_child(tab)

	# Temperature
	var trow := HBoxContainer.new()
	var tlbl := Label.new(); tlbl.text = "Temperature:"
	trow.add_child(tlbl)
	_temp_label = Label.new(); _temp_label.text = "0.70"
	trow.add_child(_temp_label)
	tab.add_child(trow)

	_temp_slider = HSlider.new()
	_temp_slider.min_value = 0.0
	_temp_slider.max_value = 2.0
	_temp_slider.step      = 0.05
	_temp_slider.value     = 0.7
	tab.add_child(_temp_slider)

	# Max tokens
	var mrow := HBoxContainer.new()
	var mlbl := Label.new(); mlbl.text = "Max Tokens:"
	mrow.add_child(mlbl)
	_tokens_spin = SpinBox.new()
	_tokens_spin.min_value = 256
	_tokens_spin.max_value = 16000
	_tokens_spin.step      = 256
	_tokens_spin.value     = 2048
	mrow.add_child(_tokens_spin)
	tab.add_child(mrow)

	# Streaming toggle
	_stream_check = CheckBox.new()
	_stream_check.text = "Enable Streaming (experimental)"
	tab.add_child(_stream_check)

	# Hybrid mode
	_hybrid_check = CheckBox.new()
	_hybrid_check.text = "Hybrid Mode (free providers first)"
	_hybrid_check.button_pressed = true
	tab.add_child(_hybrid_check)

	# Profile row
	var prow := HBoxContainer.new()
	var plbl := Label.new(); plbl.text = "Profile:"
	prow.add_child(plbl)
	_profile_opt = OptionButton.new()
	_profile_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for p in _profile.list_profiles():
		_profile_opt.add_item(p)
	prow.add_child(_profile_opt)

	var save_btn := Button.new(); save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_profile)
	prow.add_child(save_btn)

	var load_btn := Button.new(); load_btn.text = "Load"
	load_btn.pressed.connect(_on_load_profile)
	prow.add_child(load_btn)
	tab.add_child(prow)


func _build_debug_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Debug"
	_tab_container.add_child(tab)

	var debug_rtl := RichTextLabel.new()
	debug_rtl.bbcode_enabled = true
	debug_rtl.custom_minimum_size = Vector2(0, 400)
	debug_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debug_rtl.scroll_following = true

	_logger.log_entry_added.connect(func(level, cat, msg, ts):
		var colours := ["gray", "white", "yellow", "red"]
		var colour   := colours[clampi(level, 0, 3)]
		debug_rtl.append_text("[color=%s][%.1f][%s] %s[/color]\n" % [colour, ts, cat, msg])
	)
	tab.add_child(debug_rtl)

	var clear_btn := Button.new(); clear_btn.text = "Clear Debug Log"
	clear_btn.pressed.connect(func(): debug_rtl.clear(); _logger.clear())
	tab.add_child(clear_btn)


# ---------------------------------------------------------------------------
# Signal wiring
# ---------------------------------------------------------------------------

func _connect_wires() -> void:
	_provider_opt.item_selected.connect(_on_provider_selected)
	_api_key_input.text_changed.connect(_on_api_key_changed)
	_model_input.text_changed.connect(_on_model_changed)
	_endpoint_input.text_changed.connect(_on_endpoint_changed)
	_fetch_btn.pressed.connect(_on_fetch_models)
	_template_opt.item_selected.connect(_on_template_selected)
	_send_btn.pressed.connect(_on_send)
	_auto_btn.pressed.connect(_on_autonomous)
	_safe_check.toggled.connect(_on_safe_toggled)
	_rollback_btn.pressed.connect(_executor.rollback_last_script)
	_export_btn.pressed.connect(_on_export)
	_clear_hist_btn.pressed.connect(_on_clear_history)
	_temp_slider.value_changed.connect(_on_temp_changed)
	_tokens_spin.value_changed.connect(_on_tokens_changed)
	_hybrid_check.toggled.connect(func(v): _router.hybrid_mode = v)

	_orchestrator.response_ready.connect(_on_response_ready)
	_orchestrator.request_error.connect(_on_request_error)
	_orchestrator.status_changed.connect(func(s): _status_lbl.text = s)
	_estimator.stats_updated.connect(_on_stats_updated)
	_executor.action_completed.connect(func(a, _d): _log("[color=green]✓ Action: %s[/color]" % a))
	_executor.action_failed.connect(func(a, r): _log("[color=red]✗ %s: %s[/color]" % [a, r]))
	_router.provider_changed.connect(func(pid): _log("Provider → " + pid))


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_provider_selected(idx: int) -> void:
	var pid := _provider_opt.get_item_text(idx)
	_router.switch_to(pid)
	_config["active_provider"] = pid
	# Load this provider's stored key / model / endpoint
	_api_key_input.text   = _config.get("api_keys",  {}).get(pid, "")
	_model_input.text     = _config.get("models",    {}).get(pid, "")
	_endpoint_input.text  = _config.get("endpoints", {}).get(pid, "")
	if pid == "ollama":
		_api_key_input.editable = false
		_api_key_input.placeholder_text = "<Local — no key needed>"
	else:
		_api_key_input.editable = true
		_api_key_input.placeholder_text = "sk-…"


func _on_api_key_changed(key: String) -> void:
	var pid := _provider_opt.get_item_text(_provider_opt.selected)
	_config.get_or_add("api_keys", {})[pid] = key
	_router._config = _config


func _on_model_changed(m: String) -> void:
	var pid := _provider_opt.get_item_text(_provider_opt.selected)
	_config.get_or_add("models", {})[pid] = m


func _on_endpoint_changed(url: String) -> void:
	var pid := _provider_opt.get_item_text(_provider_opt.selected)
	_config.get_or_add("endpoints", {})[pid] = url


func _on_temp_changed(v: float) -> void:
	_temp_label.text = "%.2f" % v
	_config["temperature"] = v


func _on_tokens_changed(v: float) -> void:
	_config["max_tokens"] = int(v)


func _on_template_selected(idx: int) -> void:
	if idx == 0: return
	var name := _template_opt.get_item_text(idx)
	_prompt_edit.text = _templates.get_prompt(name)


func _on_fetch_models() -> void:
	var provider := _router.get_provider()
	if not provider: return
	provider.models_loaded.connect(_on_models_loaded, CONNECT_ONE_SHOT)
	provider.fetch_models(self)
	_log("Fetching models…")


func _on_models_loaded(models: Array) -> void:
	if models.is_empty():
		_log("No models returned."); return
	var popup := PopupMenu.new()
	for m in models: popup.add_item(m)
	popup.id_pressed.connect(func(id): _model_input.text = models[id])
	add_child(popup)
	popup.popup_centered(Vector2(320, 420))
	_log("Fetched %d models." % models.size())


func _on_send() -> void:
	var prompt := _prompt_edit.text.strip_edges()
	if prompt == "": _log("Please enter a prompt."); return

	# Push latest key/model/endpoint to router config before sending
	_apply_ui_to_config()
	_router.setup(_config, _logger)

	_send_btn.disabled = true
	_send_btn.text     = "⏳ Sending…"
	_orchestrator.send(prompt)


func _on_autonomous() -> void:
	var goal := _prompt_edit.text.strip_edges()
	if goal == "": _log("Enter a high-level goal for autonomous mode."); return
	_apply_ui_to_config()
	_router.setup(_config, _logger)
	_auto_btn.disabled = true
	_auto_btn.text     = "⏳ Planning…"
	_log("[i]Autonomous Agent started[/i]")
	_orchestrator.start_autonomous(goal)


func _on_response_ready(data: Dictionary) -> void:
	_send_btn.disabled = false
	_send_btn.text     = "✉  Send"
	_auto_btn.disabled = false
	_auto_btn.text     = "⚡ Auto"

	var action: String = data.get("action","")
	var expl:   String = data.get("explanation","")

	if expl != "":
		_log("[b]AI:[/b] " + expl)

	if action == "explain" or action == "":
		return

	_executor.execute(data)


func _on_request_error(msg: String) -> void:
	_send_btn.disabled = false
	_send_btn.text     = "✉  Send"
	_auto_btn.disabled = false
	_auto_btn.text     = "⚡ Auto"
	_log("[color=red]Error: " + msg + "[/color]")


func _on_stats_updated(reqs: int, tokens: int, cost: float, lat: int) -> void:
	_stats_lbl.text = "Req: %d | ~%d tokens | $%.4f | %dms" % [reqs, tokens, cost, lat]


func _on_safe_toggled(pressed: bool) -> void:
	_executor.safe_mode = pressed
	_config["safe_mode"] = pressed
	_log("Safe Mode: " + ("ON — destructive actions blocked." if pressed else "OFF"))


func _on_export() -> void:
	var out := {
		"version": "1.0",
		"config": _config,
		"templates": _templates.get_all()
	}
	var f := FileAccess.open("user://ai_assistant_export.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t"))
		_log("Exported to user://ai_assistant_export.json")


func _on_clear_history() -> void:
	_history.clear()
	_cache.clear()
	_log_rtl.clear()
	_log("History + cache cleared.")


func _on_save_profile() -> void:
	_apply_ui_to_config()
	var name := _profile_opt.get_item_text(_profile_opt.selected) if _profile_opt.selected >= 0 else "default"
	_profile.save_profile(_config, name)
	_log("Profile '%s' saved." % name)


func _on_load_profile() -> void:
	var name := _profile_opt.get_item_text(_profile_opt.selected) if _profile_opt.selected >= 0 else "default"
	_config = _profile.load_profile(name)
	_router.setup(_config, _logger)
	_cache.set_enabled(_config.get("cache_enabled", true))
	_refresh_ui_from_config()
	_log("Profile '%s' loaded." % name)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _apply_ui_to_config() -> void:
	var pid := _provider_opt.get_item_text(_provider_opt.selected)
	_config["active_provider"] = pid
	_config.get_or_add("api_keys",   {})[pid] = _api_key_input.text
	_config.get_or_add("models",     {})[pid] = _model_input.text
	_config.get_or_add("endpoints",  {})[pid] = _endpoint_input.text
	_config["temperature"] = _temp_slider.value
	_config["max_tokens"]  = int(_tokens_spin.value)
	_config["safe_mode"]   = _safe_check.button_pressed
	_config["hybrid_mode"] = _hybrid_check.button_pressed
	_router._config = _config


func _refresh_ui_from_config() -> void:
	var pid   := _config.get("active_provider", "openai")
	var pids  := ProviderRouter.PROVIDERS.keys()
	var idx   := pids.find(pid)
	if idx >= 0: _provider_opt.select(idx)

	_api_key_input.text   = _config.get("api_keys",   {}).get(pid, "")
	_model_input.text     = _config.get("models",     {}).get(pid, "")
	_endpoint_input.text  = _config.get("endpoints",  {}).get(pid, "")
	_temp_slider.value    = _config.get("temperature", 0.7)
	_tokens_spin.value    = _config.get("max_tokens", 2048)
	_safe_check.button_pressed   = _config.get("safe_mode",   false)
	_hybrid_check.button_pressed = _config.get("hybrid_mode", true)


func _log(msg: String) -> void:
	_log_rtl.append_text(msg + "\n")
	_logger.info("UI", msg.replace("[b]","").replace("[/b]","").replace("[i]","").replace("[/i]","").strip_edges())
