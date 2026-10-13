#!/usr/bin/env bash

# Experimental Command Blocks v0.14.
# Run in a temporary interactive Bash session.

HISTFILE=/dev/null bash --noprofile --rcfile /dev/fd/3 -i 3<<'CBRC'
# Command Blocks TEST v0.14

declare -A CB_MARKER=()

CB_STARTED=
CB_FIRST_PROMPT=1
CB_USER=
CB_REST=
CB_GAP_LINES=0
CB_PASTING=0
CB_STOP_MODE=0
CB_BATCH_TEXT=

shopt -s checkwinsize promptvars
bind 'set enable-bracketed-paste off'

_cb_paste_begin() {
    CB_PASTING=1
}

_cb_paste_end() {
    CB_PASTING=0
}

bind -x '"\e[200~":_cb_paste_begin'
bind -x '"\e[201~":_cb_paste_end'

cbgap() {
    local lines="${1:-5}"

    if [[ ! "$lines" =~ ^([1-9]|1[0-5])$ ]]; then
        printf 'Usage: cbgap [1-15]\n' >&2
        return 2
    fi

    CB_GAP_LINES="$lines"
}

cb() {
    if [[ "$1" != stop ]]; then
        printf 'Usage: cb stop on|off|status\n'
        return 2
    fi

    case "${2:-status}" in
        on)
            CB_STOP_MODE=1
            CB_PASTING=0

            bind '"\e[200~": bracketed-paste-begin'
            bind 'set enable-bracketed-paste on'

            bind -x '"\C-x\C-b":_cb_prepare_batch'
            bind '"\C-m": "\C-x\C-b\C-j"'

            printf '\033[93mSTOP MODE ON\033[0m\n'
            printf 'Multiline paste: review, then press Enter.\n'
            printf 'Batch runs in a separate fail-fast Bash.\n'
            ;;
        off)
            CB_STOP_MODE=0
            CB_PASTING=0

            bind '"\C-m": accept-line'
            bind 'set enable-bracketed-paste off'
            bind -x '"\e[200~":_cb_paste_begin'
            bind -x '"\e[201~":_cb_paste_end'

            printf '\033[92mSTOP MODE OFF\033[0m\n'
            printf 'Normal sequential paste behavior restored.\n'
            ;;
        status)
            if (( CB_STOP_MODE )); then
                printf 'STOP MODE: ON\n'
            else
                printf 'STOP MODE: OFF\n'
            fi
            ;;
        *)
            printf 'Usage: cb stop on|off|status\n'
            return 2
            ;;
    esac
}

