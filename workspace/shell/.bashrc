# shellcheck shell=bash
# .bashrc for ${APP_USER} user - DockerKit Local Development
# Source: workspace/shell/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Load aliases
if [ -f ~/.bash_aliases ]; then
    # shellcheck source=.bash_aliases
    . ~/.bash_aliases
fi

# Bash configuration optimized for development
export HISTCONTROL=ignoredups:erasedups
export HISTSIZE=10000
export HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize

# Save history immediately after each command (prevents loss on container restart)
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a"

# Terminal width configuration
TERMINAL_MAX_COLUMNS=${TERMINAL_MAX_COLUMNS:-120}

# Cap terminal width before each command for better output formatting
_cap_columns() {
    [[ $COLUMNS -gt $TERMINAL_MAX_COLUMNS ]] && export COLUMNS=$TERMINAL_MAX_COLUMNS
}
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}_cap_columns"

# Enable bash completion
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Development environment variables (always enabled)
export EDITOR=${EDITOR:-nano}
export PAGER=${PAGER:-less}
export COMPOSER_MEMORY_LIMIT=-1

# === Shell Detection Fix ===
export SHELL=/bin/bash
export BASH_ENV=~/.bashrc
export ENV=~/.bashrc

# Ensure bash is properly detected
if [ -n "$BASH_VERSION" ]; then
    export SHELL_NAME=bash
    export CURRENT_SHELL=bash
fi

# === Color support configuration ===
export FORCE_COLOR=1
export CLICOLOR=1
export CLICOLOR_FORCE=1
export COMPOSER_NO_ANSI=0

# Terminal color support
if [[ -t 1 ]]; then
    export COLORTERM=truecolor
    export TERM=xterm-256color
fi

# Auto-resize terminal for correct width detection
if [[ $- == *i* ]] && [[ -t 1 ]] && command -v resize >/dev/null 2>&1; then
    # Initial resize on shell start
    eval "$(resize 2>/dev/null)"

    # Auto-update on terminal window resize
    trap 'eval "$(resize 2>/dev/null)"' WINCH
fi

# Laravel artisan completion - static implementation
# Based on Symfony Console completion template for optimal performance
if command -v php >/dev/null 2>&1; then
    # Laravel artisan completion based on Symfony Console completion
    _sf_artisan() {
        # Use newline as only separator to allow space in completion values
        IFS=$'\n'
        local sf_cmd="${COMP_WORDS[0]}"

        # shellcheck disable=SC2086  # External script from Symfony Console completion - used as is
        sf_cmd_type=$(type -t $sf_cmd)
        if [[ $sf_cmd_type == "alias" ]]; then
            # shellcheck disable=SC2086  # External script from Symfony Console completion - used as is
            sf_cmd=$(alias $sf_cmd | sed -E "s/alias $sf_cmd='(.*)'/\1/")
        elif [[ $sf_cmd_type == "file" ]]; then
            # shellcheck disable=SC2086  # External script from Symfony Console completion - used as is
            sf_cmd=$(type -p $sf_cmd)
        fi

        if [[ $sf_cmd_type != "function" && ! -x $sf_cmd ]]; then
            return 1
        fi

        # shellcheck disable=SC2034  # External script from Symfony Console completion - prev may be used internally
        local cur prev words cword
        _get_comp_words_by_ref -n := cur prev words cword

        local completecmd=("$sf_cmd" "_complete" "--no-interaction" "-sbash" "-c$cword" "-Sbash")
        for w in "${words[@]}"; do
            w=$(printf -- '%b' "$w")
            # remove quotes from typed values
            quote="${w:0:1}"
            if [ "$quote" == \' ]; then
                w="${w%\'}"
                w="${w#\'}"
            elif [ "$quote" == \" ]; then
                w="${w%\"}"
                w="${w#\"}"
            fi

            # shellcheck disable=SC2236  # External script from Symfony Console completion - used as is
            if [ ! -z "$w" ]; then
                completecmd+=("-i$w")
            fi
        done

        local sfcomplete
        if sfcomplete=$("${completecmd[@]}" 2>&1); then
            local quote suggestions
            quote=${cur:0:1}

            # Use single quotes by default if suggestions contains backslash (FQCN)
            if [ "$quote" == '' ] && [[ "$sfcomplete" =~ \\ ]]; then
                quote=\'
            fi

            if [ "$quote" == \' ]; then
                # single quotes: no additional escaping (does not accept ' in values)
                suggestions=$(for s in $sfcomplete; do printf $'%q%q%q\n' "$quote" "$s" "$quote"; done)
            elif [ "$quote" == \" ]; then
                # double quotes: double escaping for \ $ ` "
                suggestions=$(for s in $sfcomplete; do
                    s=${s//\\/\\\\}
                    s=${s//\$/\\\$}
                    s=${s//\`/\\\`}
                    s=${s//\"/\\\"}
                    printf $'%q%q%q\n' "$quote" "$s" "$quote";
                done)
            else
                # no quotes: double escaping
                # shellcheck disable=SC2046  # External script from Symfony Console completion - used as is
                suggestions=$(for s in $sfcomplete; do printf $'%q\n' $(printf '%q' "$s"); done)
            fi
            # shellcheck disable=SC2207,SC2046  # External script from Symfony Console completion - used as is
            COMPREPLY=($(IFS=$'\n' compgen -W "$suggestions" -- $(printf -- "%q" "$cur")))
            __ltrim_colon_completions "$cur"
        else
            if [[ "$sfcomplete" != *"Command \"_complete\" is not defined."* ]]; then
                >&2 echo
                # shellcheck disable=SC2086  # External script from Symfony Console completion - used as is
                >&2 echo $sfcomplete
            fi

            return 1
        fi
    }

    # Register completion for multiple artisan command variants
    complete -F _sf_artisan artisan
    complete -F _sf_artisan art

    # Fast command functions without dynamic completion setup
    artisan() {
        php artisan --ansi "$@"
    }

    art() {
        php artisan --ansi "$@"
    }
fi
