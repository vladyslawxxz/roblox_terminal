return {
	name = "refcom",
	description = "Reloads all commands from the manifest",
	aliases = { "reload" },

	execute = function(args, ctx)
		ctx.printInfo("Reloading commands...")

		for k in pairs(ctx.commands) do
			ctx.commands[k] = nil
		end

		local BASE_URL = "https://raw.githubusercontent.com/vladyslawxxz/roblox_terminal/main/"

		local ok, src = pcall(function()
			return game:HttpGet(BASE_URL .. "manifest.lua")
		end)

		if not ok or not src then
			ctx.printError("Failed to fetch manifest.lua")
			return
		end

		local fn, parseErr = loadstring(src)
		if not fn then
			ctx.printError("manifest.lua parse error: " .. tostring(parseErr))
			return
		end

		local runOk, manifest = pcall(fn)
		if not runOk or type(manifest) ~= "table" then
			ctx.printError("manifest.lua returned invalid data")
			return
		end

		local loaded, failed = 0, 0

		for _, name in ipairs(manifest) do
			local url = BASE_URL .. "commands/" .. name .. ".lua"

			local fetchOk, cmdSrc = pcall(function()
				return game:HttpGet(url)
			end)

			if not fetchOk or not cmdSrc then
				ctx.printError("Failed to fetch: " .. name)
				failed = failed + 1
			else
				local cmdFn, cmdErr = loadstring(cmdSrc)
				if not cmdFn then
					ctx.printError("Parse error (" .. name .. "): " .. tostring(cmdErr))
					failed = failed + 1
				else
					local cmdOk, cmd = pcall(cmdFn)
					if cmdOk and cmd and cmd.name and cmd.execute then
						ctx.commands[cmd.name] = cmd
						loaded = loaded + 1
					else
						ctx.printError("Failed to load: " .. name)
						failed = failed + 1
					end
				end
			end
		end

		ctx.printSuccess(string.format("Reloaded %d command(s)%s",
			loaded,
			failed > 0 and (", errors: " .. failed) or ""
		))
	end,
}
