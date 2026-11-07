fish_add_path "$HOME/.local/bin"

if status is-interactive; and type -q starship
    starship init fish | source
end
