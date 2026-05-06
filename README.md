# Roblox Terminal

Roblox Terminal is a Linux-style command terminal for Roblox.
It gives you a command-line interface to inspect and manage the game object tree, plus a package manager for custom commands.

## What This Project Does

- Renders an interactive terminal GUI in `PlayerGui`
- Supports command execution with argument parsing and quoted strings
- Resolves relative and absolute object paths (`.`, `..`, `/...`)
- Maintains command history and command autocomplete
- Loads built-in commands from `manifest.lua`
- Detects executor filesystem support for persistence features
- Supports command packages through `pacman`

## Built-In Commands

- `help`
- `pwd`
- `cd`
- `ls`
- `whoami`
- `find`
- `clear`
- `echo`
- `mkdir`
- `mv`
- `rm`
- `pacman`
- `refcom`
- `playerlist`

## Quick Usage

Prompt format:

```text
[player@linux]:
```

Common examples:

```text
help
pwd
cd Workspace
ls
find Part Workspace
mkdir Folder TestFolder Workspace
mv Workspace/TestFolder --name MyFolder
rm Workspace/MyFolder
```

## pacman (Package Manager)

`pacman` installs command modules from GitHub repositories in format `@user/repo`.

Supported actions:

- `pacman -S @user/repo` install package
- `pacman -R @user/repo` remove package
- `pacman -Q` list installed packages

Package entrypoint requirements:

- Repository must contain `main.lua` in repo root
- `main.lua` must return a valid command table (`name`, `execute`, optional `aliases`, etc.)

Install source URL format:

```text
https://raw.githubusercontent.com/user/repo/refs/heads/main/main.lua
```

Local package persistence:

- Registry: `Roblox-Terminal/pkg/installed.json`
- Cached package source: `Roblox-Terminal/pkg/{user}/{repo}/main.lua`

Startup behavior:

- Cached packages are auto-loaded on terminal startup
- If local package file is missing, remote fetch is used as fallback

## Architecture

- `main.lua`: boot flow, GUI, input handling, command dispatch
- `manifest.lua`: built-in command list
- `commands/*.lua`: built-in command modules
- `detector.lua`: executor detection
- `executors.lua`: filesystem adapter map

## Developer Docs

Full command API, syntax tables, and packaging details are documented in:

- `For-Developers.md`

## Notes

- Filesystem persistence depends on executor support (`ctx.fs()` adapter availability)
- If executor is not detected, terminal still works, but persistent package storage is unavailable
