# SuperAwesomeMagicalLinux's fish defaults (the terminal opens fish; your login shell stays bash).

if status is-interactive
    set -g fish_greeting

    # The desktop's colour scheme, as the shell last set it.
    cat ~/.local/state/caelestia/sequences.txt 2>/dev/null

    command -q zoxide; and zoxide init fish --cmd cd | source
    command -q eza; and alias ls 'eza --icons --group-directories-first'

    abbr -a ll 'ls -l'
    abbr -a la 'ls -a'

    # Lets foot jump between prompts (Ctrl+Shift+Z / X).
    function __sam_mark_prompt --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end
end
