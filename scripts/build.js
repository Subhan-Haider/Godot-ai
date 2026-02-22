/**
 * build.js — Copies both addons into a clean dist/ folder.
 * Output structure mirrors what a Godot project expects:
 *   dist/
 *     addons/ai_assistant/  (production-ready plugin)
 *     addons/ai_builder/    (legacy plugin)
 */

import { cpSync, rmSync, mkdirSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dir = dirname(fileURLToPath(import.meta.url));
const root = join(__dir, "..");          // ai_project/
const dist = join(root, "dist");

console.log("🔨 Building AI Assistant Plugin...\n");

// --- Clean dist ---
if (existsSync(dist)) {
    rmSync(dist, { recursive: true, force: true });
    console.log("  ✓ Cleaned dist/");
}
mkdirSync(dist, { recursive: true });

// --- Copy addons ---
const addons = ["ai_assistant", "ai_builder"];
for (const addon of addons) {
    const src = join(root, "addons", addon);
    const dest = join(dist, "addons", addon);

    if (!existsSync(src)) {
        console.warn(`  ⚠ Skipping '${addon}' — folder not found.`);
        continue;
    }

    cpSync(src, dest, {
        recursive: true,
        filter: (src) => {
            // Exclude __pycache__, .godot cache, backup files
            return !src.includes("__pycache__") &&
                !src.includes(".godot") &&
                !src.endsWith("_backup.gd") &&
                !src.endsWith(".uid");
        }
    });
    console.log(`  ✓ Copied addons/${addon} → dist/addons/${addon}`);
}

// --- Copy project.godot so dist is a valid Godot project ---
cpSync(join(root, "project.godot"), join(dist, "project.godot"));
console.log("  ✓ Copied project.godot");

console.log("\n✅ Build complete → dist/");
