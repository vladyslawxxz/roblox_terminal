return {
	name = "find",
	description = "Search for objects by name in a directory",
	aliases = {},

	execute = function(args, ctx)
		if #args < 1 then
			ctx.printError("Usage: find <name> [dir]")
			return
		end

		local searchName = args[1]
		local dirPath = args[2] or "."
		local dir, err = ctx.resolvePath(dirPath)

		if not dir then
			ctx.printError(err or "Invalid directory")
			return
		end

		local found = {}
		local function search(obj, depth)
			if depth > 10 then return end
			for _, child in ipairs(obj:GetChildren()) do
				if child.Name:lower():find(searchName:lower(), 1, true) then
					table.insert(found, {
						path = ctx.getPathString(child),
						class = child.ClassName,
					})
				end
				search(child, depth + 1)
			end
		end

		search(dir, 0)

		if #found == 0 then
			ctx.printError("No results for: " .. searchName)
		else
			ctx.printSuccess("Found " .. #found .. " result(s):")
			for _, item in ipairs(found) do
				ctx.printLine(string.format("  %-40s [%s]", item.path, item.class))
			end
		end
	end,
}
