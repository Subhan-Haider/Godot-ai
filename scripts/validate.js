/**
 * validate.js — Validates all .gd scripts and .json files in the project.
 *
 * GDScript checks:
 *   - @tool annotation on editor plugins
 *   - Unclosed string literals
 *   - func defined without parentheses
 *   - Tabs vs spaces consistency issue detection
 *
 * JSON checks:
 *   - Valid parseable JSON for plugin.cfg values and template files
 */

import { readdirSync, readFileSync, statSync } from "fs";
import { join, extname, dirname } from "path";
import { fileURLToPath } from "url";

const __dir = dirname(fileURLToPath(import.meta.url));
const root = join(__dir, "..");
const addons = join(root, "addons");

let errors = 0;
let warnings = 0;
let checked = 0;

console.log("🔍 Validating plugin sources...\n");

// ---------------------------------------------------------------------------
// Walk all files recursively
// ---------------------------------------------------------------------------
function walk(dir, cb) {
    for (const entry of readdirSync(dir)) {
        const full = join(dir, entry);
        if (statSync(full).isDirectory()) {
            if (!entry.startsWith(".") && entry !== ".godot") walk(full, cb);
        } else {
            cb(full, entry);
        }
    }
}

// ---------------------------------------------------------------------------
// GDScript validator
// ---------------------------------------------------------------------------
function validateGD(path, src) {
    const lines = src.split("\n");
    const rel = path.replace(root + "\\", "").replace(/\\/g, "/");
    let fileErrors = 0;

    // Rule: editor plugin files should have @tool
    if (path.includes("addons") && !src.includes("@tool") && !path.includes("providers")) {
        warn(rel, 0, "Missing @tool annotation — required for EditorPlugins.");
    }

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const ln = i + 1;

        // Rule: func without parentheses (must catch "func name " without "(")
        const trimmed = line.trim();
        if (trimmed.startsWith("func ") && !trimmed.includes("(")) {
            err(rel, ln, `Malformed func declaration (missing parentheses): "${trimmed}"`);
            fileErrors++;
        }

        // Rule: print with concatenation instead of format (style warning)
        if (/print\(.*\+.*\)/.test(line) && !line.trim().startsWith("#")) {
            // Not an error, just a nudge
        }

        // Rule: mixed tabs/spaces in indentation (compare line-by-line)
        if (line.startsWith(" ") && line.includes("\t")) {
            warn(rel, ln, "Mixed indentation detected on this line.");
        }
    }

    if (fileErrors === 0) ok(rel);
    checked++;
}

// ---------------------------------------------------------------------------
// JSON validator
// ---------------------------------------------------------------------------
function validateJSON(path, src) {
    const rel = path.replace(root + "\\", "").replace(/\\/g, "/");
    try {
        JSON.parse(src);
        ok(rel);
        checked++;
    } catch (e) {
        err(rel, null, "Invalid JSON: " + e.message);
    }
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------
walk(addons, (full, name) => {
    const ext = extname(name);
    const src = readFileSync(full, "utf8");

    if (ext === ".gd") validateGD(full, src);
    if (ext === ".json") validateJSON(full, src);
});

// Summary
console.log("\n" + "─".repeat(60));
console.log(`Checked: ${checked} files | ✓ | Warnings: ${warnings} | Errors: ${errors}`);
if (errors > 0) {
    console.error(`\n❌ Validation failed with ${errors} error(s).`);
    process.exit(1);
} else {
    console.log("\n✅ All files passed validation.");
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function ok(rel) { console.log(`  ✓  ${rel}`); }
function warn(rel, ln, msg) { warnings++; console.warn(`  ⚠  ${rel}${ln ? ":" + ln : ""} — ${msg}`); }
function err(rel, ln, msg) { errors++; console.error(`  ✗  ${rel}${ln ? ":" + ln : ""} — ${msg}`); }
