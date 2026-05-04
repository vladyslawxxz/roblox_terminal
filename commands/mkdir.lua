return {
	name = "mkdir",
	description = "Creates a new object (mkdir <ClassName> <name> [dir])",
	aliases = { "mk" },

	execute = function(args, ctx)
		if #args < 2 then
			ctx.printError("Usage: mkdir <ClassName> <name> [dir]")
			return
		end

		local className = args[1]
		local objName   = args[2]
		local dirPath   = args[3] or "."
		local dir, err  = ctx.resolvePath(dirPath)

		if not dir then
			ctx.printError(err or "Invalid directory")
			return
		end

		local ok, result = pcall(function()
			local obj = Instance.new(className)
			obj.Name = objName
			obj.Parent = dir
			return obj
		end)

		if ok then
			ctx.printSuccess("Created " .. className .. " '" .. objName .. "' in " .. ctx.getPathString(dir))
		else
			ctx.printError("Failed to create: " .. tostring(result))
		end
	end,
}
