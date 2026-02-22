## VectorMemoryStub — placeholder interface for a future vector similarity search.
## Replace _store and _search implementations with a real ChromaDB or Qdrant client.
@tool
class_name VectorMemoryStub
extends RefCounted

var _entries: Array = []  # Each entry: { "text": String, "embedding": Array }


## Store a text chunk. Embedding is currently a simple bag-of-words fingerprint.
func store(text: String, _metadata: Dictionary = {}) -> void:
	_entries.append({
		"text":      text,
		"embedding": _naive_embed(text),
		"meta":      _metadata
	})
	# Cap memory at 1000 chunks to prevent OOM
	if _entries.size() > 1000:
		_entries.pop_front()


## Return top-k most similar entries to query (naive cosine on word overlap).
func search(query: String, top_k: int = 5) -> Array:
	var q_emb := _naive_embed(query)
	var scored: Array = []
	for e in _entries:
		scored.append({ "score": _cosine(q_emb, e["embedding"]), "text": e["text"] })
	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	return scored.slice(0, top_k).map(func(s): return s["text"])


func clear() -> void:
	_entries.clear()


func size() -> int:
	return _entries.size()


# ---------------------------------------------------------------------------
# Naive embedding: word-frequency vector over a fixed 256-word vocabulary.
# Replace this with a real embedding API call for production use.
# ---------------------------------------------------------------------------

const VOCAB_SIZE := 256

func _naive_embed(text: String) -> Array:
	var vec: Array = []
	vec.resize(VOCAB_SIZE)
	vec.fill(0.0)
	for word in text.to_lower().split(" ", false):
		var idx := word.hash() % VOCAB_SIZE
		if idx < 0: idx += VOCAB_SIZE
		vec[idx] += 1.0
	return vec


func _cosine(a: Array, b: Array) -> float:
	var dot := 0.0; var ma := 0.0; var mb := 0.0
	for i in range(a.size()):
		dot += a[i] * b[i]; ma += a[i] * a[i]; mb += b[i] * b[i]
	if ma == 0.0 or mb == 0.0: return 0.0
	return dot / (sqrt(ma) * sqrt(mb))
