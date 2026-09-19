# dotfiles

Personal dotfiles, tracked as a bare repo at `~/.dotfiles` with the working tree in `$HOME`.

Managed with the `dot` alias:

```sh
alias dot='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dot status
dot add .config/hypr
dot commit -m "..."

# push to all hosts
dot push github
dot push codeberg
dot push gitlab
```

Mirrored on GitHub, Codeberg, and GitLab.

Managed with ML4W / noctalia workflows. See `~/.config/bashrc` and `~/.config/hypr` for shell and compositor configuration.