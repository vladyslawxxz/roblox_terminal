# Creating Custom Commands for Roblox Terminal

This guide explains how to create custom commands for the Roblox Terminal that can be loaded dynamically using the `loadcmd <url>` command.

## Command Structure

Every command must follow this structure:

```lua
return {
    name = "your_command_name",
    description = "Brief description of what your command does",
    aliases = { "alias1", "alias2" }, -- Optional: alternative names for the command
    execute = function(args, ctx)
        -- Your command logic here
    end
}
```

## Context Object (ctx)

The `execute` function receives a `ctx` object with the following methods and functions:

| Method | Description |
|--------|-------------|
| `printLine(text)` | Print a line in default text color |
| `printError(text)` | Print an error message in red |
| `printSuccess(text)` | Print a success message in green |
| `printInfo(text)` | Print an info message in blue |
| `clearConsole()` | Clear all output from the terminal |
| `getPathString(obj)` | Get the string representation of an object's path |
| `resolvePath(pathStr)` | Resolve a path string to an object (supports `.` and `..`) |
| `currentDir()` | Get the current directory object |
| `setCurrentDir(dir)` | Change the current directory |
| `previousDir()` | Get the previous directory object |

## Example Commands

### Simple Command - Echo

```lua
return {
    name = "echo",
    description = "Print text to console",
    aliases = { "print" },
    execute = function(args, ctx)
        if #args == 0 then
            ctx.printError("Usage: echo <text>")
            return
        end
        ctx.printLine(table.concat(args, " "))
    end
}
```

### Working with Arguments

```lua
return {
    name = "add",
    description = "Add two numbers",
    execute = function(args, ctx)
        if #args < 2 then
            ctx.printError("Usage: add <number1> <number2>")
            return
        end
        
        local num1 = tonumber(args[1])
        local num2 = tonumber(args[2])
        
        if not num1 or not num2 then
            ctx.printError("Both arguments must be numbers")
            return
        end
        
        ctx.printSuccess("Result: " .. (num1 + num2))
    end
}
```

### Working with Paths and Objects

```lua
return {
    name = "inspect",
    description = "Inspect properties of an object",
    execute = function(args, ctx)
        local target = ctx.currentDir()
        
        if #args > 0 then
            local resolved, err = ctx.resolvePath(table.concat(args, "/"))
            if not resolved then
                ctx.printError(err)
                return
            end
            target = resolved
        end
        
        ctx.printInfo("Object: " .. target.Name)
        ctx.printLine("Type: " .. target.ClassName)
        ctx.printLine("Path: " .. ctx.getPathString(target))
        
        local childCount = #target:GetChildren()
        ctx.printLine("Children: " .. childCount)
    end
}
```

### Command with Error Handling

```lua
return {
    name = "safe_command",
    description = "Example command with error handling",
    execute = function(args, ctx)
        local ok, result = pcall(function()
            -- Your risky code here
            return args[1]:lower()
        end)
        
        if not ok then
            ctx.printError("Execution failed: " .. tostring(result))
            return
        end
        
        ctx.printSuccess("Result: " .. result)
    end
}
```

## Hosting Your Command

1. Create a `.lua` file with your command code
2. Host it on a publicly accessible URL (GitHub raw content, Pastebin, etc.)
3. Load it in the terminal using: `loadcmd <url>`

### Example: Using GitHub

1. Create your command file: `my_command.lua`
2. Push it to your GitHub repository
3. Get the raw file URL: `https://raw.githubusercontent.com/your-username/your-repo/main/my_command.lua`
4. Load it: `loadcmd https://raw.githubusercontent.com/your-username/your-repo/main/my_command.lua`

## Best Practices

- **Always validate arguments** - Check argument count and types before using them
- **Use appropriate print methods** - Use `printError` for errors, `printSuccess` for success, etc.
- **Handle errors gracefully** - Use `pcall` for operations that might fail
- **Provide clear error messages** - Help users understand what went wrong
- **Keep descriptions short** - One-liners in the description field
- **Test thoroughly** - Test your command with various inputs before sharing
- **Use aliases wisely** - Keep aliases related to the command name
- **Document complex commands** - Add comments explaining non-obvious logic

## Common Patterns

### Checking Argument Count

```lua
if #args < 2 then
    ctx.printError("Usage: command <arg1> <arg2>")
    return
end
```

### Type Conversion

```lua
local value = tonumber(args[1])
if not value then
    ctx.printError("Argument must be a number")
    return
end
```

### Path Resolution

```lua
local target, err = ctx.resolvePath(args[1])
if not target then
    ctx.printError(err)
    return
end
```

### Iterating Through Children

```lua
local current = ctx.currentDir()
for _, child in ipairs(current:GetChildren()) do
    ctx.printLine(child.Name .. " (" .. child.ClassName .. ")")
end
```

## Troubleshooting

**Command not loading?**
- Check that the URL is correct and accessible
- Verify the Lua syntax is valid
- Ensure the command returns a table with `name` and `execute` fields

**Arguments not parsed correctly?**
- Remember that arguments are passed as an array
- Use `table.concat(args, " ")` to combine multiple arguments into a string
- Quoted arguments are preserved as single items: `"hello world"` = `args[1]`

**Accessing game objects fails?**
- Always check if the resolved path exists before using it
- Use `ctx.resolvePath()` to safely navigate the object hierarchy
- Use `pcall` to catch any access errors
