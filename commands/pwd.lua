return {
	name = "pwd",
	description = "Prints the current directory path",
	aliases = {},

	execute = function(args, ctx)
		ctx.printInfo(ctx.getPathString(ctx.currentDir()))
	end,
}
