# pi coding agent (dockerized)

Containerized environment for running the pi coding agent. It is packaged using the `@earendil-works/pi-coding-agent` npm module. Designed for local execution with strict file-system isolation, privilege drop, and persistent storage.

## 🚨 Deprecation Notice: Repository Moved

> **Important:** This repository is no longer actively maintained.

The architecture from this project has been evolved into a multi-agent ecosystem.

### Why the move?

* **Multi-Agent Support:** The new repository is completely generic, allowing you to run and orchestrate more than just a single agent.
* **Stronger Isolation:** Security layers have been upgraded to provide even stricter container-level isolation and robust environment controls.

### ➡️ Next Steps

Please migrate your setups and follow future updates over at the new repository:

👉 **[github.com/gni/agents-container](https://github.com/gni/agents-container)**


## Quick start

**1. Configuration**
```bash
cp .env.example .env
# Edit .env with your GitHub token and Git identity
```

**2. Build**
Compiles the image from source and strips OS privilege escalation binaries.
```bash
make build
```

**3. Run**
Starts the agent in interactive TUI mode.
```bash
make run
```

---

## Usage

**Passing arguments**
Use the `run-args` target to pass specific flags, commands, or one-off prompts to the agent.
```bash
# Check version
make args="--version" run-args

# Trigger Copilot authentication
make args="/login" run-args

# Execute a direct prompt
make args="'Create a snake game in python'" run-args
```

**Maintenance and debugging**
```bash
# Access the container shell (runs as user 1000)
make shell

# Stop and remove running containers/networks
make clean

# Force rebuild the image without cache
make update
```

---

## Offline mode (llama.cpp)

To run the agent completely offline using local models, configure the following files in your `.pi-data/agent/` directory:

**.pi-data/agent/models.json**
```json
{
  "providers": {
    "llama-cpp": {
      "baseUrl": "http://127.0.0.1:1337/v1",
      "api": "openai-completions",
      "apiKey": "none",
      "models": [
        {
          "id": "gemma-4-26B-A4B-it-GGUF"
        }
      ]
    }
  }
}
```

**.pi-data/agent/settings.json**
```json
{
  "defaultProvider": "llama-cpp",
  "defaultModel": "gemma-4-26B-A4B-it-GGUF",
  "autocompleteMaxVisible": 7,
  "defaultThinkingLevel": "off"
}
```

---

## 🔒 Security architecture

This container implements a layered security design to sandbox the AI agent.

### Hardcoded command guardrail
The container uses a custom wrapper script (`src/gh-guard.sh`) placed in the path to intercept calls to the GitHub CLI. It unconditionally blocks dangerous repository or identity commands:
* **Blocked:** `gh auth` (except `git-credential`), `gh repo`, `gh secret`, `gh ssh-key`, `gh gpg-key`, `gh config`.
* **Zero-trust exemption:** Allows the command `gh auth git-credential` only when it originates from a legitimate Git operation (such as push, pull, fetch, clone, ls-remote).
* **Note:** The `PARANOID_MODE` environment variable defined in `.env` and `.env.example` is currently a placeholder; this command guardrail is hardcoded and always active.

### The micro-vault (token isolation)
Your `GITHUB_TOKEN` is never exposed in the environment variables of the main agent's process:
* The token is mapped as a Docker Secret.
* The container runs as a standard user (`UID 1000`).
* The custom SetUID C binary (`src/gh-vault.c`) compiled at `/usr/local/bin/gh` is owned by root. When invoked, it uses `setuid(0)` to read the secret in `/run/secrets/gh_*`, injects the token into the environment (`GITHUB_TOKEN` and `GH_TOKEN`), drops privileges back to the node user, and executes `/usr/local/bin/gh-guard`. The main agent cannot read the secret file directly due to file system permission blocks.

### V8 application-layer firewall
A Node.js preloaded module (`src/app-firewall.js`) is forced using `NODE_OPTIONS="--require ..."` to intercept the internal `fs` module:
* It hooks standard filesystem methods and `fs.promises` methods.
* It checks all target paths for the substrings `"gh_"`, `".secrets"`, or `".env"`.
* If a path contains any of these strings, the firewall throws a `[system block]` error.
* **Note:** This is a simple string-matching blocklist. It does not perform stack trace analysis.

### User-space OS path hook (LD_PRELOAD)
A custom C library (`src/fs-vault.c`) compiled at `/usr/local/lib/fs-vault.so` is loaded globally via `/etc/ld.so.preload`:
* It hooks dynamic linker calls to file-related standard C library functions (like `open`, `fopen`, `openat`, etc.).
* It returns `EACCES` (Permission Denied) for paths containing `"auth.json"`, `/.secrets/`, or `/run/secrets/gh_`.
* **Exemptions:** Allows file access if the calling binary is `/usr/local/bin/gh` or if the command line arguments in `/proc/self/cmdline` contain the substring `"pi "` or `"/bin/pi"`.

### OS binary purge
During the Docker build phase, native privilege escalation binaries are deleted from the system:
* Removed: `su`, `mount`, `umount`, `passwd`, `chsh`, `chfn`, `chage`, `gpasswd`, `newgrp`, `login`, `nsenter`, `unshare`, `setpriv`.
* The SetUID and SetGID bits are stripped globally from all other pre-existing system binaries.

### L7 network intercept mesh (zonzon)
To prevent the agent from communicating with unauthorized endpoints or exfiltrating data, all network traffic is isolated:
* **No direct internet access:** The `pi-agent` container runs on an internal Docker bridge network (`pi_network`) that is explicitly configured with `internal: true` and has no gateway to the external internet.
* **Connection redirect:** The `connect()` system call is intercepted by the preloaded `fs-vault.so` library. Non-loopback IPv4 connection attempts are hijacked and redirected to the `zonzon_mesh` proxy container at `172.53.0.53`.
* **The DNS and L7 proxy (zonzon):** The `zonzon_mesh` container (defined in `Dockerfile.zonzon` and `docker-compose.yml`) has dual network attachments, giving it external internet access. It runs [zonzon](https://github.com/opensecurity/zonzon) to act as both the DNS server (on port 53) and an HTTP/HTTPS proxy. It filters all redirected traffic using the domain allow-list configured in `config/hosts.json`:
  * **Allowed domains:** `*.ubuntu.com`, `ubuntu.com`, `*.github.com`, `github.com`, `*.githubusercontent.com`, `pi.dev`.
  * **Default policy:** Deny (all other DNS queries and TCP connections are blocked).
