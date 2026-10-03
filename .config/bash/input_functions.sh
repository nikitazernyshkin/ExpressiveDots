# --- Модуль продвинутых функций для клавиатуры Bash ---

# 1. Умный Fish-style SUDO (Alt + S)
_bash_fish_style_sudo() {
    if [[ -n "$READLINE_LINE" ]]; then
        if [[ "$READLINE_LINE" == sudo\ * ]]; then
            return
        fi
        READLINE_LINE="sudo $READLINE_LINE"
        READLINE_POINT=$((READLINE_POINT + 5))
    else
        local last_cmd
        last_cmd=$(history 1 | sed -E 's/^[ ]*[0-9]+[ ]+//; s/^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}[ ]+//')
        if [[ -n "$last_cmd" && "$last_cmd" != sudo\ * ]]; then
            READLINE_LINE="sudo $last_cmd"
            READLINE_POINT=${#READLINE_LINE}
        fi
    fi
}

# 2. Умное копирование пути в буфер обмена Bash (Alt + C)
_copy_cwd_to_kill_ring() {
    READLINE_LINE="$PWD"
    READLINE_POINT=${#READLINE_LINE}
}
