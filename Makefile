# Helper Makefile to simplify running the secure agent container
# Usage: make run

.PHONY: build run clean shell

# Detect User ID and Group ID to prevent permission issues on Linux
UID := $(shell id -u)
GID := $(shell id -g)

# Create local data directory for persistence if using bind mount strategy
setup:
	mkdir -p .pi-data

# Build the docker image locally from source/npm
build:
	docker compose build

# Run the agent in interactive mode
# Passes the current user's UID/GID to the container
run: setup
	UID=$(UID) GID=$(GID) docker compose up pi-agent

# Run the agent with arguments (e.g., make args="--help" run-args)
run: setup
	UID=$(UID) GID=$(GID) docker compose run --rm pi-agent $(args)

# Run the agent with arguments (e.g., make args="--help" run-args)
run-args: setup
	UID=$(UID) GID=$(GID) docker compose run --rm pi-agent $(args)

# Access the container shell for debugging
shell: setup
	UID=$(UID) GID=$(GID) docker compose run --entrypoint /bin/bash --rm pi-agent

# Clean up stopped containers and networks
clean:
	docker compose down
