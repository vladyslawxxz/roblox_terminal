return {
	name = "loadcmd",
	description = "Loads a command from a URL into the terminal (loadcmd <url>)",
	aliases = { "lc" },

	execute = function(args, ctx)
		if #args < 1 then
			ctx.printError("Usage: loadcmd <url>")
			return
		end

		local url = args[1]
		ctx.printInfo("Fetching: " .. url)

		local ok, src = pcall(function()
			return game:HttpGet(url)
		end)

		if not ok or not src then
			ctx.printError("Failed to fetch: " .. tostring(src))
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
			ctx.printError("Invalid command module: must return { name, description, aliases, execute }")
			return
		end

		ctx.commands[cmd.name] = cmd
		ctx.printSuccess("Loaded command: " .. cmd.name .. (cmd.description and (" — " .. cmd.description) or ""))
	end,
}
