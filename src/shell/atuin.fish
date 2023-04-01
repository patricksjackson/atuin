set -gx ATUIN_SESSION (atuin uuid)
set -g ATUIN_OFFSET -1

function _atuin_preexec --on-event fish_preexec
    if not test -n "$fish_private_mode"
        set -gx ATUIN_HISTORY_ID (atuin history start -- "$argv[1]")
    end
    set -g ATUIN_OFFSET -1
end

function _atuin_postexec --on-event fish_postexec
    set s $status
    if test -n "$ATUIN_HISTORY_ID"
        RUST_LOG=error atuin history end --exit $s -- $ATUIN_HISTORY_ID &>/dev/null &
        disown
    end
end

function _atuin_cancelexec --on-event fish_cancel
    set -g ATUIN_OFFSET -1
end

function _atuin_search
    set h (RUST_LOG=error atuin search $argv -i -- (commandline -b) 3>&1 1>&2 2>&3)
    commandline -f repaint
    if test -n "$h"
        commandline -r $h
    end
end

function _atuin_prev_cmd
    if test -1 -eq $ATUIN_OFFSET
        set -g ATUIN_CURRENT_CMD (commandline --current-buffer)
        set -g ATUIN_CURRENT_POS (commandline --cursor)
    end
    set -g ATUIN_OFFSET (math $ATUIN_OFFSET + 1)
    set h (RUST_LOG=error atuin search $argv --limit 1 --cmd-only --offset $ATUIN_OFFSET)
    commandline -f repaint
    commandline --replace $h
end

function _atuin_next_cmd
    switch $ATUIN_OFFSET
        case -1
            return
        case 0
            set -g ATUIN_OFFSET -1
            commandline --replace $ATUIN_CURRENT_CMD
            commandline --cursor $ATUIN_CURRENT_POS
        case '*'
            set -g ATUIN_OFFSET (math $ATUIN_OFFSET - 1)
            set h (RUST_LOG=error atuin search $argv --limit 1 --cmd-only --offset $ATUIN_OFFSET)
            commandline -f repaint
            commandline --replace $h
    end
end

function _atuin_bind_up
    # Fallback to fish's builtin up-or-search if we're in search or paging mode
    if commandline --search-mode; or commandline --paging-mode
        up-or-search
        return
    end

    # Only invoke atuin if we're on the top line of the command
    set -l lineno (commandline --line)
    switch $lineno
        case 1
            _atuin_prev_cmd --shell-up-key-binding
        case '*'
            up-or-search
    end
end

function _atuin_bind_down
    # Fallback to fish's builtin down-or-search if we're in search or paging mode
    if commandline --search-mode; or commandline --paging-mode
        down-or-search
        return
    end

    # Only invoke atuin if we're on the bottom line of the command
    set -l lineno (commandline --line)
    set -l line_count (count (commandline))
    switch $lineno
        case $line_count
            _atuin_next_cmd --shell-up-key-binding
        case '*'
            down-or-search
    end
end

# FIXME: for illustration only
# These are added by atuin in `atuin init fish`
if test -z $ATUIN_NOBIND
    bind \cr _atuin_search
    bind -k up _atuin_bind_up
    bind \e0A _atuin_bind_up
    bind \e\[A _atuin_bind_up
    bind -k down _atuin_bind_down
    bind \e0B _atuin_bind_down
    bind \e\[B _atuin_bind_down

    if bind -M insert > /dev/null 2>&1
        bind -M insert \cr _atuin_search
        bind -M insert -k up _atuin_bind_up
        bind -M insert \e0A _atuin_bind_up
        bind -M insert \e\[A _atuin_bind_up
        bind -M insert -k down _atuin_bind_down
        bind -M insert \e0B _atuin_bind_down
        bind -M insert \e\[B _atuin_bind_down
    end
end