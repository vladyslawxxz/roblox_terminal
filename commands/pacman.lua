local installedPackages = {}
local initialized = false

local HttpService = game:GetService("HttpService")
local PACKAGE_ROOT = "Roblox-Terminal/pkg"
local REGISTRY_PATH = PACKAGE_ROOT .. "/installed.json"
local LEGACY_REGISTRY_PATH = "Roblox-Terminal/installed.json"

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

local function packageDir(user, repo)
	return PACKAGE_ROOT .. "/" .. user .. "/" .. repo
end

local function packageMainPath(user, repo)
	return packageDir(user, repo) .. "/main.lua"
end

local function normalizePath(path, sep)
	if sep == "\\" then
		return path:gsub("/", "\\")
	end
	return path:gsub("\\", "/")
end

local function ensureFolderTree(fs, path)
	local built = ""
	for part in path:gmatch("[^/]+") do
		built = (built == "") and part or (built .. "/" .. part)
		pcall(function()
			fs.makefolder(built)
		end)
	end
end

local function ensureFolderTreeBoth(fs, path)
	local slashPath = normalizePath(path, "/")
	ensureFolderTree(fs, slashPath)
end

local function tryReadFile(fs, path)
	local candidates = { normalizePath(path, "/"), normalizePath(path, "\\") }
	for _, p in ipairs(candidates) do
		if fs.isfile(p) then
			local ok, content = pcall(function() return fs.readfile(p) end)
			if ok and content and content ~= "" then
				return content
			end
		end
	end
	return nil
end

local function writePackageFile(fs, user, repo, content)
	local dir = packageDir(user, repo)
	local slashDir = normalizePath(dir, "/")
	local slashFile = normalizePath(packageMainPath(user, repo), "/")

	local ok = false
	local lastErr = nil

	local function attempt(filePath, folderPath)
		local writeOk, writeErr = pcall(function()
			ensureFolderTreeBoth(fs, folderPath)
			fs.writefile(filePath, content)
		end)
		if writeOk and fs.isfile(filePath) then
			ok = true
			return
		end
		lastErr = writeErr
	end

	attempt(slashFile, slashDir)

	if ok then
		return true
	end
	return false, lastErr
end

local function writeTextFile(fs, path, content)
	local slashPath = normalizePath(path, "/")
	local parent = path:match("^(.*)[/\\][^/\\]+$") or ""

	local function attempt(targetPath)
		local ok = pcall(function()
			if parent ~= "" then
				ensureFolderTreeBoth(fs, parent)
			end
			fs.writefile(targetPath, content)
		end)
		return ok and fs.isfile(targetPath)
	end

	if attempt(slashPath) then return true end
	return false
end

local function saveRegistry(fs)
	local payload = {}
	for key, entry in pairs(installedPackages) do
		local user, repo = key:match("^@([^/]+)/(.+)$")
		local ver = entry.version or {0, 0, 0}
		payload[key] = {
			name = entry.name,
			user = user or "",
			repo = repo or "",
			version = { ver[1] or 0, ver[2] or 0, ver[3] or 0 },
		}
	end

	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not ok then return end

	writeTextFile(fs, REGISTRY_PATH, encoded)
end

local function loadFromDisk(fs, ctx)
	local raw = tryReadFile(fs, REGISTRY_PATH)
	local ok = raw ~= nil
	if not ok or not raw or raw == "" then
		local oldRaw = tryReadFile(fs, LEGACY_REGISTRY_PATH)
		local oldOk = oldRaw ~= nil
		if oldOk and oldRaw and oldRaw ~= "" then
			raw = oldRaw
			writeTextFile(fs, REGISTRY_PATH, oldRaw)
		end
	end
	if not raw or raw == "" then return end

	local decodedOk, registry = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not decodedOk or type(registry) ~= "table" then return end

	for key, entry in pairs(registry) do
		if type(key) == "string" and type(entry) == "table" then
			local user = entry.user
			local repo = entry.repo
			local ver = entry.version

			if (not user or user == "" or not repo or repo == "") then
				local pu, pr = key:match("^@([^/]+)/(.+)$")
				user, repo = pu, pr
			end

			if user and repo then
				local pkgKey = "@" .. user .. "/" .. repo
				local src = tryReadFile(fs, packageMainPath(user, repo))

				if not src then
					local url = buildUrl(user, repo)
					local srcOk, remoteSrc = pcall(function() return game:HttpGet(url) end)
					if srcOk and remoteSrc and remoteSrc ~= "" then
						src = remoteSrc
					end
				end

				if src then
					local fn = loadstring(src)
					if fn then
						local runOk, cmd = pcall(fn)
						if runOk and type(cmd) == "table" and cmd.name and cmd.execute then
							ctx.commands[cmd.name] = cmd
							if cmd.aliases then
								for _, alias in ipairs(cmd.aliases) do
									ctx.commands[alias] = cmd
								end
							end
							installedPackages[pkgKey] = {
								name = cmd.name,
								version = type(ver) == "table" and {
									tonumber(ver[1]) or 0,
									tonumber(ver[2]) or 0,
									tonumber(ver[3]) or 0,
								} or (cmd.version or {0, 0, 0}),
							}
						end
					end
				end
			end
		end
	end
end

local function createProgressBar(ctx, label)
	local BAR_W = 40
	local line  = ctx.printAnimLine(label .. " [" .. string.rep("-", BAR_W) .. "]")
	local done  = false

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
		local fs = ctx.fs and ctx.fs()

		if not initialized then
			initialized = true
			if fs then
				loadFromDisk(fs, ctx)
			end
		end

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
			for i = 1, 20 do dlUpdate(i / 20) task.wait(0.04) end
			dlFinish()
			task.wait(0.1)

			local inUpdate, inFinish = createProgressBar(ctx, "installing  " .. cmd.name)
			for i = 1, 20 do inUpdate(i / 20) task.wait(0.03) end
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

			if fs then
				local writeOk, writeErr = writePackageFile(fs, pkg.user, pkg.repo, src)
				if not writeOk then
					ctx.printError("failed to save package file: " .. tostring(writeErr))
				end
				saveRegistry(fs)
			end

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
			for i = 1, 20 do rmUpdate(i / 20) task.wait(0.03) end
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

			if fs then
				pcall(function()
					local dirSlash = normalizePath(packageDir(pkg.user, pkg.repo), "/")
					local fileSlash = normalizePath(packageMainPath(pkg.user, pkg.repo), "/")
					if fs.isfile(fileSlash) then
						fs.delfile(fileSlash)
					end
					if fs.isfolder(dirSlash) then
						fs.delfolder(dirSlash)
					end
				end)
				saveRegistry(fs)
			end

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
