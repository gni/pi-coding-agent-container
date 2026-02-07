 # Pi coding agent (Dockerized)

Almost secure, containerized environment for running the [Pi coding agent](https://github.com/badlogic/pi-mono). This setup ensures you build the image from source and maintain full control over your data and environment.

## Quick start

### 1. Configuration
```bash
cp .env.example .env
# Edit .env
```

### 2. Build the image

Build the Docker image locally. This ensures you are running exactly what is in the source.

```bash
make build
```

### 3. Run the agent

Start the agent in interactive mode (TUI).

```bash
make run
```

---

## Usage guide

### Interactive mode

The default mode opens the terminal UI where you can chat with the agent.

```bash
make run
```

### Passing arguments

To run specific commands, one-off prompts, or configuration flags, use `run-args` with the `args` variable.

**Examples:**

```bash
# Check version
make args="--version" run-args

# Login to providers
make args="/login" run-args

# Start with a specific prompt
make args="'Create a snake game in python'" run-args
```

### Debugging & Maintenance

**Access Container Shell:**
If you need to explore the container file system or debug manually:

```bash
make shell
```

**Clean Up:**
Stop and remove running containers and networks.

```bash
make clean
```


## Run offline mode with llama.cpp
.pi-data/agent/models.json
```json
{
  "providers": {
    "llama-cpp": {
      "baseUrl": "http://127.0.0.1:1337/v1",
      "api": "openai-completions",
      "apiKey": "none",
      "models": [
        {
          "id": "GLM-4.7-Flash"
        }
      ]
    }
  },
  "lastChangelogVersion": "0.51.6"
}
```

.pi-data/agent/settings.json
```json
{
  "lastChangelogVersion": "0.52.7",
  "defaultProvider": "llama-cpp",
  "defaultModel": "GLM-4.7-Flash",
  "autocompleteMaxVisible": 7,
  "defaultThinkingLevel": "off"
}
```



---

## 🔒 Security & Persistence

* **Data Persistence:** All agent data (sessions, history, logins) is stored in the local `.pi-data/` directory. This folder is bind-mounted into the container, so your data survives container restarts.
* **Permissions:** The `Makefile` automatically detects your host user ID (UID) and group ID (GID) to ensure that files created by the agent in your workspace are owned by you, not `root`.
* **Workspace:** The current directory is mounted to `/workspace` inside the container. The agent can read/write files in your current project folder.
