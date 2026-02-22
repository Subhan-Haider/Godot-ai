## TokenEstimator — approximates token count & cumulative cost.
@tool
class_name TokenEstimator
extends RefCounted

signal stats_updated(requests: int, total_tokens: int, total_cost_usd: float, last_latency_ms: int)

# Cost per 1k tokens (rough averages, can be overridden)
const COST_PER_1K := {
	"openai":      0.003,
	"openrouter":  0.002,
	"gemini":      0.001,
	"grok":        0.002,
	"huggingface": 0.001,
	"ollama":      0.0,
	"custom":      0.001,
}

var total_requests:   int   = 0
var total_tokens:     int   = 0
var total_cost_usd:   float = 0.0
var last_latency_ms:  int   = 0
var _provider_id:     String = "openai"


func set_provider(pid: String) -> void:
	_provider_id = pid


## Estimate tokens for a messages array (4 chars ≈ 1 token heuristic).
func estimate_messages(messages: Array) -> int:
	var chars := 0
	for m in messages:
		chars += str(m.get("content", "")).length()
	return chars / 4


## Record a completed response for stats.
func record_response(text: String, latency_ms: int) -> void:
	last_latency_ms = latency_ms
	var tokens := text.length() / 4
	total_tokens   += tokens
	total_requests += 1
	var rate := COST_PER_1K.get(_provider_id, 0.001)
	total_cost_usd += (float(tokens) / 1000.0) * rate
	stats_updated.emit(total_requests, total_tokens, total_cost_usd, last_latency_ms)


func reset() -> void:
	total_requests  = 0
	total_tokens    = 0
	total_cost_usd  = 0.0
	last_latency_ms = 0
