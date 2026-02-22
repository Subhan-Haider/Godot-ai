/**
 * package.js — Zips the dist/ folder into a versioned release archive.
 * Reads version from package.json. Output: releases/ai-assistant-v{version}.zip
 * Run AFTER build.js.
 */

import archiver from "archiver";
import { createWriteStream, mkdirSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { createRequire } from "module";

const require = createRequire(import.meta.url);
const __dir = dirname(fileURLToPath(import.meta.url));
const root = join(__dir, "..");
const pkg = require(join(root, "package.json"));
const version = pkg.version ?? "0.0.0";

const dist = join(root, "dist");
const releases = join(root, "releases");
const zipName = `ai-assistant-v${version}.zip`;
const zipPath = join(releases, zipName);

if (!existsSync(dist)) {
    console.error("❌ dist/ not found. Run `npm run build` first.");
    process.exit(1);
}

mkdirSync(releases, { recursive: true });

const output = createWriteStream(zipPath);
const zip = archiver("zip", { zlib: { level: 9 } });

zip.on("warning", (err) => { if (err.code !== "ENOENT") throw err; });
zip.on("error", (err) => { throw err; });

output.on("close", () => {
    const kb = (zip.pointer() / 1024).toFixed(1);
    console.log(`\n✅ Packaged → releases/${zipName}  (${kb} KB)`);
});

zip.pipe(output);
zip.directory(dist, false);  // Add dist/ contents at zip root
await zip.finalize();

console.log("📦 Packaging complete.");
