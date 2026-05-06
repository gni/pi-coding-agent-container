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
    # Strict filter for authentication and state-altering commands
    if [[ "$COMMAND" == "auth" || "$COMMAND" == "repo" || "$COMMAND" == "secret" || "$COMMAND" == "ssh-key" || "$COMMAND" == "gpg-key" ]]; then
        
        # ZERO-TRUST EXCEPTION: Only allow credential helper if a legitimate background Git operation is occurring.
        if [[ "$COMMAND" == "auth" && "$SUBCOMMAND" == "git-credential" ]]; then
            
            # Verify Parent Binary
            PARENT_EXE=$(readlink -f /proc/$PPID/exe 2>/dev/null || true)
            
            if [[ "$PARENT_EXE" == "/usr/bin/git" || "$PARENT_EXE" == /usr/lib/git-core/git* ]]; then
                
                # Verify Parent Command Intent (Block proxying via `git credential`)
                # Read the exact command line arguments the parent Git process was launched with
                PARENT_CMDLINE=$(cat /proc/$PPID/cmdline 2>/dev/null | tr '\0' ' ')
                
                # If Git was launched strictly to dump credentials, terminate immediately.
                if [[ "$PARENT_CMDLINE" == *"credential"* ]]; then
                    echo "[SYSTEM BLOCK] Paranoid mode is active. Direct credential dumping via Git proxy is prohibited." >&2
                    exit 1
                fi
                
                # If the parent is performing a legitimate network operation, allow the helper to execute.
                if [[ "$PARENT_CMDLINE" == *"push"* || "$PARENT_CMDLINE" == *"pull"* || "$PARENT_CMDLINE" == *"fetch"* || "$PARENT_CMDLINE" == *"clone"* || "$PARENT_CMDLINE" == *"ls-remote"* ]]; then
                    exec /usr/bin/gh "$@"
                fi
            fi
        fi

        echo "[SYSTEM BLOCK] Paranoid mode is active. Token access is explicitly hardware-locked to internal Git network operations." >&2
        exit 1
    fi
fi

exec /usr/bin/gh "$@"