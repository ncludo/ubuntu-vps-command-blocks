#!/usr/bin/env bash

# Experimental Command Blocks v0.17.0-dev.
# Run in a temporary interactive Bash session.

CB_BORDER_FILTER_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/cb-border-filter.py"
if [[ ! -f "$CB_BORDER_FILTER_PATH" ]] || ! command -v python3 >/dev/null 2>&1; then
    printf 'Command Blocks: border helper/python3 missing.\n' >&2
    exit 2
fi
HISTFILE=/dev/null CB_BORDER_FILTER_PATH="$CB_BORDER_FILTER_PATH" bash --noprofile --rcfile /dev/fd/3 -i 3<<'CBRC'
# Command Blocks v0.17.0-dev

declare -A CB_MARKER=()

CB_STARTED=
CB_FIRST_PROMPT=1
CB_USER=
CB_REST=
CB_GAP_LINES=0
CB_PASTING=0
CB_STOP_MODE=0
CB_BATCH_MODE=separate
CB_BATCH_TEXT=
CB_BATCH_READY=0
CB_BATCH_ACTIVE=0
CB_BATCH_TRACE=0
CB_STEP_SCRIPT=
CB_BORDER_MODE=0
CB_BORDER_ACTIVE=0
CB_BORDER_PREPARE=
CB_BORDER_INITIAL_FUNCTRACE=0
[[ $- == *T* ]] && CB_BORDER_INITIAL_FUNCTRACE=1

shopt -s checkwinsize promptvars
bind 'set enable-bracketed-paste off'

