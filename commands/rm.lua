return {
	name = "rm",
	description = "Removes an object (rm <path>)",
	aliases = { "del" },

	execute = function(args, ctx)
		if #args < 1 then
			ctx.printError("Usage: rm <path>")
			return
		end

		local path     = args[1]
		local obj, err = ctx.resolvePath(path)

		if not obj then
			ctx.printError(err or "Object not found")
			return
		end

		if obj == game or obj == workspace then
			ctx.printError("Cannot remove protected object: " .. obj.Name)
			return
		end

		local removedPath = ctx.getPathString(obj)
		obj:Destroy()
		ctx.printSuccess("Removed: " .. removedPath)
	end,
}
