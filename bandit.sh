#!/bin/bash

CONFIG_DIR="$HOME/.config/bandit"
CONFIG_FILE="$CONFIG_DIR/bandit_level.conf"
PASS_DIR="$CONFIG_DIR/passwords"
TEMPLATE="./bandit_level.conf.template"

LEVEL=""
CLI_LEVEL=""
SYNC_ONLY=false

# ---------- init ----------

init_config() {
    mkdir -p "$CONFIG_DIR" "$PASS_DIR"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cp "$TEMPLATE" "$CONFIG_FILE"
        echo "initialized bandit config at $CONFIG_FILE!"
    fi
}

# ---------- args ----------

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
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
        *)
            echo "unknown argument: $1"
            exit 1
            ;;
        esac
    done
}

# ---------- config ----------

load_config_level() {
    [[ -f "$CONFIG_FILE" ]] || return
    source "$CONFIG_FILE"
    LEVEL="${LEVEL:-}"
}

write_config_level() {
    local new_level="$1"

    if [[ -f "$CONFIG_FILE" ]]; then
        # replace existing LEVEL= line or append if missing
        if grep -q '^LEVEL=' "$CONFIG_FILE"; then
            sed -i "s/^LEVEL=.*/LEVEL=$new_level/" "$CONFIG_FILE"
        else
            echo "LEVEL=$new_level" >>"$CONFIG_FILE"
        fi
    else
        echo "LEVEL=$new_level" >"$CONFIG_FILE"
    fi
}

resolve_level() {
    if [[ -n "$CLI_LEVEL" ]]; then
        LEVEL="$CLI_LEVEL"
    fi

    if [[ -z "$LEVEL" ]]; then
        echo "no level specified and none found in config"
        echo "use --level <n> or set LEVEL in $CONFIG_FILE"
        exit 1
    fi
}

# ---------- passwords ----------

password_file() {
    echo "$PASS_DIR/level$1"
}

password_exists() {
    [[ -f "$(password_file "$1")" ]]
}

sync_passwords() {
    [[ -n "$SYNC_HOST" && -n "$SYNC_DIR" ]] || {
        echo "sync config missing"
        echo "set SYNC_HOST and SYNC_DIR in $CONFIG_FILE"
        exit 1
    }

    echo "syncing passwords to $SYNC_HOST:$SYNC_DIR"
    rsync -av "$PASS_DIR/" "$SYNC_HOST:$SYNC_DIR/"
    echo "sync complete"
}

# ---------- run ----------

run_level() {
    local user="bandit$LEVEL"
    local pass_file
    pass_file="$(password_file "$LEVEL")"

    if password_exists "$LEVEL"; then
        echo "using stored password for level $LEVEL"
        sshpass -f "$pass_file" \
            ssh "$user@bandit.labs.overthewire.org" -p 2220
    else
        echo "no stored password for level $LEVEL"
        echo "connecting manually..."
        ssh "$user@bandit.labs.overthewire.org" -p 2220
    fi
}

post_run() {
    local wrote_password=false

    read -p "did you clear level $LEVEL? (y/n): " cleared

    if [[ "$cleared" =~ ^[yY]$ ]]; then
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
                rsync -av "$PASS_DIR/" "$SYNC_HOST:$SYNC_DIR/"
                echo "passwords synced"
            fi
        fi

        read -p "continue to level $next_level? (y/n): " cont
        [[ "$cont" =~ ^[yY]$ ]] && return 0 || return 2
    else
        read -p "retry level $LEVEL? (y/n): " retry
        [[ "$retry" =~ ^[yY]$ ]] && return 1 || return 2
    fi
}

# ---------- main ----------

main() {
    init_config
    parse_args "$@"
    load_config_level

    if $SYNC_ONLY; then
        sync_passwords
        exit 0
    fi

    resolve_level

    while true; do
        run_level
        post_run
        case $? in
        0) LEVEL=$((LEVEL + 1)) ;; # next level
        1) : ;;                    # retry same level
        2) break ;;                # exit
        esac
    done
}

main "$@"