_cb_border_begin ()
{
    (( CB_BORDER_MODE )) || return 0
    (( ! CB_BORDER_ACTIVE )) || return 0
    exec {CB_BORDER_OUT_FD}>&1 {CB_BORDER_ERR_FD}>&2
    exec > >(python3 -u "$CB_BORDER_FILTER_PATH") 2>&1
    CB_BORDER_PID=$!
    CB_BORDER_ACTIVE=1
    if (( BASH_SUBSHELL > 0 )); then
        trap '_cb_border_end' EXIT
    fi
}
_cb_border_end ()
{
    (( CB_BORDER_ACTIVE )) || return 0
    exec 1>&"$CB_BORDER_OUT_FD" 2>&"$CB_BORDER_ERR_FD"
    # Bound draining if a background job retains the output pipe.
    ( sleep 4; kill "$CB_BORDER_PID" 2>/dev/null || : ) &
    local guard=$!
    wait "$CB_BORDER_PID" 2>/dev/null || :
    kill "$guard" 2>/dev/null || :
    wait "$guard" 2>/dev/null || :
    exec {CB_BORDER_OUT_FD}>&- {CB_BORDER_ERR_FD}>&-
    CB_BORDER_ACTIVE=0
    return 0
}
_cb_border_debug ()
{
    local frame

    [[ "$BASH_COMMAND" == _cb_finish ]] && return 0

    for frame in "${FUNCNAME[@]:1}"; do
        case "$frame" in
            _cb_*|cb) return 0 ;;
        esac
    done

    if [[ "${CB_BORDER_PREPARE:-}" == 1 ]] &&
       (( CB_BORDER_MODE && ! CB_BORDER_ACTIVE )) &&
       [[ -t 1 ]]; then
        _cb_border_begin
    fi
    return 0
}
_cb_paste_begin ()
{
    CB_PASTING=1
}
_cb_paste_end ()
{
    CB_PASTING=0
}
cbgap ()
{
    local lines="${1:-5}";
    if [[ ! "$lines" =~ ^([1-9]|1[0-5])$ ]]; then
        printf 'Usage: cbgap [1-15]\n' 1>&2;
        return 2;
    fi;
    CB_GAP_LINES="$lines"
}
_cb_sync_bindings ()
{
    CB_PASTING=0;
    if [[ "$CB_BATCH_MODE" == grouped ]] || (( CB_STOP_MODE )); then
        bind '"\e[200~": bracketed-paste-begin';
        bind 'set enable-bracketed-paste on';
        bind -x '"\C-x\C-b":_cb_prepare_batch';
        bind '"\C-m": "\C-x\C-b\C-j"';
    else
        bind '"\C-m": accept-line';
        bind 'set enable-bracketed-paste off';
        bind -x '"\e[200~":_cb_paste_begin';
        bind -x '"\e[201~":_cb_paste_end';
    fi
}
cb ()
{
    case "${1:-}" in
        batch)
            case "${2:-status}" in
                separate | grouped)
                    CB_BATCH_MODE="$2";
                    _cb_sync_bindings;
                    printf 'BATCH MODE: %s\n' "${CB_BATCH_MODE^^}"
                ;;
                status)
                    printf 'BATCH MODE: %s\n' "${CB_BATCH_MODE^^}"
                ;;
                *)
                    printf 'Usage: cb batch separate|grouped|status\n' 1>&2;
                    return 2
                ;;
            esac
        ;;
        stop)
            case "${2:-status}" in
                on)
                    CB_STOP_MODE=1;
                    _cb_sync_bindings;
                    printf '\033[93mSTOP MODE ON\033[0m\n'
                ;;
                off)
                    CB_STOP_MODE=0;
                    _cb_sync_bindings;
                    printf '\033[92mSTOP MODE OFF\033[0m\n'
                ;;
                status)
                    if (( CB_STOP_MODE )); then
                        printf 'STOP MODE: ON\n';
                    else
                        printf 'STOP MODE: OFF\n';
                    fi
                ;;
                *)
                    printf 'Usage: cb stop on|off|status\n' 1>&2;
                    return 2
                ;;
            esac
        ;;
        border)
            case "${2:-status}" in
                on)
                    CB_BORDER_MODE=1;
                    set -T;
                    printf 'OUTPUT BORDER: ON (experimental; selection may copy borders)\n'
                ;;
                off)
                    CB_BORDER_MODE=0;
                    (( CB_BORDER_INITIAL_FUNCTRACE )) || set +T;
                    printf 'OUTPUT BORDER: OFF\n'
                ;;
                status)
                    if (( CB_BORDER_MODE )); then
                        printf 'OUTPUT BORDER: ON (experimental)\n';
                    else
                        printf 'OUTPUT BORDER: OFF\n';
                    fi
                ;;
                *)
                    printf 'Usage: cb border on|off|status\n' >&2;
                    return 2
                ;;
            esac
        ;;
        status)
            cb batch status;
            cb stop status;
            cb border status
        ;;
        *)
            printf 'Usage: cb batch separate|grouped|status | cb stop on|off|status | cb border on|off|status | cb status\n' 1>&2;
            return 2
        ;;
    esac
}
_cb_prepare_batch ()
{
    if [[ "$READLINE_LINE" != *'
'* ]]; then
        return 0;
    fi;
    CB_BATCH_TEXT="$READLINE_LINE";
    CB_BATCH_READY=1;
    READLINE_LINE=;
    READLINE_POINT=0
}
_cb_clear_readline_prompt ()
{
    printf '\033[2A\r\033[2K\033[1B\r\033[2K\033[1A\r'
}
_cb_print_batch_input ()
{
    local script="$1" line first=1;
    _cb_clear_readline_prompt;
    printf '\033[95m┌─  %s\033[0m%s\n' "$CB_USER" "$CB_REST";
    while IFS= read -r line || [[ -n "$line" ]]; do
        if (( first )); then
            printf '\033[95m│\033[0m ❯ %s\n' "$line";
            first=0;
        else
            printf '\033[95m│\033[0m   %s\n' "$line";
        fi;
    done < <(printf '%s' "$script");
    printf '\033[95m├────────────────────────────────────────\033[0m\n'
}
_cb_update_header ()
{
    local width="${COLUMNS:-80}" max_chars;
    local host="${HOSTNAME%%.*}" dir="$PWD" now;
    local branch='' git_part='' prefix suffix room keep;
    [[ "$width" =~ ^[0-9]+$ ]] || width=80;
    (( width < 30 )) && width=30;
    max_chars=$(( width - 9 ));
    if [[ "$dir" == "$HOME" ]]; then
        dir='~';
    else
        if [[ "$dir" == "$HOME/"* ]]; then
            dir="~/${dir#"$HOME"/}";
        fi;
    fi;
    dir=${dir//'
'/ };
    dir=${dir//'
'/ };
    dir=${dir//'	'/ };
    if command -v git > /dev/null 2>&1; then
        if [[ $(git -C "$PWD" rev-parse --is-inside-work-tree 2> /dev/null) == true ]]; then
            branch=$(git -C "$PWD" symbolic-ref --quiet --short HEAD 2> /dev/null);
            if [[ -z "$branch" ]]; then
                branch=$(git -C "$PWD" rev-parse --short HEAD 2> /dev/null);
            fi;
            [[ -n "$branch" ]] && git_part=" · ${branch}";
        fi;
    fi;
    printf -v now '%(%H:%M:%S)T' -1;
    CB_USER="${USER:-root}@${host}";
    prefix="${CB_USER} · ";
    suffix="${git_part} · ${now}";
    room=$(( max_chars - ${#prefix} - ${#suffix} ));
    if (( room < 8 )); then
        suffix=" · ${now}";
        room=$(( max_chars - ${#prefix} - ${#suffix} ));
    fi;
    if (( room > 1 && ${#dir} > room )); then
        keep=$(( room - 1 ));
        dir="…${dir: -keep}";
    fi;
    CB_REST=" · ${dir}${suffix}";
    if (( ${#CB_USER} + ${#CB_REST} > max_chars )); then
        local available=$(( max_chars - ${#CB_USER} ));
        if (( available > 1 )); then
            CB_REST="${CB_REST:0:available-1}…";
        else
            CB_REST='';
        fi;
    fi
}
_cb_print_status ()
{
    local rc="$1" started="$2" ended="$EPOCHREALTIME";
    local elapsed='n/a' start_us end_us diff_us;
    if [[ "$started" =~ ^[0-9]+\.[0-9]{6}$ && "$ended" =~ ^[0-9]+\.[0-9]{6}$ ]]; then
        start_us="${started/.}";
        end_us="${ended/.}";
        diff_us=$(( 10#$end_us - 10#$start_us ));
        (( diff_us < 0 )) && diff_us=0;
        if (( diff_us >= 60000000 )); then
            printf -v elapsed '%dm %02d.%03ds' "$(( diff_us / 60000000 ))" "$(( (diff_us / 1000000) % 60 ))" "$(( (diff_us % 1000000) / 1000 ))";
        else
            printf -v elapsed '%d.%03ds' "$(( diff_us / 1000000 ))" "$(( (diff_us % 1000000) / 1000 ))";
        fi;
    fi;
    if (( rc == 0 )); then
        printf '\033[95m└─ \033[0m\033[1;97;42m ✓ \033[0m %d · %s\n\n' "$rc" "$elapsed";
    else
        printf '\033[95m└─ \033[0m\033[1;97;41m ✗ \033[0m %d · %s\n\n' "$rc" "$elapsed";
    fi
}
_cb_build_steps ()
{
    local script="$1" line chunk='' diagnostic quoted;
    local slashes rest;
    local prelude;
    prelude=$(cat <<'TRACE'
CB_STEP_ACTIVE=0
CB_STEP_STARTED=

_cb_step_open() {
    local source="$1" line first=1
    _cb_update_header

    printf '\033[95m┌─  %s\033[0m%s\n' "$CB_USER" "$CB_REST"

    while IFS= read -r line || [[ -n "$line" ]]; do
        if (( first )); then
            printf '\033[95m│\033[0m ❯ %s\n' "$line"
            first=0
        else
            printf '\033[95m│\033[0m   %s\n' "$line"
        fi
    done < <(printf '%s' "$source")

    printf '\033[95m├────────────────────────────────────────\033[0m\n'
    CB_STEP_STARTED="$EPOCHREALTIME"
    CB_STEP_ACTIVE=1
    _cb_border_begin
}

_cb_step_close() {
    local rc="$1"
    _cb_border_end
    CB_STEP_ACTIVE=0
    _cb_print_status "$rc" "$CB_STEP_STARTED"
    return 0
}

_cb_step_on_exit() {
    local rc="$1"
    trap - EXIT
    _cb_border_end

    if (( CB_STEP_ACTIVE )); then
        if (( rc == 130 )); then
            printf '\n'
        fi
        _cb_step_close "$rc"
    fi
}

trap 'exit 130' INT
trap '_cb_step_on_exit "$?"' EXIT
TRACE
);
    CB_STEP_SCRIPT="$(declare -f _cb_update_header)"'
';
    CB_STEP_SCRIPT+="$(declare -f _cb_print_status)"'
';
    CB_STEP_SCRIPT+="$(declare -f _cb_border_begin)"$'\n';
    CB_STEP_SCRIPT+="$(declare -f _cb_border_end)"$'\n';
    CB_STEP_SCRIPT+="CB_BORDER_MODE=$CB_BORDER_MODE"$'\n';
    CB_STEP_SCRIPT+="CB_BORDER_ACTIVE=0"$'\n';
    CB_STEP_SCRIPT+="$prelude"'
';
    while IFS= read -r line || [[ -n "$line" ]]; do
        chunk+="$line"'
';
        rest="$line";
        slashes=0;
        while [[ "$rest" == *\\ ]]; do
            rest="${rest%\\}";
            (( slashes += 1 ));
        done;
        (( slashes % 2 == 1 )) && continue;
        if diagnostic=$(bash --noprofile --norc -n -c "$chunk" 2>&1) && [[ "$diagnostic" != *'here-document at line'* ]]; then
            if [[ -n "${chunk//[[:space:]]/}" ]]; then
                printf -v quoted '%q' "$chunk";
                CB_STEP_SCRIPT+="_cb_step_open ${quoted}"'
';
                CB_STEP_SCRIPT+="$chunk";
                CB_STEP_SCRIPT+='_cb_step_close "$?"''
';
            fi;
            chunk='';
        fi;
    done < <(printf '%s\n' "$script");
    if [[ -n "${chunk//[[:space:]]/}" ]]; then
        printf 'BATCH SYNTAX ERROR: incomplete command\n' 1>&2;
        return 2;
    fi;
    bash --noprofile --norc -n -c "$CB_STEP_SCRIPT" || return 2
}
_cb_run_batch ()
{
    local script="$CB_BATCH_TEXT" rc;
    local child_prelude='cb() { printf "cb stop/batch: run separately, outside a batch.\n" >&2; return 2; }
';
    CB_BATCH_TEXT=;
    CB_BATCH_READY=0;
    CB_BATCH_ACTIVE=1;
    CB_BATCH_TRACE=0;
    printf '\033[?2004l';
    if [[ "$CB_BATCH_MODE" == grouped ]]; then
        CB_STARTED="$EPOCHREALTIME";
        _cb_print_batch_input "$script";
        _cb_border_begin;
        if (( CB_STOP_MODE )); then
            bash --noprofile --norc -e -o pipefail -c "${child_prelude}${script}" < /dev/tty;
        else
            bash --noprofile --norc -c "${child_prelude}${script}" < /dev/tty;
        fi;
        rc=$?;
        _cb_border_end;
    else
        CB_BATCH_TRACE=1;
        CB_STARTED=;
        _cb_clear_readline_prompt;
        if _cb_build_steps "$script"; then
            bash --noprofile --norc -e -o pipefail -c "${child_prelude}${CB_STEP_SCRIPT}" < /dev/tty;
            rc=$?;
        else
            rc=2;
        fi;
    fi;
    CB_BATCH_ACTIVE=0;
    CB_BATCH_TRACE=0;
    _cb_border_end;
    if (( CB_BORDER_MODE )); then
        printf '\033[95m│\033[0m '
    fi;
    if (( rc == 130 )); then
        printf '\033[91mBATCH INTERRUPTED\033[0m · exit 130\n';
    else
        if (( rc != 0 )); then
            if (( CB_STOP_MODE )); then
                printf '\033[91mBATCH STOPPED\033[0m · exit %d · remaining commands skipped\n' "$rc";
            else
                printf '\033[91mBATCH FINISHED\033[0m · exit %d\n' "$rc";
            fi;
        else
            printf '\033[92mBATCH COMPLETED\033[0m\n';
        fi;
    fi;
    return "$rc"
}
_cb_finish ()
{
    local rc=$?;
    _cb_border_end;
    CB_BORDER_PREPARE=;
    if (( CB_BATCH_ACTIVE )); then
        CB_BATCH_ACTIVE=0;
        CB_BATCH_READY=0;
        CB_BATCH_TEXT=;
        if (( CB_BORDER_MODE )); then
            printf '\033[95m│\033[0m '
        fi;
        if (( rc == 130 )); then
            printf '\033[91mBATCH INTERRUPTED\033[0m · exit 130\n';
        else
            printf '\033[91mBATCH INTERRUPTED\033[0m · exit %d\n' "$rc";
        fi;
        if (( CB_BATCH_TRACE )); then
            CB_BATCH_TRACE=0;
            CB_STARTED=;
            _cb_update_header;
            return 0;
        fi;
    else
        if (( CB_BATCH_READY )); then
            local batch_mode="$CB_BATCH_MODE";
            _cb_run_batch;
            rc=$?;
            if [[ "$batch_mode" == separate ]]; then
                CB_STARTED=;
                _cb_update_header;
                return 0;
            fi;
        fi;
    fi;
    if (( CB_FIRST_PROMPT )); then
        CB_FIRST_PROMPT=0;
        _cb_update_header;
        return 0;
    fi;
    if [[ -z "$CB_STARTED" ]]; then
        if (( CB_PASTING )); then
            printf '\033[2A\r\033[2K\033[1B\r\033[2K\033[1A\r';
        else
            printf '\033[2A\r\033[2K\033[1B\r\033[2K\033[1A\r\n';
        fi;
        _cb_update_header;
        return 0;
    fi;
    local i;
    _cb_print_status "$rc" "$CB_STARTED";
    CB_STARTED=;
    if (( CB_GAP_LINES > 0 )); then
        for ((i=0; i<CB_GAP_LINES; i++ ))
        do
            printf '\n';
        done;
        CB_GAP_LINES=0;
    fi;
    _cb_update_header;
    return 0
}

trap '_cb_border_debug' DEBUG

bind -x '"\e[200~":_cb_paste_begin'
bind -x '"\e[201~":_cb_paste_end'

PROMPT_COMMAND=_cb_finish

PS0='${CB_MARKER[${CB_STARTED:=$EPOCHREALTIME}]}${CB_MARKER[${CB_BORDER_PREPARE:=1}]}'$'\033[?2004l\033[95m├────────────────────────────────────────\033[0m\n'

PS1='\[\e[?2004h\]\[\e[95m\]┌─  ${CB_USER}\[\e[0m\]${CB_REST}\n\[\e[95m\]│\[\e[0m\] ❯ \[\eD\eD\e[2A\]'

PS2='\[\e[95m\]│\[\e[90m\] … \[\e[0m\]'

trap 'printf "\033[?2004l"' EXIT

printf '\n\033[95mCommand Blocks v0.17.0-dev activated\033[0m\n'
printf 'Default: SEPARATE + Stop OFF + Border OFF.\n'
printf 'Use cb batch separate|grouped, cb stop on|off, cb border on|off, cb status.\n'
printf 'Temporary shell; no configuration files changed.\n\n'
CBRC
