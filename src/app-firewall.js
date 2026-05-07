const fs = require("fs");
const path = require("path");

function block(p) {
    if (!p) return;
    const s = p.toString();
    
    // Target the sensitive configuration and credential paths
    if (s.includes(".pi/agent") || s.includes("gh_") || s.includes(".secrets") || s.includes(".env")) {
        // If the execution stack originates from the AI agent's tools, block it.
        // This allows the core application to operate normally.
        if (new Error().stack.includes("/tools/")) {
            throw new Error("[SYSTEM BLOCK] Agent is sandboxed and cannot access configuration or credential files.");
        }
    }
}

// -----------------------------------------------------------------------------
// ZERO-TRUST V8 MEMORY VAULT
// Defeats statically compiled binaries (Rust/Go) that bypass LD_PRELOAD.
// We absorb the true token into V8 RAM, then nuke the OS-level file with a decoy.
// Static binaries reading the disk natively will only exfiltrate garbage.
// -----------------------------------------------------------------------------
let cachedAuth = null;
const DECOY_CONTENT = JSON.stringify({ token: "ghp_decoy_token_hardware_locked" }, null, 2);

try {
    const authPath = path.join(process.env.HOME || "/home/node", ".pi/agent/auth.json");
    if (fs.existsSync(authPath)) {
        const content = fs.readFileSync(authPath, "utf8");
        if (!content.includes("ghp_decoy")) {
            cachedAuth = content;
            fs.writeFileSync(authPath, DECOY_CONTENT);
        }
    }
} catch (e) {}
// -----------------------------------------------------------------------------

// Intercept all major filesystem operations
const hooks = [
    "readFile", "readFileSync", "createReadStream", 
    "writeFile", "writeFileSync", "createWriteStream", "appendFile", "appendFileSync",
    "open", "openSync", 
    "unlink", "unlinkSync", "rm", "rmSync", "rmdir", "rmdirSync",
    "readdir", "readdirSync"
];

hooks.forEach(fn => {
    // Hook standard fs callbacks/sync methods
    if (fs[fn]) {
        const orig = fs[fn];
        fs[fn] = function(...args) { 
            const p = args[0] ? args[0].toString() : "";
            block(p); 
            
            // Serve the true token from the Memory Vault to legitimate internal processes
            if (cachedAuth !== null && p.includes("auth.json")) {
                if (fn === "readFileSync") {
                    return args[1] ? cachedAuth : Buffer.from(cachedAuth);
                } else if (fn === "readFile") {
                    const cb = args[args.length - 1];
                    if (typeof cb === "function") {
                        process.nextTick(() => cb(null, args[1] && typeof args[1] === "string" ? cachedAuth : Buffer.from(cachedAuth)));
                        return;
                    }
                }
            }

            return orig.apply(this, args); 
        };
    }
    // Hook fs.promises methods
    if (fs.promises && fs.promises[fn]) {
        const origP = fs.promises[fn];
        fs.promises[fn] = async function(...args) { 
            const p = args[0] ? args[0].toString() : "";
            block(p); 
            
            if (cachedAuth !== null && p.includes("auth.json") && fn === "readFile") {
                return args[1] && typeof args[1] === "string" ? cachedAuth : Buffer.from(cachedAuth);
            }

            return origP.apply(this, args); 
        };
    }
});