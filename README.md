# Roblox Terminal

A Linux-style terminal emulator for Roblox that allows you to interact with the game's object hierarchy through command-line interface.

## Features

- **Interactive terminal GUI** - Dark-themed terminal window with a command input box and scrollable output
- **Command-based navigation** - Navigate through the Roblox workspace hierarchy using commands like `cd`, `pwd`, `ls`
- **Window controls** - Minimize, maximize, and close the terminal window
- **Command history** - Navigate through previous commands using arrow keys
- **Extensible architecture** - Easy to add new custom commands

## Usage

The terminal displays a prompt in the format: `[username@linux]: `

Common operations:
- Type a command and press Enter to execute
- Use arrow keys to navigate command history
- Close the terminal window and click the `>_` button to reopen it

## Development

Commands are loaded dynamically from the `commands/` directory via `manifest.lua`. Each command module should export:

```lua
return {
    name = "command_name",
    aliases = {"alias1", "alias2"},
    execute = function(args, ctx)
        -- Command implementation
    end
}
