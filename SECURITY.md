# Security Policy

## Supported Versions

Currently, the following versions of the Godot AI Builder are actively supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| v1.0.x  | :white_check_mark: |

## Reporting a Vulnerability

We take the security of this project very seriously. Because the Godot AI Builder interfaces with local file systems (`res://`) and executes code based on AI logic, protecting users from accidentally destructive actions or malicious prompts (Prompt Injection) is a priority.

If you discover a security vulnerability, **please do not report it by opening a public GitHub issue**.

Instead, please send an email to `subhan@example.com` (or create a private GitHub Security Advisory in the repository). 

### What to Include in Your Report:
*   A clear description of the vulnerability.
*   The steps required to reproduce the issue.
*   The versions of Godot and the Plugin affected.
*   (Optional) Any ideas or fixes to resolve the issue.

### Our Response:
We will try to acknowledge your report within 48 hours. If the vulnerability is accepted, we will coordinate with you to publish a fix and appropriately credit you for the discovery.

### Note on "Safe Mode"
The plugin includes a **Safe Mode** toggle designed to block potentially destructive actions (like `delete_node` or `write_script` overwrites) without explicit user intervention. If you find a way to consistently bypass Safe Mode via a standard AI Action generation, please report it following the guidelines above.
