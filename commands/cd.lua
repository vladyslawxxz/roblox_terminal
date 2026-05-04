return {
	name = "cd",
	description = "Change the current directory",
	aliases = { "chdir" },

	execute = function(args, ctx)
		if #args == 0 then
			ctx.printError("Usage: cd <path>")
			return
		end

		local path = table.concat(args, " ")
		local target, err = ctx.resolvePath(path)
		
		if not target then
			ctx.printError(err or "Path not found")
			return
		end

		ctx.setCurrentDir(target)
		ctx.printSuccess("Changed to: " .. ctx.getPathString(target))
	end,
}