_cb_prepare_batch() {
    (( CB_STOP_MODE )) || return 0

    if [[ "$READLINE_LINE" != *$'\n'* ]]; then
        return 0
    fi

    CB_BATCH_TEXT="$READLINE_LINE"
    READLINE_LINE='_cb_run_batch'
    READLINE_POINT=${#READLINE_LINE}
}

_cb_run_batch() {
    local script="$CB_BATCH_TEXT"
    local rc

    CB_BATCH_TEXT=

    printf '\033[90m[STOP MODE] Executing pasted batch:\033[0m\n'
    printf '%s\n' "$script"
    printf '\033[95m────────────────────────────────────────\033[0m\n'

    bash --noprofile --norc -e -o pipefail \
        -c "$script" </dev/tty

    rc=$?

    if (( rc != 0 )); then
        printf '\033[91mBATCH STOPPED\033[0m'
        printf ' · exit %d · remaining commands skipped\n' "$rc"
    else
        printf '\033[92mBATCH COMPLETED\033[0m\n'
    fi

    return "$rc"
}

_cb_update_header() {
    local width="${COLUMNS:-80}"
    local max_chars
    local host="${HOSTNAME%%.*}"
    local dir="$PWD"
    local now
    local branch=''
    local git_part=''
    local prefix suffix room keep

    [[ "$width" =~ ^[0-9]+$ ]] || width=80
    (( width < 30 )) && width=30

    max_chars=$(( width - 9 ))

    if [[ "$dir" == "$HOME" ]]; then
        dir='~'
    elif [[ "$dir" == "$HOME/"* ]]; then
        dir="~/${dir#"$HOME"/}"
    fi

    dir=${dir//$'\n'/ }
    dir=${dir//$'\r'/ }
    dir=${dir//$'\t'/ }

    if command -v git >/dev/null 2>&1; then
        if [[ $(git -C "$PWD" rev-parse --is-inside-work-tree 2>/dev/null) == true ]]; then
            branch=$(git -C "$PWD" symbolic-ref --quiet --short HEAD 2>/dev/null)

            if [[ -z "$branch" ]]; then
                branch=$(git -C "$PWD" rev-parse --short HEAD 2>/dev/null)
            fi

            [[ -n "$branch" ]] && git_part=" · ${branch}"
        fi
    fi

    printf -v now '%(%H:%M:%S)T' -1

    CB_USER="${USER:-root}@${host}"

    prefix="${CB_USER} · "
    suffix="${git_part} · ${now}"

    room=$(( max_chars - ${#prefix} - ${#suffix} ))

    if (( room < 8 )); then
        suffix=" · ${now}"
        room=$(( max_chars - ${#prefix} - ${#suffix} ))
    fi

    if (( room > 1 && ${#dir} > room )); then
        keep=$(( room - 1 ))
        dir="…${dir: -keep}"
    fi

    CB_REST=" · ${dir}${suffix}"

    if (( ${#CB_USER} + ${#CB_REST} > max_chars )); then
        local available=$(( max_chars - ${#CB_USER} ))

        if (( available > 1 )); then
            CB_REST="${CB_REST:0:available-1}…"
        else
            CB_REST=''
        fi
    fi
}

_cb_finish() {
    local rc=$?

    if (( CB_FIRST_PROMPT )); then
        CB_FIRST_PROMPT=0
        _cb_update_header
        return 0
    fi

    if [[ -z "$CB_STARTED" ]]; then
        if (( CB_PASTING )); then
            printf '\033[2A\r\033[2K\033[1B\r\033[2K\033[1A\r'
        else
            printf '\033[2A\r\033[2K\033[1B\r\033[2K\033[1A\r\n'
        fi

        _cb_update_header
        return 0
    fi

    local ended="$EPOCHREALTIME"
    local elapsed='n/a'
    local start_us end_us diff_us
    local i

    if [[ "$CB_STARTED" =~ ^[0-9]+\.[0-9]{6}$ &&
          "$ended" =~ ^[0-9]+\.[0-9]{6}$ ]]; then

        start_us="${CB_STARTED/.}"
        end_us="${ended/.}"

        diff_us=$(( 10#$end_us - 10#$start_us ))
        (( diff_us < 0 )) && diff_us=0

        if (( diff_us >= 60000000 )); then
            printf -v elapsed '%dm %02d.%03ds' \
                "$(( diff_us / 60000000 ))" \
                "$(( (diff_us / 1000000) % 60 ))" \
                "$(( (diff_us % 1000000) / 1000 ))"
        else
            printf -v elapsed '%d.%03ds' \
                "$(( diff_us / 1000000 ))" \
                "$(( (diff_us % 1000000) / 1000 ))"
        fi
    fi

    CB_STARTED=

    if (( rc == 0 )); then
        printf '\033[95m└─ \033[0m\033[1;97;42m ✓ \033[0m %d · %s\n\n' \
            "$rc" "$elapsed"
    else
        printf '\033[95m└─ \033[0m\033[1;97;41m ✗ \033[0m %d · %s\n\n' \
            "$rc" "$elapsed"
    fi

    if (( CB_GAP_LINES > 0 )); then
        for (( i=0; i<CB_GAP_LINES; i++ )); do
            printf '\n'
        done
        CB_GAP_LINES=0
    fi

    _cb_update_header
    return 0
}

PROMPT_COMMAND=_cb_finish

PS0='${CB_MARKER[${CB_STARTED:=$EPOCHREALTIME}]}'$'\033[?2004l\033[95m├────────────────────────────────────────\033[0m\n'

PS1='\[\e[?2004h\]\[\e[95m\]┌─  ${CB_USER}\[\e[0m\]${CB_REST}\n\[\e[95m\]│\[\e[0m\] ❯ \[\eD\eD\e[2A\]'

PS2='\[\e[90m\]│ … \[\e[0m\]'

trap 'printf "\033[?2004l"' EXIT

printf '\n\033[95mCommand Blocks TEST v0.14 activated\033[0m\n'
printf 'Accent: username + frame only.\n'
printf 'Path, Git branch and time: neutral text.\n'
printf 'Status badges: enlarged.\n'
printf 'Stop Mode: OFF by default.\n'
printf 'No configuration files changed.\n\n'
CBRC
