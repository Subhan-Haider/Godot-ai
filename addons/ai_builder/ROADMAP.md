# AI Builder Expansion Roadmap

This document outlines the massive planned feature set for the AI Builder Godot Engine middleware.

## 🧠 1. AI CORE SYSTEM FEATURES
### 🔌 Multi-Provider Engine
- [x] Unlimited provider support
- [x] Plugin-based provider system
- [x] Add custom REST endpoint
- [x] OpenAI-compatible mode
- [x] Automatic provider health check
- [x] Fallback routing
- [x] Smart provider selection
- [x] Per-task provider selection

### 🔑 API Key Management
- [x] Secure key storage (Basic)
- [x] Encrypted local save
- [x] Multiple keys per provider
- [x] Key validation checker
- [x] Usage tracking & Cost estimator
- [x] Free-tier detector & Rate limit monitor

### 🤖 Model Management
- [x] Manual model entry
- [x] Fetch available models dynamically
- [x] Model capability detection (Text, Code, Image, Audio, Function calling, Vision)
- [x] Model performance stats (Latency, Cost per 1k tokens)

### 🧾 Unified AI Abstraction Layer
- [x] Unified message format
- [x] Provider response normalizer
- [x] Structured JSON enforcement
- [x] Tool calling wrapper
- [x] Streaming adapter
- [x] Error normalization, Retry logic, Timeout handling

## 🎮 2. GAME DEVELOPMENT FEATURES
### 🏗 Scene Generation
- [x] Generate node trees
- [x] Generate full 2D scene / Generate 3D environment
- [x] Auto camera & lighting setup
- [x] UI layout generator & Responsive UI builder
- [x] Tilemap & Procedural map auto-generation

### 🧩 Node Creation & Editing
- [x] Add nodes
- [x] Delete nodes
- [x] Modify properties
- [x] Connect signals
- [x] Batch edit nodes
- [x] Rename hierarchy safely
- [x] Convert node types & Reparent nodes

### 📜 Script System
- [x] Generate GDScript
- [x] Attach automatically
- [x] Refactor existing code
- [x] Optimize code & Fix errors
- [x] Explain code & Add comments
- [x] Generate unit tests

### 🖼 Asset Generation
- [x] Sprite & UI generation
- [x] Backgrounds & Tilesets
- [x] Audio (SFX, Ambient, Music, Voice)
- [x] 3D (Meshes, Materials, PBR textures, Shaders)

### 🎬 Animation System
- [x] Create animation player tracks
- [x] Setup state machines & Auto transition rules
- [x] Blend tree generation & AI movement logic

## 🧠 3. GAME DESIGN INTELLIGENCE
- [x] Game Idea Generator (Concept, Monetization, Market fit)
- [x] Gameplay Balancing (Difficulty scaling, Health/damage balancing, Economy)
- [x] Level Design AI (Layouts, Enemy placement, Pathfinding optimization)
- [x] NPC Intelligence (Behavior tree generation, Dialogue systems, Quest systems, Factions)

## 🛠 4. DEVELOPER ASSISTANT FEATURES
- [x] Debug Assistant (Analyze error logs, Suggest fixes, Identify null references, Memory leak hints)
- [x] Refactor Assistant (Safe rename, Modularization, Dead code removal, Duplicate detection)
- [x] Documentation Generator (Auto README, Script documentation, API docs, Inline comments)
- [x] Learning Mode (Explain Godot nodes, Interactive tutorials, Guided build mode)

## 🧱 5. EDITOR INTEGRATION FEATURES
### 🖥 AI Dock Panel
- [x] Command mode interface
- [x] Structured action mode
- [x] Prompt templates
- [x] Action preview window

### 👁 Context Awareness
- [x] AI reads Scene tree
- [x] AI reads Scripts
- [x] AI reads Project settings, Signals, Input mappings, Assets list

### 🔍 Visual Diff System
- [x] Highlight changed nodes
- [x] Show script diff
- [x] Approve before apply & Undo stack

## 🔄 6. AUTONOMOUS AI MODE
- [x] Planning Mode (Break goal into steps, Execute sequentially, Evaluate result, Improve iteration)
- [x] Multi-Agent System (Designer, Programmer, Artist, Tester collaboration)
- [x] Self Testing (Simulate gameplay, Detect crashes, Detect logic flaws, Suggest improvements)

## 🌐 7. COLLABORATION FEATURES
- [x] Share prompt templates & Team AI profiles
- [x] Cloud sync & Version history
- [x] Prompt marketplace & Plugin extension system

## 🔒 8. SECURITY & SAFETY
- [x] File access restriction
- [x] Script execution sandbox (Basic)
- [x] Permission system
- [x] Auto backup before changes
- [x] Rollback system & Safe mode

## 📊 9. ANALYTICS & OPTIMIZATION
- [x] AI usage dashboard & Provider comparison
- [x] Cost tracking & Token usage tracking

## 💰 10. MONETIZATION FEATURES
- [x] Premium AI routing & Hosted proxy service
- [x] Plugin store & AI template marketplace

## 🧬 11. ADVANCED FUTURE FEATURES
- [x] Screenshot understanding (vision models)
- [x] Voice-to-command & In-editor speech assistant
- [x] AI code autocomplete
- [x] AI auto-play tester
- [x] Game style consistency training
- [x] Project memory vector database
- [x] Offline full LLM integration & AI fine-tuning tools

## 📦 12. FREE + PAID MODEL SUPPORT
- [x] Free Models (Ollama local, Free-tier APIs)
- [x] Paid Models (Premium cloud APIs)
- [x] Hybrid Mode (Try free first -> Fallback to paid -> Cost-based auto routing)
