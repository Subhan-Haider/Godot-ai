## AIOrchestrator - Central coordinator and dependency-injection hub.
##
## Owns references to all services, assembles prompts, dispatches requests,
## handles retries, and emits normalised results for the UI to consume.
@tool
class_name AIOrchestrator
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal response_ready(structured: Dictionary)
signal stream_chunk(text: String)
signal request_error(message: String)
signal status_changed(message: String)

# ---------------------------------------------------------------------------
# Injected services (set up by MainDock)
# ---------------------------------------------------------------------------
var logger:    AILogger         = null
var router:    ProviderRouter   = null
var context:   ContextCollector = null
var history:   ConversationHistory = null
var estimator: TokenEstimator   = null
var cache:     CacheManager     = null

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _busy:          bool    = false
var _last_prompt:   String  = ""
var _last_messages: Array   = []
var _request_start: int     = 0

# Autonomous build mode state
var _is_autonomous: bool      = false
var _autonomous_steps: Array  = []
var _current_step_idx: int    = 0

# ---------------------------------------------------------------------------
# System prompt (constant core + injected context)
# ---------------------------------------------------------------------------
const SYSTEM_CORE := """You are an expert Godot Engine 4 assistant integrated directly into the editor.

Always respond with a single valid JSON object (no markdown fences). Use this schema:
{
  "action": "<action_name>",
  "explanation": "<text explanation>",
  "code": "<gdscript_code>",
  "nodes": [ { "type": "NodeType", "name": "Name", "parent": "ParentName", "properties": {} } ],
  "assets": [ { "prompt": "image_prompt", "name": "filename" } ],
  "commands": [ <nested action objects> ],
  "steps": [ { "role": "Programmer/Designer/Tester", "task": "detailed task" } ]
}

Available actions:
plan           - Generate a list of 'steps' to achieve a complex goal.
batch          - Execute all actions in 'commands' array sequentially.
create_node    - Create nodes from 'nodes' array.
delete_node    - Delete a node; provide 'name'.
modify_node    - Set properties; provide 'name' and 'properties' dict.
reparent_node  - Move node; provide 'name' and 'parent'.
connect_signal - Connect a signal; provide 'name', 'signal', 'target', 'method'.
write_script   - Write/overwrite a GDScript; provide 'code' and a 'path'.
attach_script  - Attach existing script to node; provide 'name' and 'path'.
explain        - Textual response only via 'explanation'.
noop           - Do nothing.
"""


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Send a user prompt. Gathers context, assembles messages, and dispatches.
func send(user_prompt: String) -> void:
	if _busy:
		logger.warn("Orchestrator", "Ignoring send: already busy.")
		return

	_busy = true
	_last_prompt = user_prompt
	status_changed.emit("Gathering context…")

	# Check cache first
	if cache:
		var cached := cache.get(user_prompt)
		if cached != null:
			logger.info("Orchestrator", "Cache hit.")
			_busy = false
			_on_success(cached)
			return

	var ctx: String = context.collect() if context else ""

	var system_msg := {
		"role": "system",
		"content": SYSTEM_CORE + "\n\n" + ctx
	}

	_last_messages = [system_msg]

	# Inject conversation history
	if history:
		for msg in history.get_messages():
			_last_messages.append(msg)

	_last_messages.append({ "role": "user", "content": user_prompt })

	# Token estimation / warning
	if estimator:
		var est := estimator.estimate_messages(_last_messages)
		logger.info("Orchestrator", "Estimated prompt tokens: ~%d" % est)

	var provider := router.select_best(user_prompt) if router else null
	if not provider:
		_fail("No provider available.")
		return

	# Wire signals (single-use — disconnect after completion)
	provider.response_completed.connect(_on_provider_response.bind(provider), CONNECT_ONE_SHOT)
	provider.request_failed.connect(_on_provider_failed.bind(provider), CONNECT_ONE_SHOT)

	_request_start = Time.get_ticks_msec()
	status_changed.emit("Sending to %s..." % provider.get_provider_name())
	logger.info("Orchestrator", "-> %s [%s]" % [provider.get_provider_name(), provider.model_name])

	provider.send_chat(_last_messages, self)


## Retry the last prompt (e.g. after user clicks Retry).
func retry() -> void:
	if _last_prompt == "": return
	router.reset_retry()
	send(_last_prompt)


