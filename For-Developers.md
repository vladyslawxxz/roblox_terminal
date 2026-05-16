# Roblox Terminal Developer Manual (Extended)

Version: 3.0
Audience: command authors, package authors, maintainers
Scope: command contract, runtime API, syntax, package lifecycle, testing, troubleshooting

---

## 1. Purpose

This document is a full developer reference for Roblox Terminal.
It explains exactly how commands are loaded, initialized, executed, persisted, and removed.
It also includes strict syntax tables and an API table for `ctx` and filesystem behavior.

Primary goals:
- Build stable command modules.
- Avoid runtime regressions.
- Use `pacman` packaging correctly.
- Debug quickly when commands fail.

---

## 2. Architecture Overview

| Layer | Responsibility | Notes |
|---|---|---|
| `main.lua` | GUI, input parsing, command dispatch, boot sequence | Loads manifest and command modules from remote source |
| `manifest.lua` | Built-in command list | Ordered list of command module names |
| `commands/*.lua` | Command modules | Each module returns a command table |
| `detector.lua` | Executor detection | Returns executor adapter or `nil` |
| `executors.lua` | Filesystem adapter map | Normalizes read/write API across executors |
| `pacman.lua` | Package install/remove/list and local cache restore | Uses executor filesystem API |

Command lifecycle in short:
1. Terminal starts and builds GUI.
2. Manifest is downloaded and parsed.
3. Commands are downloaded and registered in `ctx.commands`.
4. Command `init(ctx)` hooks run once (if present).
5. User input is tokenized and dispatched to `execute(args, ctx)`.

---

## 3. Command Module Contract

Every command module must return a table.

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | Yes | Primary command name used for dispatch |
| `execute` | `function(args, ctx)` | Yes | Runtime handler |
| `description` | `string` | No | Help text shown by `help` |
| `aliases` | `string[]` | No | Alternative names |
| `version` | `number[]` | No | Semantic-like tuple `{major, minor, patch}` |
| `init` | `function(ctx)` | No | Startup hook, runs after command loading |

Minimal valid module:
```lua
return {
    name = "hello",
    description = "Print greeting",
    aliases = { "hi" },
    execute = function(args, ctx)
        ctx.printSuccess("Hello, world!")
    end
}
```

---

## 4. Terminal Syntax

### 4.1 Input Grammar

| Rule | Syntax | Meaning |
|---|---|---|
| Command | `<name> [args...]` | Executes a command |
| Quoted argument | `"text with spaces"` | Preserves spaces inside one arg |
| Path token | `a/b/c` | Relative path by default |
| Root path | `/a/b/c` | Absolute from `game` |
| Current dir | `.` | Current object |
| Parent dir | `..` | Parent object |

### 4.2 Argument Parsing Behavior

| Case | Input | Parsed args |
|---|---|---|
| Plain args | `echo one two` | `{"echo", "one", "two"}` |
| Quoted | `echo "one two" three` | `{"echo", "one two", "three"}` |
| Leading spaces | `   help` | Name becomes `help` after split |
| Empty input | `` | No command executed |

### 4.3 Path Resolution Rules

| Rule ID | Rule |
|---|---|
| P1 | Empty path or `/` resolves to `game` |
| P2 | Relative path starts from `ctx.currentDir()` |
| P3 | Absolute path starts from `game` |
| P4 | `.` is ignored in traversal |
| P5 | `..` moves one parent up |
| P6 | Unknown child name returns `nil, "Path not found: ..."` |
| P7 | `name:ClassName` syntax selects child by both name and class, case-insensitive |

When multiple children share the same name, use `name:ClassName` to target a specific one:

```
Workspace/obj:Part
Workspace/obj:Sound
Workspace/obj:Sound/obj2:Script
```

## 5. Runtime Context API (`ctx`)

