# AI Assistant Plugin — Setup Guide
# Version 1.0.0

## Overview

A production-ready, modular AI assistant integrated directly into the Godot 4 editor.

### Features
- **7 provider adapters**: OpenAI, OpenRouter, Gemini, Grok, HuggingFace, Ollama (local), Custom REST
- **Multi-tab dock**: Main / Settings / Debug panels
- **Intelligent routing**: Hybrid free-first, smart complexity routing, auto fallback
- **Full executor**: Create/delete/modify/reparent nodes, write scripts, attach scripts, generate docs
- **Safety system**: Safe mode, per-action permissions, auto-backup, one-click rollback
- **Conversation history**: Rolling 12-turn context window
- **Token & cost estimator**: Per-provider rate tables
- **Response cache**: On-disk JSON cache with hash keys
- **12-template library**: 2D/3D scene gen, NPC AI, refactoring, unit tests, more
- **Profile system**: Save/load named configuration profiles
- **Vector memory stub**: Ready to connect to ChromaDB/Qdrant
- **Debug log panel**: Levelled, colour-coded, timestamped

---

## Installation

1. Copy the `addons/ai_assistant/` folder into your Godot project's `addons/` directory.
2. Open **Project → Project Settings → Plugins**.
3. Find **"AI Assistant"** and set it to **Enabled**.
4. The dock panel appears in the bottom-right editor area.

---

## Quick Start

### Connect OpenAI
1. Select **"openai"** from the Provider dropdown.
2. Paste your `sk-…` key in the API Key field.
3. Model defaults to `gpt-4o`. Change if needed.
4. Click **✉ Send** with a prompt such as:
   > "Create a CharacterBody2D named Player with WASD movement."

### Use Ollama (local, free)
1. Install and start Ollama: `ollama serve`
2. Pull a model: `ollama pull llama3`
3. Select **"ollama"** in the provider dropdown.
4. No API key needed. Model: `llama3`.
5. Enable **Hybrid Mode** in Settings to auto-prefer Ollama.

---

## Response Schema

The assistant always returns a JSON object. The plugin parses this and dispatches actions:

```json
{
  "action": "batch",
  "nodes": [
    { "type": "CharacterBody2D", "name": "Player", "parent": "", "properties": {} },
    { "type": "CollisionShape2D", "name": "Shape", "parent": "Player", "properties": {} }
  ],
  "code": "extends CharacterBody2D\n...",
  "assets": [],
  "explanation": "Created a Player node with movement script.",
  "commands": []
}
```

### Available Actions

| Action | Description |
|---|---|
| `batch` | Run multiple sub-actions from `commands` array |
| `create_node` | Create nodes from the `nodes` array |
| `delete_node` | Delete node by `name` |
| `modify_node` | Set `properties` on node `name` |
| `reparent_node` | Move `name` to new `parent` |
| `connect_signal` | Connect `signal` on `name` to `method` on `target` |
| `write_script` | Write GDScript to `nodes[0].path` |
| `attach_script` | Attach existing script at `path` to node `name` |
| `generate_docs` | Write markdown to `nodes[0].path` |
| `explain` | Text in `explanation` only, no editor changes |
| `noop` | Do nothing |

---

## Architecture

```
addons/ai_assistant/
├── plugin.cfg
├── plugin.gd                      # EditorPlugin entry point
│
├── core/
│   ├── AIOrchestrator.gd          # Central coordinator  ← DI hub
│   ├── ConversationHistory.gd     # Rolling message window
│   ├── TokenEstimator.gd          # Cost & token tracking
│   ├── CacheManager.gd            # On-disk JSON response cache
│   ├── PromptTemplateLibrary.gd   # 12 built-in + user templates
│   └── Logger.gd                  # Levelled logging with signal
│
├── providers/
│   ├── BaseProvider.gd            # Abstract interface
│   ├── OpenAIProvider.gd
│   ├── OpenRouterProvider.gd
│   ├── GeminiProvider.gd
│   ├── GrokProvider.gd
│   ├── HuggingFaceProvider.gd
│   ├── OllamaProvider.gd
│   └── CustomProvider.gd
│
├── routing/
│   └── ProviderRouter.gd          # Hybrid/smart routing + fallback
│
├── executor/
│   └── ActionExecutor.gd          # Full action dispatcher + undo + backup
│
├── context/
│   ├── ContextCollector.gd        # Scene tree, script, assets, settings
│   └── VectorMemoryStub.gd        # Pluggable vector memory interface
│
├── config/
│   └── ProfileManager.gd          # Save/load JSON profiles
│
└── ui/
    └── MainDock.gd                # 3-tab dock (Main / Settings / Debug)
```

---

## Adding a New Provider

1. Create `addons/ai_assistant/providers/MyProvider.gd`
2. Extend `BaseProvider`
3. Override `get_provider_name()`, `send_chat()`, and optionally `fetch_models()`
4. Register the path in `ProviderRouter.PROVIDERS`
5. Restart the plugin

```gdscript
@tool
class_name MyProvider
extends BaseProvider

func get_provider_name() -> String: return "MyProvider"
func get_default_endpoint() -> String: return "https://api.myprovider.com/v1/chat"
func get_default_model() -> String: return "my-model-v1"

func send_chat(messages: Array, node: Node) -> void:
    var http := _make_http(node)
    http.request_completed.connect(_on_done.bind(http))
    http.request(get_default_endpoint(), [...], HTTPClient.METHOD_POST, JSON.stringify({...}))

func _on_done(_r, code, _h, body, http):
    http.queue_free()
    if code != 200: _emit_failure("Error %d" % code); return
    _emit_success("parsed text here")
```

---

## Safety Reference

| Feature | Behaviour |
|---|---|
| **Safe Mode** | Blocks `delete_node` and `write_script` entirely |
| **Permissions** | Per-action flags in config `permissions` dict |
| **Auto Backup** | Before overwriting any script, copies to `_backup.gd` |
| **Rollback** | ⟲ button restores last backed-up script |
| **Preview Dialog** | Every destructive action shows diff before applying |
| **Undo** | All node operations registered with `EditorUndoRedoManager` |

---

## Configuration Profile Format

Profiles are stored in `user://ai_assistant_profiles/<name>.json`:

```json
{
  "active_provider": "openai",
  "api_keys":   { "openai": "sk-...", "gemini": "AI..." },
  "models":     { "openai": "gpt-4o", "ollama": "llama3" },
  "endpoints":  { "ollama": "http://localhost:11434/api/chat" },
  "temperature": 0.7,
  "max_tokens":  2048,
  "safe_mode":   false,
  "hybrid_mode": true,
  "cache_enabled": true,
  "permissions": {
    "create_nodes": true, "delete_nodes": true,
    "write_scripts": true, "fetch_external": true
  }
}
```