## Begin an autonomous multi-step plan.
func start_autonomous(goal: String) -> void:
	_is_autonomous = true
	_autonomous_steps = []
	_current_step_idx = 0
	
	var plan_prompt = "PLAN: " + goal
	send(plan_prompt)


# ---------------------------------------------------------------------------
# Private callbacks
# ---------------------------------------------------------------------------

func _on_provider_response(result: Dictionary, _provider: BaseProvider) -> void:
	var latency_ms := Time.get_ticks_msec() - _request_start
	logger.info("Orchestrator", "<- Response in %dms" % latency_ms)

	if estimator:
		estimator.record_response(result.get("text", ""), latency_ms)

	router.reset_retry()

	var text: String = result.get("text", "")

	# Store in cache
	if cache and _last_prompt != "":
		cache.store(_last_prompt, text)

	# Add to history
	if history:
		history.add("user",      _last_prompt)
		history.add("assistant", text)

	_busy = false
	_on_success(text)


func _on_provider_failed(error: String, code: int, _provider: BaseProvider) -> void:
	logger.error("Orchestrator", "Provider error (HTTP %d): %s" % [code, error])

	# Attempt fallback
	if router and router.try_fallback():
		logger.info("Orchestrator", "Retrying with fallback provider…")
		var fp := router.get_provider()
		fp.response_completed.connect(_on_provider_response.bind(fp), CONNECT_ONE_SHOT)
		fp.request_failed.connect(_on_provider_failed.bind(fp), CONNECT_ONE_SHOT)
		fp.send_chat(_last_messages, self)
		return

	_busy = false
	_fail(error)


func _on_success(raw_text: String) -> void:
	status_changed.emit("Parsing response…")
	var structured := _parse_response(raw_text)
	
	if _is_autonomous:
		if structured.get("action") == "plan":
			_autonomous_steps = structured.get("steps", [])
			_current_step_idx = 0
			logger.info("Orchestrator", "Autonomous Plan generated with %d steps." % _autonomous_steps.size())
			_execute_next_step()
			return
		elif _current_step_idx < _autonomous_steps.size():
			logger.info("Orchestrator", "Step %d completed." % (_current_step_idx + 1))
			_current_step_idx += 1
			if _current_step_idx < _autonomous_steps.size():
				_execute_next_step()
				return
			else:
				_is_autonomous = false
				logger.info("Orchestrator", "Autonomous Goal Reached.")
	
	status_changed.emit("Ready")
	response_ready.emit(structured)


func _execute_next_step() -> void:
	if _current_step_idx >= _autonomous_steps.size():
		return
		
	var step = _autonomous_steps[_current_step_idx]
	var task = step.get("task", "")
	var role = step.get("role", "Programmer")
	
	status_changed.emit("Executing Step %d/%d..." % [_current_step_idx + 1, _autonomous_steps.size()])
	logger.info("Orchestrator", "Exec Step %d: %s [%s]" % [_current_step_idx + 1, task, role])
	
	# Reuse send logic but override prompt to be specific task
	send(task)


func _fail(msg: String) -> void:
	status_changed.emit("Error")
	request_error.emit(msg)
	_busy = false


# ---------------------------------------------------------------------------
# Response normalisation
# ---------------------------------------------------------------------------

## Strip markdown fences, parse JSON, return normalised dict.
func _parse_response(raw: String) -> Dictionary:
	var clean := raw.strip_edges()

	# Strip ```json ... ``` or ``` ... ``` fences
	for fence in ["```json", "```gdscript", "```"]:
		if clean.begins_with(fence):
			clean = clean.substr(fence.length())
			break
	if clean.ends_with("```"):
		clean = clean.substr(0, clean.length() - 3)
	clean = clean.strip_edges()

	var json := JSON.new()
	if json.parse(clean) != OK:
		logger.warn("Orchestrator", "Response is not JSON; wrapping as explanation.")
		return { "action": "explain", "explanation": raw, "code": "", "nodes": [], "assets": [], "commands": [] }

	var data: Dictionary = json.get_data()
	# Ensure all expected keys exist
	for key in ["action", "code", "nodes", "assets", "explanation", "commands", "steps"]:
		if not data.has(key):
			data[key] = [] if key in ["nodes", "assets", "commands", "steps"] else ""
	return data
