/**
 * lint.js — Style and convention checker for GDScript.
 * Focuses on readability and Godot 4 best practices.
 */

import { readdirSync, readFileSync, statSync } from "fs";
import { join, extname, dirname } from "path";
import { fileURLToPath } from "url";

const __dir = dirname(fileURLToPath(import.meta.url));
const root = join(__dir, "..");
const addons = join(root, "addons");

let warnings = 0;
let checked = 0;

console.log("🎨 Linting GDScript style...\n");

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

function lintGD(path, src) {
    const lines = src.split("\n");
    const rel = path.replace(root + "\\", "").replace(/\\/g, "/");
    let fileWarnings = 0;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const ln = i + 1;
        const trimmed = line.trim();

        if (trimmed.length === 0) continue;

        // Rule: Line length > 120
        if (line.length > 120) {
            warn(rel, ln, `Line too long (${line.length} > 120 chars).`);
            fileWarnings++;
        }

        // Rule: Snake_case for variables (basic check)
        if (/var\s+[A-Z]/.test(trimmed)) {
            warn(rel, ln, `Variables should use snake_case: "${trimmed}"`);
            fileWarnings++;
        }

        // Rule: PascalCase for ClassNames
        if (/class_name\s+[a-z]/.test(trimmed)) {
            warn(rel, ln, `class_name should use PascalCase: "${trimmed}"`);
            fileWarnings++;
        }

        // Rule: Missing space after comma
        if (/,(\w)/.test(trimmed)) {
            warn(rel, ln, `Add a space after comma: "${trimmed}"`);
            fileWarnings++;
        }

        // Rule: No space before colon in types
        if (/\s+:/.test(trimmed)) {
            warn(rel, ln, `Avoid space before type colon: "${trimmed}"`);
            fileWarnings++;
        }
    }

    if (fileWarnings === 0) console.log(`  ✓  ${rel}`);
    checked++;
}

walk(addons, (full, name) => {
    if (extname(name) === ".gd") {
        const src = readFileSync(full, "utf8");
        lintGD(full, src);
    }
});

console.log("\n" + "─".repeat(60));
console.log(`Linted: ${checked} files | Warnings: ${warnings}`);
if (warnings > 0) {
    console.log("\n💡 Style improvements suggested.");
} else {
    console.log("\n✨ Perfectly styled!");
}

function warn(rel, ln, msg) { warnings++; console.warn(`  ⚠  ${rel}:${ln} — ${msg}`); }
