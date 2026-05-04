return {
	name = "mv",
	description = "Moves or renames an object (mv <path> <dest> | mv <path> --name <new>)",
	aliases = {},

	execute = function(args, ctx)
		if #args < 2 then
			ctx.printError("Usage: mv <path> <dest>  or  mv <path> --name <newname>")
			return
		end

		local srcPath  = args[1]
		local src, err = ctx.resolvePath(srcPath)

		if not src then
			ctx.printError(err or "Source not found")
			return
		end

		if args[2] == "--name" then
			if not args[3] then
				ctx.printError("Usage: mv <path> --name <newname>")
				return
			end
			local oldName = src.Name
			src.Name = args[3]
			ctx.printSuccess("Renamed: " .. oldName .. " -> " .. src.Name)
		else
			local destPath  = args[2]
			local dest, err2 = ctx.resolvePath(destPath)

			if not dest then
				ctx.printError(err2 or "Destination not found")
				return
			end

			local oldPath = ctx.getPathString(src)
			src.Parent = dest
			ctx.printSuccess("Moved: " .. oldPath .. " -> " .. ctx.getPathString(src))
		end
	end,
}
