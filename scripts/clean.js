/**
 * clean.js — Removes build artifacts (dist/ and releases/).
 */

import { rmSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dir = dirname(fileURLToPath(import.meta.url));
const root = join(__dir, "..");

const targets = ["dist", "releases"];

console.log("🧹 Cleaning project artifacts...");

targets.forEach(target => {
    const path = join(root, target);
    if (existsSync(path)) {
        rmSync(path, { recursive: true, force: true });
        console.log(`  ✓ Removed ${target}/`);
    }
});

console.log("\n✨ Clean complete.");
