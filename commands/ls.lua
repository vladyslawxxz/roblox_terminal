return {
	name = "ls",
	description = "List contents of the current directory",
	aliases = { "list" },

	execute = function(args, ctx)
		local target = ctx.currentDir()
		
		if #args > 0 then
			local path = table.concat(args, " ")
			local resolved, err = ctx.resolvePath(path)
			if not resolved then
				ctx.printError(err or "Path not found")
				return
			end
			target = resolved
		end

		local children = target:GetChildren()
		
		if #children == 0 then
			ctx.printInfo("(empty directory)")
			return
		end

		for _, child in ipairs(children) do
			local line = child.Name .. " (" .. child.ClassName .. ")"
			ctx.printLine(line)
		end
		
		local msg = string.format("Total: %d item(s)", #children)
		ctx.printInfo(msg)
	end,
}