| API | Signature | Returns | Purpose | Common Use |
|---|---|---|---|---|
| `printLine` | `printLine(text)` | `nil` | Standard output | Regular command text |
| `printError` | `printError(text)` | `nil` | Error output style | Usage errors |
| `printSuccess` | `printSuccess(text)` | `nil` | Success style | Confirmed action |
| `printInfo` | `printInfo(text)` | `nil` | Info style | Headers and hints |
| `printColored` | `printColored(text, color)` | `nil` | Custom color output | Visual grading |
| `createColor` | `createColor(r, g, b)` | `Color3` | Build output color | Colorized lists |
| `clearConsole` | `clearConsole()` | `nil` | Remove all output lines | `clear` command |
| `printAnimLine` | `printAnimLine(text[, color])` | `TextLabel` | Create line for dynamic updates | Progress bars |
| `updateAnimLine` | `updateAnimLine(lineObj, text[, color])` | `nil` | Update animated line | Install/remove progress |
| `confirm` | `confirm(question)` | `boolean` | Ask Y/N question | Destructive actions |
| `getPathString` | `getPathString(obj)` | `string` | Convert object to path text | Messages and logs |
| `resolvePath` | `resolvePath(pathStr)` | `Instance` or `nil, err` | Resolve target object | Any path-based command |
| `currentDir` | `currentDir()` | `Instance` | Read active directory | Default target |
| `setCurrentDir` | `setCurrentDir(dir)` | `nil` | Change active directory | `cd` command |
| `previousDir` | `previousDir()` | `Instance` | Read previous directory | Back-navigation features |
| `commands` | table | mutable table | Shared registry of commands | Dynamic registration |
| `fs` | `fs()` | executor adapter or `nil` | Access executor filesystem API | `pacman` persistence |

Filesystem adapter methods expected by commands that persist data:

| FS Method | Signature | Required by pacman | Notes |
|---|---|---|---|
| `writefile` | `writefile(path, data)` | Yes | Writes text file |
| `readfile` | `readfile(path)` | Yes | Reads text file |
| `makefolder` | `makefolder(path)` | Yes | Creates folder |
| `isfile` | `isfile(path)` | Yes | File existence check |
| `isfolder` | `isfolder(path)` | Yes | Folder existence check |
| `appendfile` | `appendfile(path, data)` | No | Optional utility |
| `delfile` | `delfile(path)` | Yes | Remove file |
| `delfolder` | `delfolder(path)` | Yes | Remove folder |

---

## 6. Built-In Commands Syntax Table

| Command | Aliases | Syntax | Description |
|---|---|---|---|
| `help` | `?` | `help` | List all commands |
| `pwd` | none | `pwd` | Print current path |
| `cd` | `chdir` | `cd <path>` | Change current directory |
| `ls` | `list` | `ls [path]` | List children |
| `whoami` | `player`, `info` | `whoami [partial_name]` | Show player info |
| `find` | none | `find <name> [dir]` | Search object names recursively |
| `clear` | `cls` | `clear` | Clear output |
| `echo` | none | `echo <text...>` | Print text |
| `mkdir` | `mk` | `mkdir <ClassName> <name> [dir]` | Create instance |
| `mv` | none | `mv <path> <dest>` or `mv <path> --name <new>` | Move or rename |
| `rm` | `del` | `rm <path>` | Remove object |
| `pacman` | `pkg` | `pacman -S|-R|-Q ...` | Package manager |
| `refcom` | `reload` | `refcom` | Reload manifest commands |
| `playerlist` | `pl` | `playerlist [--sort=age-up\|--sort=age-down]` | Show players |
| `setprop` | `sp` | `setprop <path> <property> <value>` | Set a property on any object |

---

## 7. Package Lifecycle (`pacman`)

A package `main.lua` can return either a single command table or an array of command tables. Both formats are supported everywhere — install, remove, startup restore, and built-in manifest loading.

Single command:
```lua
return {
    name = "hello",
    execute = function(args, ctx) ctx.printLine("hi") end,
}
```

Multiple commands:
```lua
return {
    {
        name    = "math-add",
        aliases = { "add" },
        execute = function(args, ctx)
            ctx.printLine(tonumber(args[1]) + tonumber(args[2]))
        end,
    },
    {
        name    = "math-sub",
        aliases = { "sub" },
        execute = function(args, ctx)
            ctx.printLine(tonumber(args[1]) - tonumber(args[2]))
        end,
    },
}
```

### 7.1 Install

