# Godot AI Builder & Assistant

Welcome to the **Godot AI Builder & Assistant**! This is a powerful, AI-driven suite of plugins for Godot 4.x that supercharges your game development workflow directly within the Godot editor.

## 🛠️ Installation & Setup

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/Subhan-Haider/Godot-ai.git
   ```
2. **Move the Plugins:** Copy the `addons/ai_builder` and `addons/ai_assistant` folders into your Godot project's `res://addons/` directory.
3. **Enable the Plugins:** Go to **Project > Project Settings > Plugins** in the Godot Editor. Check the "Enabled" box next to **AI Builder** and **AI Assistant**.
4. **Configure:** Open the new AI docks, select your preferred provider, and enter your API keys (or start your local Ollama server).

## 🚀 Key Capabilities

*   **Multi-Provider Support**: Seamlessly switch between local and cloud AI models.
    *   **Ollama (Local)** - Run models like LLaMA 3 or Mistral entirely on your own hardware for free! *No internet connection required.*
    *   **OpenRouter** - Access top-tier models like GPT-4, Claude 3, and more.
    *   **Google Gemini** - Fast and capable inference using Gemini 1.5 Pro/Flash.
    *   **HuggingFace** - Open-weights models hosted on HF inference endpoints.
    *   **Custom Endpoints** - Connect to any OpenAI-compatible API format.
*   **Autonomous Multi-Agent Workflow**: Watch the AI build your game step-by-step.
    *   **Architect**: Plans the Scene Tree, node hierarchies, and structure.
    *   **Logic Engineer**: Writes robust GDScript, assigns classes, and connects signals.
    *   **Visual Designer**: Handles layout presets, materials, and visual setup.
    *   **QA Lead**: Tests game loops, fixes syntax errors, and manages project health.
*   **Direct Editor Integration**: The AI can execute real editor actions on your behalf:
    *   Create, delete, rename, and reparent nodes in the active scene.
    *   Modify node properties (e.g., positions, colors, layouts, physics flags).
    *   Write, validate, and attach GDScripts dynamically.
    *   Connect Godot signals between nodes automatically.
*   **Project Health Scanner**: Recursively scans your `res://` directory for GDScript syntax errors. The AI automatically proposes and implements fixes to keep your game bug-free.
*   **Safety First**: Includes a "Safe Mode" toggle that blocks destructive actions (like deleting nodes or modifying critical scripts). Built-in integration with Godot's `UndoRedo` system allows you to reverse any AI action instantly.
*   **Context Aware**: Automatically injects details about your open scene, active scripts, and project structure into the prompt, giving the AI a deep understanding of your game without you having to explain everything.

## 💻 Usage Example

1. **Open the AI Builder Dock** in the Godot Editor.
2. **Select your AI Provider** (e.g., Ollama).
3. **Write a Prompt**: Give the AI a high-level goal, such as:
   > *"Generate a Main Menu UI. Use a CanvasLayer with a TextureRect background. Add a VBoxContainer in the center with two Buttons: 'Start Game' and 'Quit'. Write a script, attach it to the CanvasLayer, and connect the button pressed signals to print statements."*
4. **Generate Blueprint**: The AI will analyze the request and generate a structured JSON execution plan.
5. **Review & Execute**: Click 'Apply' to see the nodes, control layouts, scripts, and signal connections instantly appear in your project!

## 🤖 Local Setup with Ollama
Running AI locally gives you ultimate privacy and zero API costs.
1. Download and install [Ollama](https://ollama.com/).
2. Run `ollama run llama3` in your terminal to download and start a fast, powerful model.
3. In the Godot AI Builder dock, select **Ollama** as the provider.
4. Click the **Model Sync** button (`🔄`). The plugin will auto-detect your running instance.

## 💡 FAQ & Troubleshooting

*   **Error parsing URL /tags from Ollama**: Make sure you have the Ollama app running in the background and that the model is fully downloaded (`ollama pull llama3`). If the error persists, toggle the plugin off and on via Project Settings to clear cache.
*   **The AI hallucinates invalid Godot 4 syntax**: If you are using weaker local models (like Llama3 8B), they may struggle with strict Godot 4 syntax. Try switching to a more powerful model via OpenRouter (like Claude-3.5-Sonnet or GPT-4o), or use the **Project Health Scanner** to auto-fix the errors.
*   **Safe Mode is blocking my scripts**: Safe Mode is enabled by default to prevent the AI from overwriting core game files accidentally. You can toggle this off in the AI Builder dock under the 'Safety Controls' section.
*   **API Key is not saving**: Go to your Godot settings and make sure Godot has read/write permissions for its `user://` directory, as API keys are stored in an encrypted configuration file there.

## 🗺️ Roadmap Planner

We are continuously improving the plugin. Upcoming features include:
*   Visual Node dragging functionality to drop AI modules onto your scene.
*   More advanced Audio and Image generation integrations.
*   A fully chat-based inline script editor plugin.

## 🤝 Contributing
Contributions are extremely welcome! Whether it's adding a new AI provider, improving the action executors, or designing robust prompts.
1. Fork the project.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

## 📜 License
This project is open-source under the MIT License. Feel free to fork, modify, and contribute to pushing the boundaries of AI-assisted game development!

