return {
	name = "playerlist",
	description = "Shows all players in the server with account age info (--sort=age-up | age-down)",
	aliases = { "pl" },

	execute = function(args, ctx)
		local Players = game:GetService("Players")
		local list = Players:GetPlayers()

		if #list == 0 then
			ctx.printError("No players found")
			return
		end

		local sortMode = nil
		for _, arg in ipairs(args) do
			if arg == "--sort=age-up" then
				sortMode = "age-up"
			elseif arg == "--sort=age-down" then
				sortMode = "age-down"
			end
		end

		if sortMode == "age-up" then
			table.sort(list, function(a, b) return a.AccountAge < b.AccountAge end)
		elseif sortMode == "age-down" then
			table.sort(list, function(a, b) return a.AccountAge > b.AccountAge end)
		end

		local minAge, maxAge = math.huge, -math.huge
		for _, p in ipairs(list) do
			if p.AccountAge < minAge then minAge = p.AccountAge end
			if p.AccountAge > maxAge then maxAge = p.AccountAge end
		end

		local function ageToColor(age)
			local t = 0
			if maxAge ~= minAge then
				t = (age - minAge) / (maxAge - minAge)
			end
			local r = math.floor(59 + (255 - 59) * t)
			local g = math.floor(59 + (255 - 59) * t)
			local b = math.floor(59 + (255 - 59) * t)
			return ctx.createColor(r, g, b)
		end

		ctx.printInfo("=== PLAYER LIST (" .. #list .. ") ===")
		if sortMode then
			ctx.printInfo("Sorted by: " .. sortMode)
		end

		for i, p in ipairs(list) do
			local color = ageToColor(p.AccountAge)
			local line = string.format("  %d. %-20s | %d days old", i, p.Name, p.AccountAge)
			ctx.printColored(line, color)
		end
	end,
}
