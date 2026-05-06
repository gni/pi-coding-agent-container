#!/usr/bin/env bash
set -e

COMMAND=""
SUBCOMMAND=""

# Secure Parser: Ignore flags (starting with -) to find the actual commands
for arg in "$@"; do
    if [[ "$arg" != -* ]]; then
        if [ -z "$COMMAND" ]; then
            COMMAND="$arg"
        elif [ -z "$SUBCOMMAND" ]; then
            SUBCOMMAND="$arg"
            break
        fi
    fi
done

# Normalize to lowercase to prevent 'Auth' bypass
COMMAND="${COMMAND,,}"
SUBCOMMAND="${SUBCOMMAND,,}"

if [ "${PARANOID_MODE}" = "true" ]; then
    # Whitelist the exact command Git uses internally to get the token from memory
    if [[ "$COMMAND" == "auth" && "$SUBCOMMAND" == "git-credential" ]]; then
        exec /usr/bin/gh "$@"
    fi

    # Block all manual or interactive state-altering commands
    if [[ "$COMMAND" == "auth" || "$COMMAND" == "repo" || "$COMMAND" == "secret" || "$COMMAND" == "ssh-key" || "$COMMAND" == "gpg-key" ]]; then
        echo "[SYSTEM BLOCK] Paranoid mode is active. The agent is not authorized to execute interactive gh commands." >&2
        exit 1
    fi
fi

exec /usr/bin/gh "$@"