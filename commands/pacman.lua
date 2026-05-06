local installedPackages = {}

local function parseVersion(v)
	if type(v) ~= "table" then return "0.0.0" end
	return (v[1] or 0) .. "." .. (v[2] or 0) .. "." .. (v[3] or 0)
end

local function parsePackage(raw)
	local user, repo = raw:match("^@([^/]+)/(.+)$")
	if not user or not repo then
		return nil, "invalid package format. Use @username/reponame"
	end
	return { user = user, repo = repo, key = raw }, nil
end

local function buildUrl(user, repo)
	return "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/refs/heads/main/main.lua"
end

local function createProgressBar(ctx, label)
	local BAR_W  = 40
	local line   = ctx.printAnimLine(label .. " [" .. string.rep("-", BAR_W) .. "]")
	local done   = false

	local function update(progress)
		if done then return end
		progress = math.clamp(progress, 0, 1)
		local filled = math.floor(progress * BAR_W)
		local empty  = BAR_W - filled - 1
		local pac    = (filled % 2 == 0) and "C" or "c"
		local bar
		if filled >= BAR_W then
			bar = string.rep("#", BAR_W)
		elseif filled == 0 then
			bar = pac .. string.rep("-", BAR_W - 1)
		else
			bar = string.rep("#", filled) .. pac .. string.rep("-", empty)
		end
		ctx.updateAnimLine(line, label .. " [" .. bar .. "]")
	end

	local function finish()
		done = true
		ctx.updateAnimLine(line, label .. " [" .. string.rep("#", BAR_W) .. "]")
	end

	return update, finish
end

return {
	name        = "pacman",
	description = "Package manager for terminal commands",
	version     = {1, 0, 0},
	aliases     = { "pkg" },

	execute = function(args, ctx)
		if #args < 1 then
			ctx.printError("usage: pacman -S @user/repo | -R @user/repo | -Q")
			return
		end

		local flag = args[1]

		if flag == "-S" then
			if #args < 2 then
				ctx.printError("usage: pacman -S @username/reponame")
				return
			end

			local pkg, err = parsePackage(args[2])
			if not pkg then ctx.printError(err) return end

			if installedPackages[pkg.key] then
				ctx.printError("package already installed: " .. pkg.key)
				return
			end

			local url = buildUrl(pkg.user, pkg.repo)

			ctx.printInfo(":: Resolving " .. pkg.key .. "...")
			task.wait(0.4)
			ctx.printLine("resolving dependencies...")
			task.wait(0.3)
			ctx.printLine("looking for conflicting packages...")
			task.wait(0.3)

			local ok, src = pcall(function() return game:HttpGet(url) end)
			if not ok or not src or src == "" then
				ctx.printError("failed to fetch: " .. tostring(src))
				return
			end

			local fn, parseErr = loadstring(src)
			if not fn then
				ctx.printError("parse error: " .. tostring(parseErr))
				return
			end

			local runOk, cmd = pcall(fn)
			if not runOk or type(cmd) ~= "table" or not cmd.name or not cmd.execute then
				ctx.printError("invalid package: main.lua must return { name, execute, ... }")
				return
			end

			local ver = parseVersion(cmd.version)

			ctx.printLine("")
			ctx.printLine("Packages (1)  " .. cmd.name .. "-" .. ver)
			ctx.printLine("")
			ctx.printInfo("Total Download Size:   0.01 MiB")
			ctx.printInfo("Total Installed Size:  0.01 MiB")
			ctx.printLine("")

			local confirmed = ctx.confirm(":: Proceed with installation? [Y/n] ")
			if not confirmed then
				ctx.printLine("Aborted.")
				return
			end

			ctx.printLine("")

			local dlUpdate, dlFinish = createProgressBar(ctx, "downloading " .. cmd.name)
			for i = 1, 20 do
				dlUpdate(i / 20)
				task.wait(0.04)
			end
			dlFinish()
			task.wait(0.1)

			local inUpdate, inFinish = createProgressBar(ctx, "installing  " .. cmd.name)
			for i = 1, 20 do
				inUpdate(i / 20)
				task.wait(0.03)
			end
			inFinish()
			task.wait(0.15)

			ctx.commands[cmd.name] = cmd
			if cmd.aliases then
				for _, alias in ipairs(cmd.aliases) do
					ctx.commands[alias] = cmd
				end
			end

			installedPackages[pkg.key] = {
				name    = cmd.name,
				version = cmd.version or {0, 0, 0},
			}

			ctx.printLine("")
			ctx.printSuccess("(1/1) installing " .. cmd.name .. " v" .. ver .. "  [done]")

		elseif flag == "-R" then
			if #args < 2 then
				ctx.printError("usage: pacman -R @username/reponame")
				return
			end

			local pkg, err = parsePackage(args[2])
			if not pkg then ctx.printError(err) return end

			local entry = installedPackages[pkg.key]
			if not entry then
				ctx.printError("package not installed: " .. pkg.key)
				return
			end

			ctx.printLine("checking dependencies...")
			task.wait(0.4)
			ctx.printLine("")
			ctx.printLine("Packages (1)  " .. entry.name .. "-" .. parseVersion(entry.version))
			ctx.printLine("")

			local confirmed = ctx.confirm(":: Do you want to remove these packages? [Y/n] ")
			if not confirmed then
				ctx.printLine("Aborted.")
				return
			end

			ctx.printLine("")

			local rmUpdate, rmFinish = createProgressBar(ctx, "removing    " .. entry.name)
			for i = 1, 20 do
				rmUpdate(i / 20)
				task.wait(0.03)
			end
			rmFinish()
			task.wait(0.15)

			local stored = ctx.commands[entry.name]
			ctx.commands[entry.name] = nil
			if stored and stored.aliases then
				for _, alias in ipairs(stored.aliases) do
					ctx.commands[alias] = nil
				end
			end
			installedPackages[pkg.key] = nil

			ctx.printLine("")
			ctx.printSuccess("(1/1) removing  " .. entry.name .. "  [done]")

		elseif flag == "-Q" then
			local count = 0
			for key, entry in pairs(installedPackages) do
				ctx.printLine(
					string.format("  %-16s %s  (%s)",
						entry.name, parseVersion(entry.version), key)
				)
				count = count + 1
			end
			if count == 0 then
				ctx.printInfo("no packages installed.")
			else
				ctx.printLine("")
				ctx.printInfo("total: " .. count .. " package(s)")
			end

		else
			ctx.printError("unknown flag: " .. flag .. ". Use -S, -R or -Q")
		end
	end,
}
