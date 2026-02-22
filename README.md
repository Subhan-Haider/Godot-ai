# Godot AI Builder & Assistant

Welcome to the **Godot AI Builder & Assistant**! This is a powerful, AI-driven suite of plugins for Godot 4.x that supercharges your game development workflow directly within the Godot editor.

## 🚀 Features

*   **Multi-Provider Support**: Seamlessly switch between local and cloud AI models. Supports:
    *   **Ollama (Local)** - Run models like LLaMA 3 or Mistral entirely on your own hardware for free!
    *   **OpenRouter**
    *   **Google Gemini**
    *   **HuggingFace**
    *   **Custom Endpoints**
*   **Autonomous Multi-Agent Workflow**: Watch the AI build your game step-by-step.
    *   **Architect**: Plans the Scene Tree and node hierarchies.
    *   **Logic Engineer**: Writes robust GDScript and connects signals.
    *   **Visual Designer**: Handles layout presets and visual setup.
    *   **QA Lead**: Tests game loops and project health.
*   **Direct Editor Integration**: The AI can execute real editor actions on your behalf:
    *   Create, delete, rename, and reparent nodes.
    *   Modify node properties (e.g., positions, colors, layouts).
    *   Write, validate, and attach GDScripts.
    *   Connect signals between nodes automatically.
*   **Project Health Scanner**: Recursively scans your project for GDScript syntax errors and uses AI to automatically propose and implement fixes.
*   **Safety First**: Includes a "Safe Mode" toggle that blocks destructive actions (like deleting nodes or modifying critical files) without your explicit permission. Built-in Undo/Redo support for all AI actions.

## 🛠️ Usage

1. **Open the AI Builder Dock** in the Godot Editor.
2. **Select your AI Provider** (e.g., Ollama for local, or enter an API key for OpenRouter/Gemini).
3. **Choose a Template or Write a Prompt**: Describe what you want to build (e.g., *"Generate a Main Menu UI with a Start and Quit button"*).
4. **Generate Blueprint**: The AI will plan and explain the necessary steps. 
5. **Execute**: Click 'Apply' to see the nodes and scripts instantly appear in your project!

## 🤖 Local Setup with Ollama
To use the free, local AI:
1. Download and install [Ollama](https://ollama.com/).
2. Run `ollama run llama3` in your terminal to download a fast, powerful model.
3. In the Godot AI Builder dock, select **Ollama** as the provider and click the fetch models button!

## 📜 License
This project is open-source. Feel free to fork, modify, and contribute!
