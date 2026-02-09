#!/bin/bash

# Global Config
CONFIG_DIR="$HOME/.config/overthewire"
CONFIGS_DIR="$CONFIG_DIR/configs"
PASS_DIR="$CONFIG_DIR/passwords"

LOCAL_CONFIGS_DIR="./configs"

# State
GAME="bandit" # Default game
LEVEL=""
CLI_LEVEL=""
SYNC_ONLY=false
PULL_ONLY=false
VERSION="v0.2"
REMOTE_COMMAD=""

HOST=""
PORT=""
GAME_CONFIG_FILE=""
GAME_PASS_DIR=""

show_help() {
    echo "otw $VERSION"
    echo "Usage: otw [options]"
    echo
    echo "Options:"
    echo "  --game <name>     select game (bandit/b, leviathan/l, narnia/n). Default: bandit"
    echo "  --level <n>       start at a specific level"
    echo "  --sync            force sync passwords to remote server"
    echo "  --pull            pull passwords from remote server"
    echo "  --version         show version information"
    echo "  --help            show this help message"
    exit 0
}

check_dependencies() {
    local missing=false
    for cmd in sshpass rsync; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "error: $cmd is not installed."
            missing=true
        fi
    done
    if $missing; then
        echo "please install missing dependencies and try again."
        exit 1
    fi
}

init_config() {
    mkdir -p "$CONFIG_DIR" "$CONFIGS_DIR" "$PASS_DIR"

    if [[ -d "$LOCAL_CONFIGS_DIR" ]]; then
        echo "Initializing configs from $LOCAL_CONFIGS_DIR..."
        for conf in "$LOCAL_CONFIGS_DIR"/*.conf; do
            [[ -e "$conf" ]] || continue
            filename=$(basename "$conf")
            target="$CONFIGS_DIR/$filename"

            if [[ ! -f "$target" ]]; then
                cp "$conf" "$target"
                echo "Initialized $target"
            fi
        done
    else
        echo "Warning: Local configs directory not found at $LOCAL_CONFIGS_DIR"
    fi
}

set_game_config() {
    case "$GAME" in
    bandit | b)
        GAME="bandit"
        HOST="bandit.labs.overthewire.org"
        PORT="2220"
        ;;
    leviathan | l)
        GAME="leviathan"
        HOST="leviathan.labs.overthewire.org"
        PORT="2223"
        ;;
    narnia | n)
        GAME="narnia"
        HOST="narnia.labs.overthewire.org"
        PORT="2226"
        ;;
    *)
        echo "error: unknown game '$GAME'"
        exit 1
        ;;
    esac

    GAME_CONFIG_FILE="$CONFIGS_DIR/${GAME}_level.conf"
    GAME_PASS_DIR="$PASS_DIR/$GAME"
    mkdir -p "$GAME_PASS_DIR"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --game | -g)
            [[ -n "$2" ]] || {
                echo "error: --game requires an argument"
                exit 1
            }
            GAME="$2"
            shift 2
            ;;
        --level)
            [[ -n "$2" && "$2" =~ ^[0-9]+$ ]] || {
                echo "error: --level requires a number"
                exit 1
            }
            CLI_LEVEL="$2"
            shift 2
            ;;
        --sync)
            SYNC_ONLY=true
            shift
            ;;
        --pull)
            PULL_ONLY=true
            shift
            ;;
        --version)
            echo "otw $VERSION"
            exit 0
            ;;
        --help)
            show_help
            ;;
        --args)
            REMOTE_COMMAD="$2"
            shift 2
            ;;
        *)
            echo "unknown argument: $1"
            exit 1
            ;;
        esac
    done
}

load_config_level() {
    [[ -f "$GAME_CONFIG_FILE" ]] || return
    source "$GAME_CONFIG_FILE"
    LEVEL="${LEVEL:-}"
    MAX_LEVEL="${MAX_LEVEL:-}"
}

write_config_level() {
    local new_level="$1"

    if [[ -f "$GAME_CONFIG_FILE" ]]; then
        if grep -q '^LEVEL=' "$GAME_CONFIG_FILE"; then
            sed -i "s/^LEVEL=.*/LEVEL=$new_level/" "$GAME_CONFIG_FILE"
        else
            echo "LEVEL=$new_level" >>"$GAME_CONFIG_FILE"
        fi
    else
        echo "LEVEL=$new_level" >"$GAME_CONFIG_FILE"
    fi
}

resolve_level() {
    if [[ -n "$CLI_LEVEL" ]]; then
        LEVEL="$CLI_LEVEL"
    fi

    if [[ -z "$LEVEL" ]]; then
        echo "no level specified and none found in config for $GAME"
        echo "use --level <n> or set LEVEL in $GAME_CONFIG_FILE"
        exit 1
    fi
}

password_file() {
    echo "$GAME_PASS_DIR/level$1"
}

password_exists() {
    [[ -f "$(password_file "$1")" ]]
}

get_sync_config() {
    local game="$1"
    local conf="$CONFIGS_DIR/${game}_level.conf"

    # Defaults
    local s_host=""
    local s_dir=""

    if [[ -f "$conf" ]]; then
        s_host=$(grep "^SYNC_HOST=" "$conf" | cut -d'=' -f2 | tr -d '"')
        s_dir=$(grep "^SYNC_DIR=" "$conf" | cut -d'=' -f2 | tr -d '"')
    fi

    echo "$s_host|$s_dir"
}

