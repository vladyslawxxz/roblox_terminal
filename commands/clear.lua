return {
	name = "clear",
	description = "Clears the terminal output",
	aliases = { "cls" },

	execute = function(args, ctx)
		ctx.clearConsole()
	end,
}
