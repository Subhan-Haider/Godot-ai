/**
 * watch.js — Dev-watch script that monitors addons/ and rebuilds on change.
 */

import chokidar from "chokidar";
import { exec } from "child_process";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dir = dirname(fileURLToPath(import.meta.url));
const root = join(__dir, "..");
const addons = join(root, "addons");

console.log("👀 Watching for changes in addons/...");

const watcher = chokidar.watch(addons, {
    ignored: /(^|[\/\\])\../, // ignore dotfiles
    persistent: true,
    ignoreInitial: true
});

function rebuild() {
    console.log("\n📦 Change detected. Rebuilding...");
    exec("npm run build", (err, stdout, stderr) => {
        if (err) {
            console.error(`❌ Build failed: ${err.message}`);
            return;
        }
        console.log(stdout);
        if (stderr) console.error(stderr);
        console.log("✅ Build updated.");
    });
}

watcher
    .on("add", rebuild)
    .on("change", rebuild)
    .on("unlink", rebuild);

process.on("SIGINT", () => {
    watcher.close();
    process.exit();
});