sync_current_game() {
    [[ -n "$SYNC_HOST" && -n "$SYNC_DIR" ]] || {
        echo "sync config missing for $GAME"
        echo "set SYNC_HOST and SYNC_DIR in $GAME_CONFIG_FILE"
        exit 1
    }

    echo "syncing $GAME passwords to $SYNC_HOST:$SYNC_DIR/"
    rsync -av "$GAME_PASS_DIR/" "$SYNC_HOST:$SYNC_DIR/"
    echo "sync complete"
}

pull_current_game() {
    [[ -n "$SYNC_HOST" && -n "$SYNC_DIR" ]] || {
        echo "sync config missing for $GAME"
        echo "set SYNC_HOST and SYNC_DIR in $GAME_CONFIG_FILE"
        exit 1
    }

    echo "pulling $GAME passwords from $SYNC_HOST:$SYNC_DIR/"
    mkdir -p "$GAME_PASS_DIR"
    rsync -av "$SYNC_HOST:$SYNC_DIR/" "$GAME_PASS_DIR/"
    echo "pull complete"
}

sync_all() {
    echo "Syncing ALL games..."
    for g in bandit leviathan narnia; do
        # Read config without loading into global state
        local conf_data
        conf_data=$(get_sync_config "$g")
        local s_host="${conf_data%|*}"
        local s_dir="${conf_data#*|}"

        if [[ -n "$s_host" && -n "$s_dir" ]]; then
            echo "[$g] syncing to $s_host..."
            local g_pass_dir="$PASS_DIR/$g"
            rsync -av "$g_pass_dir/" "$s_host:$s_dir/"
        else
            echo "[$g] skipped: sync config missing"
        fi
    done
    echo "Sync All Complete."
}

pull_all() {
    echo "Pulling ALL games..."
    for g in bandit leviathan; do
        local conf_data
        conf_data=$(get_sync_config "$g")
        local s_host="${conf_data%|*}"
        local s_dir="${conf_data#*|}"

        if [[ -n "$s_host" && -n "$s_dir" ]]; then
            echo "[$g] pulling from $s_host..."
            local g_pass_dir="$PASS_DIR/$g"
            mkdir -p "$g_pass_dir"
            rsync -av "$s_host:$s_dir/" "$g_pass_dir/"
        else
            echo "[$g] skipped: sync config missing"
        fi
    done
    echo "Pull All Complete."
}

run_level() {
    local user="$GAME$LEVEL"
    local pass_file
    pass_file="$(password_file "$LEVEL")"

    if password_exists "$LEVEL"; then
        echo "using stored password for $GAME level $LEVEL"
        sshpass -f "$pass_file" \
            ssh "$user@$HOST" -p "$PORT" "$REMOTE_COMMAD"
    else
        echo "no stored password for $GAME level $LEVEL"
        echo "connecting manually..."
        ssh "$user@$HOST" -p "$PORT" "$REMOTE_COMMAD"
    fi
}

post_run() {
    local wrote_password=false

    read -p "did you clear level $LEVEL? (y/n): " cleared

    if [[ "$cleared" =~ ^[yY]$ ]]; then
        REMOTE_COMMAD=""
        if [[ -n "$MAX_LEVEL" && "$LEVEL" -ge "$MAX_LEVEL" ]]; then
            echo "yay game cleared!! $GAME (level $MAX_LEVEL)!"
            return 2
        fi

        local next_level=$((LEVEL + 1))
        local next_pass_file
        next_pass_file="$(password_file "$next_level")"

        if [[ -f "$next_pass_file" ]]; then
            echo "password for level $next_level already exists"
        else
            read -p "store password for level $next_level? (y/n): " store
            if [[ "$store" =~ ^[yY]$ ]]; then
                read -s -p "enter password for level $next_level: " pw
                echo
                echo "$pw" >"$next_pass_file"
                chmod 600 "$next_pass_file"
                echo "password for level $next_level stored"
                wrote_password=true
            fi
        fi

        if [[ -z "$CLI_LEVEL" ]]; then
            write_config_level "$next_level"
            echo "default level updated to $next_level"
        fi

        if $wrote_password && [[ -n "$SYNC_HOST" && -n "$SYNC_DIR" ]]; then
            read -p "sync passwords to $SYNC_HOST? (y/n): " sync
            if [[ "$sync" =~ ^[yY]$ ]]; then
                sync_current_game
            fi
        fi

        read -p "continue to level $next_level? (y/n): " cont
        [[ "$cont" =~ ^[yY]$ ]] && return 0 || return 2
    else
        read -p "retry level $LEVEL? (y/n): " retry
        [[ "$retry" =~ ^[yY]$ ]] && return 1 || return 2
    fi
}

main() {
    check_dependencies
    init_config
    parse_args "$@"
    set_game_config
    load_config_level

    if $SYNC_ONLY; then
        sync_all
        exit 0
    fi

    if $PULL_ONLY; then
        pull_all
        exit 0
    fi

    resolve_level

    while true; do
        run_level
        post_run
        case $? in
        0) LEVEL=$((LEVEL + 1)) ;;
        1) : ;;
        2) break ;;
        esac
    done
}

main "$@"