| Step | Action | Result |
|---|---|---|
| 1 | Validate package ID format `@user/repo` | Rejects invalid format |
| 2 | Download `https://raw.githubusercontent.com/user/repo/refs/heads/main/main.lua` | Receives source |
| 3 | `loadstring` + execute module | Single command table or array returned |
| 4 | Register all commands and their aliases in `ctx.commands` | All commands become executable immediately |
| 5 | Save package source to local cache | `Roblox-Terminal/pkg/{user}/{repo}/main.lua` |
| 6 | Save registry JSON with `names` array | `Roblox-Terminal/pkg/installed.json` |

### 7.2 Remove

| Step | Action | Result |
|---|---|---|
| 1 | Validate package ID | Reject unknown format |
| 2 | Lookup installed entry | Reject if not installed |
| 3 | Confirm removal | Supports abort |
| 4 | Unregister all commands and their aliases | All commands removed |
| 5 | Delete cached `main.lua` and package folder | Local package removed |
| 6 | Rewrite registry JSON | State consistent |

### 7.3 Startup Restore

| Source order | Behavior |
|---|---|
| Local cache first | Reads cached `main.lua` from `pkg/{user}/{repo}` |
| Remote fallback second | Uses `HttpGet` only if local file is missing |
| Registry source | Uses `Roblox-Terminal/pkg/installed.json` and migrates old registry path if needed |

---

## 8. Startup Hook Contract (`init`)

| Rule | Requirement |
|---|---|
| I1 | `init(ctx)` is optional |
| I2 | Hook runs once per command module at startup |
| I3 | Keep hook lightweight; avoid long blocking tasks |
| I4 | Hook should tolerate missing `ctx.fs()` |
| I5 | Hook should not assume command execution order |

Example:
```lua
return {
    name = "cachecheck",
    description = "Validates cache on startup",
    init = function(ctx)
        local fs = ctx.fs and ctx.fs()
        if not fs then return end
        if fs.isfolder("Roblox-Terminal/pkg") then
            ctx.printInfo("pkg cache available")
        end
    end,
    execute = function(args, ctx)
        ctx.printLine("ok")
    end
}
```

---

## 9. Error Behavior Reference

| Error Source | Symptom | Typical Root Cause | Recommended Fix |
|---|---|---|---|
| Parse error in module | Command fails to load | Invalid Lua syntax | Run lint / re-check table commas and `end` |
| Missing `name` | `invalid package` on install | Module table incomplete | Add `name` field |
| Missing `execute` | `invalid package` on install | Module table incomplete | Add `execute` function |
| `resolvePath` fails | `Path not found` | Wrong relative/absolute path | Use `pwd`, test with `ls` |
| No filesystem adapter | No persistence | Executor not detected | Fix detector or use supported executor |
| Registry unreadable | Packages not restored | Corrupted JSON | Reinstall packages or rewrite registry |

---

## 10. Style and Compatibility Rules

| Rule | Recommendation | Reason |
|---|---|---|
| S1 | Validate all arguments | Prevent runtime errors |
| S2 | Use `table.concat(args, " ")` for free-text args | Supports spaces |
| S3 | Prefer `ctx.resolvePath` over manual traversal | Consistent semantics |
| S4 | Print clear usage when invalid input | Better UX |
| S5 | Do not rely on globals unless documented | Improves portability |
| S6 | Keep command side effects explicit | Debuggability |


## 11. Context API Quick Recipes

| Recipe | Goal | Snippet |
|---|---|---|
| R001 | Print success | `ctx.printSuccess("done")` |
| R002 | Resolve object path | `local obj, err = ctx.resolvePath(path)` |
| R003 | Resolve with class disambiguation | `local obj, err = ctx.resolvePath("Workspace/obj:Sound")` |
| R004 | Default to current dir | `local target = ctx.currentDir()` |
| R005 | Move current dir | `ctx.setCurrentDir(target)` |
| R006 | Read filesystem adapter | `local fs = ctx.fs and ctx.fs()` |
| R007 | Prompt confirmation | `local ok = ctx.confirm("Proceed? [Y/n] ")` |
| R008 | Draw progress line | `local line = ctx.printAnimLine("working...")` |
| R009 | Update progress line | `ctx.updateAnimLine(line, "working... 50%")` |
| R010 | Render color line | `ctx.printColored(msg, ctx.createColor(200,200,200))` |
