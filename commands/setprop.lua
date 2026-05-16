return {
	name = "setprop",
	description = "Set a property of an object. Usage: setprop <path> <property> <value>  (use name:ClassName to disambiguate)",
	aliases = {"sp"},

	execute = function(args, ctx)
		if #args < 3 then
			ctx.printError("Not enough arguments.")
			ctx.printLine("Usage: setprop <path> <property> <value>")
			return
		end

		local path = args[1]
		local property = args[2]
		local valueStr = table.concat(args, " ", 3)

		local obj, err = ctx.resolvePath(path)
		if not obj then
			ctx.printError(err or "Path not found: " .. path)
			return
		end

		local value
		local lowerVal = string.lower(valueStr)

		if lowerVal == "true" then
			value = true
		elseif lowerVal == "false" then
			value = false
		elseif lowerVal == "nil" or lowerVal == "null" then
			value = nil
		elseif tonumber(valueStr) then
			value = tonumber(valueStr)
		elseif string.find(valueStr, ",") and string.match(valueStr, "^[%d%.%-%s,]+$") then
			local nums = {}
			for num in string.gmatch(valueStr, "([%d%.%-]+)") do
				table.insert(nums, tonumber(num))
			end
			if #nums == 3 then
				value = Vector3.new(nums[1], nums[2], nums[3])
			elseif #nums == 4 then
				value = UDim2.new(nums[1], nums[2], nums[3], nums[4])
			elseif #nums == 6 then
				value = CFrame.new(nums[1], nums[2], nums[3]) * CFrame.Angles(math.rad(nums[4]), math.rad(nums[5]), math.rad(nums[6]))
			else
				ctx.printError("Expected 3 (Vector3), 4 (UDim2) or 6 (CFrame) numbers.")
				return
			end
		elseif string.sub(valueStr, 1, 1) == "#" then
			local hex = string.sub(valueStr, 2)
			if #hex == 6 then
				local r = tonumber(string.sub(hex, 1, 2), 16) or 0
				local g = tonumber(string.sub(hex, 3, 4), 16) or 0
				local b = tonumber(string.sub(hex, 5, 6), 16) or 0
				value = Color3.fromRGB(r, g, b)
			else
				ctx.printError("Hex color must be in format #RRGGBB")
				return
			end
		elseif string.find(valueStr, "^Enum%.") then
			local ok, result = pcall(function()
				local parts = {}
				for part in string.gmatch(valueStr, "([^%.]+)") do
					table.insert(parts, part)
				end
				if #parts == 3 then
					return Enum[parts[2]][parts[3]]
				end
				return nil
			end)
			if ok and result then
				value = result
			else
				ctx.printError("Unknown Enum: " .. valueStr)
				return
			end
		else
			value = valueStr
		end

		if property == "Parent" then
			if value == nil then
				obj.Parent = nil
				ctx.printSuccess("Set Parent = nil for " .. ctx.getPathString(obj))
			else
				local newParent, parentErr = ctx.resolvePath(valueStr)
				if not newParent then
					ctx.printError("Parent object not found: " .. (parentErr or valueStr))
					return
				end
				obj.Parent = newParent
				ctx.printSuccess("Moved " .. obj.Name .. " → " .. ctx.getPathString(newParent))
			end
			return
		end

		if value == nil then
			ctx.printError("nil is not supported for regular properties.")
			return
		end

		local ok, setErr = pcall(function()
			obj[property] = value
		end)
		if not ok then
			ctx.printError("Failed to set " .. property .. ": " .. tostring(setErr))
			return
		end

		local valDisplay = tostring(value)
		local valType = typeof(value)
		if valType == "Vector3" then
			valDisplay = string.format("Vector3(%.2f, %.2f, %.2f)", value.X, value.Y, value.Z)
		elseif valType == "Color3" then
			valDisplay = string.format("Color3(%d, %d, %d)", math.floor(value.R * 255), math.floor(value.G * 255), math.floor(value.B * 255))
		elseif valType == "CFrame" then
			local pos = value.Position
			valDisplay = string.format("CFrame(%.2f, %.2f, %.2f)", pos.X, pos.Y, pos.Z)
		elseif valType == "UDim2" then
			valDisplay = string.format("UDim2(%.3f, %d, %.3f, %d)", value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
		end

		ctx.printSuccess("Set " .. property .. " = " .. valDisplay .. " for " .. obj.Name)
	end,
}
