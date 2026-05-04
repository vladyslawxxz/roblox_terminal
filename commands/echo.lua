return {
	name = "echo",
	description = "Prints text to the terminal",
	aliases = {},

	execute = function(args, ctx)
		if #args == 0 then
			ctx.printLine("")
			return
		end
		ctx.printLine(table.concat(args, " "))
	end,
}
