return {
	name = "help",
	description = "Shows a list of all available commands",
	aliases = { "?" },

	execute = function(args, ctx)
		ctx.printInfo("=== TERMINAL HELP ===")

		local sorted = {}
		for _, cmd in pairs(ctx.commands) do
			table.insert(sorted, cmd)
		end
		table.sort(sorted, function(a, b) return a.name < b.name end)

		for _, cmd in ipairs(sorted) do
			local aliases = ""
			if cmd.aliases and #cmd.aliases > 0 then
				aliases = " (" .. table.concat(cmd.aliases, ", ") .. ")"
			end
			ctx.printLine(string.format("  %-12s - %s%s", cmd.name, cmd.description, aliases))
		end

		ctx.printLine("")
		ctx.printLine("Total commands: " .. #sorted)
	end,
}
