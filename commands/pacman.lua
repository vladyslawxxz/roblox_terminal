local installedPackages = {}

local function parseVersion(v)
	if type(v) ~= "table" then return "0.0.0" end
	return (v[1] or 0) .. "." .. (v[2] or 0) .. "." .. (v[3] or 0)
end

local function parsePackage(raw)
	local user, repo = raw:match("^@([^/]+)/(.+)$")
	if not user or not repo then
		return nil, "Invalid package format. Use @username/reponame"
	end
	return { user = user, repo = repo }, nil
end

local function buildUrl(user, repo)
	return "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/refs/heads/main/main.lua"
end

return {
	name = "pacman",
	description = "Package manager for terminal commands",
	version = {1, 0, 0},
	aliases = { "pkg" },

	execute = function(args, ctx)
		if #args < 1 then
			ctx.printError("Usage: pacman -S @user/repo | pacman -R @user/repo | pacman -Q")
			return
		end

		local flag = args[1]

		-- Встановити пакет
		if flag == "-S" then
			if #args < 2 then
				ctx.printError("Usage: pacman -S @username/reponame")
				return
			end

			local pkg, err = parsePackage(args[2])
			if not pkg then
				ctx.printError(err)
				return
			end

			if installedPackages[args[2]] then
				ctx.printError("Package already installed: " .. args[2])
				return
			end

			local url = buildUrl(pkg.user, pkg.repo)
			ctx.printInfo("Fetching " .. args[2] .. "...")

			local ok, src = pcall(function()
				return game:HttpGet(url)
			end)

			if not ok or not src then
				ctx.printError("Failed to fetch package: " .. tostring(src))
				return
			end

			local fn, parseErr = loadstring(src)
			if not fn then
				ctx.printError("Parse error: " .. tostring(parseErr))
				return
			end

			local runOk, cmd = pcall(fn)
			if not runOk then
				ctx.printError("Runtime error: " .. tostring(cmd))
				return
			end

			if type(cmd) ~= "table" or not cmd.name or not cmd.execute then
				ctx.printError("Invalid package: main.lua must return { name, execute, ... }")
				return
			end

			ctx.commands[cmd.name] = cmd

			installedPackages[args[2]] = {
				name    = cmd.name,
				version = cmd.version or {0, 0, 0},
			}

			ctx.printSuccess(
				"installed: " .. cmd.name ..
				" v" .. parseVersion(cmd.version) ..
				" (" .. args[2] .. ")"
			)

		-- Видалити пакет
		elseif flag == "-R" then
			if #args < 2 then
				ctx.printError("Usage: pacman -R @username/reponame")
				return
			end

			local pkgKey = args[2]
			local entry  = installedPackages[pkgKey]

			if not entry then
				ctx.printError("Package not installed: " .. pkgKey)
				return
			end

			ctx.commands[entry.name] = nil
			installedPackages[pkgKey] = nil

			ctx.printSuccess("removed: " .. entry.name .. " (" .. pkgKey .. ")")

		-- Список встановлених
		elseif flag == "-Q" then
			local count = 0
			for key, entry in pairs(installedPackages) do
				ctx.printLine(
					"  " .. entry.name ..
					" v" .. parseVersion(entry.version) ..
					" (" .. key .. ")"
				)
				count = count + 1
			end
			if count == 0 then
				ctx.printInfo("No packages installed.")
			else
				ctx.printLine("")
				ctx.printInfo("Total: " .. count .. " package(s)")
			end

		else
			ctx.printError("Unknown flag: " .. flag .. ". Use -S, -R or -Q")
		end
	end,
}
