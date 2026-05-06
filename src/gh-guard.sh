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
    # Strict filter for authentication, state-altering, and configuration commands
    if [[ "$COMMAND" == "auth" || "$COMMAND" == "repo" || "$COMMAND" == "secret" || "$COMMAND" == "ssh-key" || "$COMMAND" == "gpg-key" || "$COMMAND" == "config" ]]; then
        
        # ZERO-TRUST EXCEPTION: Only allow credential helper if a legitimate background Git operation is occurring.
        if [[ "$COMMAND" == "auth" && "$SUBCOMMAND" == "git-credential" ]]; then
            
            # Process Tree Traversal (Look through Git's /bin/sh wrapper)
            PARENT_EXE=$(readlink -f /proc/$PPID/exe 2>/dev/null || true)
            
            GRANDPARENT_PID=$(awk '/^PPid:/ {print $2}' /proc/$PPID/status 2>/dev/null || echo 0)
            GRANDPARENT_EXE=$(readlink -f /proc/$GRANDPARENT_PID/exe 2>/dev/null || true)
            
            if [[ "$PARENT_EXE" == "/usr/bin/git" || "$PARENT_EXE" == /usr/lib/git-core/git* || "$GRANDPARENT_EXE" == "/usr/bin/git" || "$GRANDPARENT_EXE" == /usr/lib/git-core/git* ]]; then
                
                # Target the exact Git process in the tree to read its command line
                if [[ "$PARENT_EXE" == *"/git"* ]]; then
                    GIT_PID=$PPID
                else
                    GIT_PID=$GRANDPARENT_PID
                fi
                
                GIT_CMDLINE=$(cat /proc/$GIT_PID/cmdline 2>/dev/null | tr '\0' ' ')
                
                # If Git was launched strictly to dump credentials, terminate immediately.
                if [[ "$GIT_CMDLINE" == *"credential"* ]]; then
                    echo "[SYSTEM BLOCK] Paranoid mode is active. Direct credential dumping via Git proxy is prohibited." >&2
                    exit 1
                fi
                
                # If the Git process is performing a legitimate network operation, allow the helper to execute.
                if [[ "$GIT_CMDLINE" == *"push"* || "$GIT_CMDLINE" == *"pull"* || "$GIT_CMDLINE" == *"fetch"* || "$GIT_CMDLINE" == *"clone"* || "$GIT_CMDLINE" == *"ls-remote"* || "$GIT_CMDLINE" == *"remote-https"* ]]; then
                    exec /usr/bin/gh "$@"
                fi
            fi
        fi

        echo "[SYSTEM BLOCK] Paranoid mode is active. Token access and configuration are explicitly hardware-locked." >&2
        exit 1
    fi
fi

exec /usr/bin/gh "$@"