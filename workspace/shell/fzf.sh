#!/bin/bash

# fzf integration
source /opt/fzf/shell/key-bindings.bash 2>/dev/null || true
source /opt/fzf/shell/completion.bash 2>/dev/null || true
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_T_OPTS="--preview 'cat {}' --preview-window=right:60%:wrap"
