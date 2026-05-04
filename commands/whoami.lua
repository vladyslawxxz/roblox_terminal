return {
	name = "whoami",
	description = "Shows current player info",
	aliases = {},

	execute = function(args, ctx)
		local player = game:GetService("Players").LocalPlayer
		ctx.printInfo("=== PLAYER INFO ===")
		ctx.printLine("Name:      " .. player.Name)
		ctx.printLine("Display:   " .. player.DisplayName)
		ctx.printLine("UserId:    " .. tostring(player.UserId))
		ctx.printLine("AccountAge:" .. tostring(player.AccountAge) .. " days")
		ctx.printLine("Dir:       " .. ctx.getPathString(ctx.currentDir()))
	end,
}
