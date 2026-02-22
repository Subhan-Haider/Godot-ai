## ProviderRouter — selects, instantiates, and manages provider lifecycle.
## Implements hybrid routing: free-first → paid fallback, health checking, retry.
@tool
class_name ProviderRouter
extends RefCounted

signal provider_changed(provider_name: String)

const PROVIDERS := {
	"openai":       "res://addons/ai_assistant/providers/OpenAIProvider.gd",
	"openrouter":   "res://addons/ai_assistant/providers/OpenRouterProvider.gd",
	"gemini":       "res://addons/ai_assistant/providers/GeminiProvider.gd",
	"grok":         "res://addons/ai_assistant/providers/GrokProvider.gd",
	"huggingface":  "res://addons/ai_assistant/providers/HuggingFaceProvider.gd",
	"ollama":       "res://addons/ai_assistant/providers/OllamaProvider.gd",
	"custom":       "res://addons/ai_assistant/providers/CustomProvider.gd",
}

const FREE_PROVIDERS  := ["ollama"]
const PAID_PROVIDERS  := ["openai", "openrouter", "gemini", "grok", "huggingface", "custom"]

var active_id:  String         = "openai"
var _provider:  BaseProvider   = null
var _config:    Dictionary     = {}   # full config dict from ProfileManager
var _logger:    AILogger       = null
var hybrid_mode: bool          = true
var _retry_count: int          = 0
var max_retries:  int          = 2


func setup(config: Dictionary, logger: AILogger) -> void:
	_config = config
	_logger = logger
	_switch_to(config.get("active_provider", "openai"))


## Returns the currently active provider instance.
func get_provider() -> BaseProvider:
	return _provider


## Manually switch to a named provider.
func switch_to(provider_id: String) -> bool:
	return _switch_to(provider_id)


## Auto-select the best available provider for a given prompt.
func select_best(prompt: String) -> BaseProvider:
	if hybrid_mode:
		for pid in FREE_PROVIDERS:
			if _is_healthy(pid):
				if pid != active_id:
					_switch_to(pid)
					_logger.info("Router", "Hybrid: routed to free provider '%s'." % pid)
				return _provider

	# Complexity heuristic: long prompts or script-related go to most capable paid model
	var is_complex := prompt.length() > 400 or "script" in prompt.to_lower() or "architecture" in prompt.to_lower()
	var ordered    := PAID_PROVIDERS if is_complex else (FREE_PROVIDERS + PAID_PROVIDERS)

	for pid in ordered:
		if pid == active_id: return _provider
		if _is_healthy(pid):
			_switch_to(pid)
			_logger.info("Router", "Smart: selected '%s' for prompt." % pid)
			return _provider

	return _provider


## Called by orchestrator on request failure to attempt fallback.
func try_fallback() -> bool:
	_retry_count += 1
	if _retry_count > max_retries:
		_retry_count = 0
		_logger.warn("Router", "Max retries exceeded.")
		return false

	var all_ids := PAID_PROVIDERS + FREE_PROVIDERS
	var cur_idx := all_ids.find(active_id)

	for i in range(1, all_ids.size()):
		var next := all_ids[(cur_idx + i) % all_ids.size()]
		if _is_healthy(next):
			_switch_to(next)
			_logger.info("Router", "Fallback → '%s'." % next)
			return true

	return false


func reset_retry() -> void:
	_retry_count = 0


func get_provider_ids() -> Array:
	return PROVIDERS.keys()


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _switch_to(pid: String) -> bool:
	if not PROVIDERS.has(pid):
		_logger.error("Router", "Unknown provider '%s'." % pid)
		return false

	var script = load(PROVIDERS[pid])
	if not script:
		_logger.error("Router", "Could not load provider script for '%s'." % pid)
		return false

	_provider         = script.new()
	_provider.api_key = _config.get("api_keys", {}).get(pid, "")
	_provider.model_name = _config.get("models", {}).get(pid, _provider.get_default_model())
	_provider.endpoint_url = _config.get("endpoints", {}).get(pid, _provider.get_default_endpoint())
	_provider.temperature  = _config.get("temperature", 0.7)
	_provider.max_tokens   = _config.get("max_tokens", 2048)
	active_id = pid
	provider_changed.emit(pid)
	return true


func _is_healthy(pid: String) -> bool:
	var keys := _config.get("api_keys", {})
	if pid == "ollama": return true  # local server, always attempt
	return keys.get(pid, "").strip_edges() != ""
