return {
	name = "whoami",
	description = "Shows player info (current player or search by name)",
	aliases = { "player", "info" },

	execute = function(args, ctx)
		local Players = game:GetService("Players")
		local targetPlayer = nil
		
		if #args == 0 then
			-- No args, show current player
			targetPlayer = Players.LocalPlayer
		else
			-- Search for player by name (partial match)
			local searchName = table.concat(args, " "):lower()
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr.Name:lower():find(searchName, 1, true) then
					targetPlayer = plr
					break
				end
			end
			
			if not targetPlayer then
				ctx.printError("Player not found: " .. searchName)
				return
			end
		end
		
		-- Format account age nicely
		local accountAge = targetPlayer.AccountAge
		local years = math.floor(accountAge / 365)
		local days = accountAge % 365
		
		local ageStr
		if years > 0 then
			ageStr = string.format("%d year(s), %d day(s)", years, days)
		else
			ageStr = string.format("%d day(s)", days)
		end
		
		ctx.printInfo("=== PLAYER INFO ===")
		ctx.printLine("Name:       " .. targetPlayer.Name)
		ctx.printLine("Display:    " .. targetPlayer.DisplayName)
		ctx.printLine("UserId:     " .. tostring(targetPlayer.UserId))
		ctx.printLine("Account Age: " .. ageStr)
		
		if targetPlayer:FindFirstChild("Character") then
			ctx.printLine("Status:     Online")
		else
			ctx.printLine("Status:     Offline/No Character")
		end
	end,
}
