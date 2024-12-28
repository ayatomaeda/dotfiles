# Install

```sh
$ brew install chezmoi
```

# Add dotfiles

```sh
$ chezmoi add .zshrc
```

# Edit dotfiles

```sh
$ chezmoi edit .zshrc
```

# Apply

```sh
$ chezmoi apply
```

# Git commit & push

```sh
$ chezmoi cd

$ git add .
$ git remote add origin ~
$ git push origin ~
```

# New PC

```sh
$ brew install chezmoi
$ chezmoi init ~.git

$chezmoi apply
```
