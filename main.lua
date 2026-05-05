local BASE_URL = "https://raw.githubusercontent.com/vladyslawxxx/roblox_terminal/main/"

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then warn("[TERMINAL] player is nil!") return end

local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then warn("[TERMINAL] PlayerGui not found!") return end

print("[TERMINAL] Initializing...")

local CONFIG = {
	PromptTemplate    = "[{player}@linux]: ",
	BackgroundColor   = Color3.fromRGB(17, 17, 17),
	TitleBarColor     = Color3.fromRGB(24, 24, 24),
	TextColor         = Color3.fromRGB(204, 204, 204),
	ErrorColor        = Color3.fromRGB(180, 60, 60),
	SuccessColor      = Color3.fromRGB(170, 170, 170),
	InfoColor         = Color3.fromRGB(102, 102, 102),
	AccentColor       = Color3.fromRGB(204, 204, 204),
	MutedColor        = Color3.fromRGB(68, 68, 68),
	BorderColor       = Color3.fromRGB(42, 42, 42),
	Font              = Enum.Font.Code,
	TextSize          = 13,
	WindowSize        = Vector2.new(700, 460),
	AnimationDuration = 0.25,
}

local State = {
	isVisible      = true,
	isMinimized    = false,
	currentDir     = workspace,
	previousDir    = workspace,
	commandHistory = {},
	historyIndex   = 0,
	outputLines    = {},
}

local function fetch(url)
	local ok, result = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok then
		warn("[TERMINAL] HttpGet failed: " .. url .. "\n" .. tostring(result))
		return nil
	end
	return result
end

local function loadModule(url)
	local src = fetch(url)
	if not src then return nil end
	local fn, err = loadstring(src)
	if not fn then
		warn("[TERMINAL] loadstring error (" .. url .. "): " .. tostring(err))
		return nil
	end
	local ok, module = pcall(fn)
	if not ok then
		warn("[TERMINAL] module error (" .. url .. "): " .. tostring(module))
		return nil
	end
	return module
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LinuxTerminal"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "TerminalWindow"
mainFrame.Size = UDim2.new(0, CONFIG.WindowSize.X, 0, CONFIG.WindowSize.Y)
mainFrame.Position = UDim2.new(0.5, -CONFIG.WindowSize.X / 2, 0.5, -CONFIG.WindowSize.Y / 2)
mainFrame.BackgroundColor3 = CONFIG.BackgroundColor
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = mainFrame
	local s = Instance.new("UIStroke")
	s.Color = CONFIG.BorderColor
	s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = mainFrame
end

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3 = CONFIG.TitleBarColor
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = titleBar
	local fix = Instance.new("Frame")
	fix.Size = UDim2.new(1, 0, 0.5, 0)
	fix.Position = UDim2.new(0, 0, 0.5, 0)
	fix.BackgroundColor3 = CONFIG.TitleBarColor
	fix.BorderSizePixel = 0
	fix.Parent = titleBar
	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(1, 0, 0, 1)
	sep.Position = UDim2.new(0, 0, 1, -1)
	sep.BackgroundColor3 = CONFIG.BorderColor
	sep.BorderSizePixel = 0
	sep.Parent = titleBar
end

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -120, 1, 0)
titleText.Position = UDim2.new(0, 0, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = player.Name .. "@linux"
titleText.TextColor3 = CONFIG.MutedColor
titleText.Font = Enum.Font.Code
titleText.TextSize = 12
titleText.TextXAlignment = Enum.TextXAlignment.Center
titleText.Parent = titleBar

local function makeWinBtn(posX, icon)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 28, 0, 28)
	btn.Position = UDim2.new(0, posX, 0.5, -14)
	btn.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = titleBar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = icon
	lbl.TextColor3 = Color3.fromRGB(90, 90, 90)
	lbl.Font = Enum.Font.Code
	lbl.TextSize = 16
	lbl.Parent = btn
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
		lbl.TextColor3 = Color3.fromRGB(90, 90, 90)
	end)
	return btn, lbl
end

local minimizeBtn = makeWinBtn(10, "-")
local maximizeBtn = makeWinBtn(44, "[]")
local closeBtn    = makeWinBtn(78, "x")

local outputFrame = Instance.new("ScrollingFrame")
outputFrame.Name = "Output"
outputFrame.Size = UDim2.new(1, -32, 1, -88)
outputFrame.Position = UDim2.new(0, 16, 0, 50)
outputFrame.BackgroundTransparency = 1
outputFrame.BorderSizePixel = 0
outputFrame.ScrollBarThickness = 3
outputFrame.ScrollBarImageColor3 = CONFIG.BorderColor
outputFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
outputFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
outputFrame.Parent = mainFrame

local outputLayout = Instance.new("UIListLayout")
outputLayout.SortOrder = Enum.SortOrder.LayoutOrder
outputLayout.Padding = UDim.new(0, 1)
outputLayout.Parent = outputFrame

local inputSep = Instance.new("Frame")
inputSep.Size = UDim2.new(1, 0, 0, 1)
inputSep.Position = UDim2.new(0, 0, 1, -38)
inputSep.BackgroundColor3 = CONFIG.BorderColor
inputSep.BorderSizePixel = 0
inputSep.Parent = mainFrame

local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, 0, 0, 38)
inputFrame.Position = UDim2.new(0, 0, 1, -38)
inputFrame.BackgroundColor3 = CONFIG.TitleBarColor
inputFrame.BorderSizePixel = 0
inputFrame.Parent = mainFrame

do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = inputFrame
	local fix = Instance.new("Frame")
	fix.Size = UDim2.new(1, 0, 0.5, 0)
	fix.Position = UDim2.new(0, 0, 0, 0)
	fix.BackgroundColor3 = CONFIG.TitleBarColor
	fix.BorderSizePixel = 0
	fix.Parent = inputFrame
end

local promptLabel = Instance.new("TextLabel")
promptLabel.Size = UDim2.new(0, 0, 1, 0)
promptLabel.Position = UDim2.new(0, 16, 0, 0)
promptLabel.AutomaticSize = Enum.AutomaticSize.X
promptLabel.BackgroundTransparency = 1
promptLabel.Text = CONFIG.PromptTemplate:gsub("{player}", player.Name)
promptLabel.TextColor3 = CONFIG.MutedColor
promptLabel.Font = CONFIG.Font
promptLabel.TextSize = CONFIG.TextSize
promptLabel.TextXAlignment = Enum.TextXAlignment.Left
promptLabel.Parent = inputFrame

local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(1, -120, 1, 0)
inputBox.Position = UDim2.new(0, 115, 0, 0)
inputBox.BackgroundTransparency = 1
inputBox.Text = ""
inputBox.PlaceholderText = "type a command..."
inputBox.PlaceholderColor3 = CONFIG.MutedColor
inputBox.TextColor3 = CONFIG.TextColor
inputBox.Font = CONFIG.Font
inputBox.TextSize = CONFIG.TextSize
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.ClearTextOnFocus = false
inputBox.Parent = inputFrame

promptLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
	local w = promptLabel.TextBounds.X
	inputBox.Position = UDim2.new(0, 16 + w + 6, 0, 0)
	inputBox.Size = UDim2.new(1, -(16 + w + 22), 1, 0)
end)
promptLabel.Text = promptLabel.Text

local MAX_SUGGESTIONS   = 7
local autocompleteItems = {}
local acSelectedIndex   = 0
local acCurrentMatches  = {}

local acFrame = Instance.new("Frame")
acFrame.Name             = "AutocompleteMenu"
acFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
acFrame.BorderSizePixel  = 0
acFrame.Visible          = false
acFrame.ZIndex           = 50
acFrame.ClipsDescendants = false
acFrame.Parent           = mainFrame

do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = acFrame
	local stroke = Instance.new("UIStroke")
	stroke.Color           = Color3.fromRGB(50, 50, 50)
	stroke.Thickness       = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent          = acFrame
end

local acList = Instance.new("UIListLayout")
acList.SortOrder = Enum.SortOrder.LayoutOrder
acList.Padding   = UDim.new(0, 0)
acList.Parent    = acFrame

local acPad = Instance.new("UIPadding")
acPad.PaddingTop    = UDim.new(0, 4)
acPad.PaddingBottom = UDim.new(0, 4)
acPad.Parent        = acFrame

local ITEM_H = 28
local MENU_W = 260

local function clearAcItems()
	for _, f in ipairs(autocompleteItems) do f:Destroy() end
	autocompleteItems = {}
	acSelectedIndex   = 0
end

local function updateAcSelection()
	for i, item in ipairs(autocompleteItems) do
		local sel = (i == acSelectedIndex)
		TweenService:Create(item, TweenInfo.new(0.08), {
			BackgroundColor3 = sel and Color3.fromRGB(38, 38, 38) or Color3.fromRGB(20, 20, 20)
		}):Play()
		local nl = item:FindFirstChild("Name")
		local dl = item:FindFirstChild("Desc")
		if nl then
			nl.TextColor3 = sel and Color3.fromRGB(210, 210, 210) or Color3.fromRGB(130, 130, 130)
		end
		if dl then
			dl.TextColor3 = sel and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(52, 52, 52)
		end
	end
end

local function hideAc()
	acFrame.Visible  = false
	clearAcItems()
	acCurrentMatches = {}
end

local function buildAcItem(i, cmdName, cmdDesc, query)
	local item = Instance.new("Frame")
	item.Name             = "AcItem_" .. i
	item.Size             = UDim2.new(0, MENU_W, 0, ITEM_H)
	item.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	item.BorderSizePixel  = 0
	item.ZIndex           = 51
	item.LayoutOrder      = i
	item.Parent           = acFrame

	if i > 1 then
		local div = Instance.new("Frame")
		div.Size             = UDim2.new(1, -20, 0, 1)
		div.Position         = UDim2.new(0, 10, 0, 0)
		div.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		div.BorderSizePixel  = 0
		div.ZIndex           = 52
		div.Parent           = item
	end

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft  = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent       = item

	local highlighted = ""
	local lname = cmdName:lower()
	local lq    = query:lower()
	local s, e  = lname:find(lq, 1, true)
	if s then
		highlighted = cmdName:sub(1, s - 1)
			.. '<font color="rgb(180,180,255)">'
			.. cmdName:sub(s, e)
			.. '</font>'
			.. cmdName:sub(e + 1)
	else
		highlighted = cmdName
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name                 = "Name"
	nameLabel.Size                 = UDim2.new(0.55, 0, 1, 0)
	nameLabel.Position             = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.RichText             = true
	nameLabel.Text                 = highlighted
	nameLabel.TextColor3           = Color3.fromRGB(130, 130, 130)
	nameLabel.Font                 = CONFIG.Font
	nameLabel.TextSize             = 12
	nameLabel.TextXAlignment       = Enum.TextXAlignment.Left
	nameLabel.ZIndex               = 52
	nameLabel.Parent               = item

	local descLabel = Instance.new("TextLabel")
	descLabel.Name                 = "Desc"
	descLabel.Size                 = UDim2.new(0.45, -4, 1, 0)
	descLabel.Position             = UDim2.new(0.55, 4, 0, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Text                 = cmdDesc or ""
	descLabel.TextColor3           = Color3.fromRGB(52, 52, 52)
	descLabel.Font                 = CONFIG.Font
	descLabel.TextSize             = 11
	descLabel.TextXAlignment       = Enum.TextXAlignment.Left
	descLabel.TextTruncate         = Enum.TextTruncate.AtEnd
	descLabel.ZIndex               = 52
	descLabel.Parent               = item

	table.insert(autocompleteItems, item)
	return item
end

local function showAc(matches, query)
	clearAcItems()
	if #matches == 0 then
		acFrame.Visible = false
		return
	end
	for i, m in ipairs(matches) do
		buildAcItem(i, m.name, m.desc, query)
	end
	local totalH = #matches * ITEM_H + 8
	acFrame.Size = UDim2.new(0, MENU_W, 0, totalH)
	local inputAbsY = inputFrame.AbsolutePosition.Y
	local inputAbsX = inputFrame.AbsolutePosition.X
	local mainAbsY  = mainFrame.AbsolutePosition.Y
	local mainAbsX  = mainFrame.AbsolutePosition.X
	local relX = inputAbsX - mainAbsX + 12
	local relY = inputAbsY - mainAbsY - totalH - 6
	acFrame.Position = UDim2.new(0, relX, 0, relY)
	acFrame.Visible  = true
end

local Commands = {}

local function getMatches(query)
	if not query or query == "" then return {} end
	local results = {}
	local q = query:lower()
	for name, cmd in pairs(Commands) do
		if name:lower():find(q, 1, true) then
			table.insert(results, { name = name, desc = cmd.description or "" })
		end
		if cmd.aliases then
			for _, alias in ipairs(cmd.aliases) do
				if alias:lower():find(q, 1, true) then
					local dup = false
					for _, r in ipairs(results) do
						if r.name == alias then dup = true break end
					end
					if not dup then
						table.insert(results, { name = alias, desc = cmd.description or "" })
					end
				end
			end
		end
	end
	table.sort(results, function(a, b) return a.name < b.name end)
	if #results > MAX_SUGGESTIONS then
		local trimmed = {}
		for i = 1, MAX_SUGGESTIONS do trimmed[i] = results[i] end
		return trimmed
	end
	return results
end

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
	local text = inputBox.Text
	if text == "" or text:find(" ") then
		hideAc()
		return
	end
	local matches = getMatches(text)
	acCurrentMatches = matches
	acSelectedIndex  = 0
	showAc(matches, text)
end)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 44, 0, 44)
toggleBtn.Position = UDim2.new(0, 16, 0, 16)
toggleBtn.BackgroundColor3 = CONFIG.TitleBarColor
toggleBtn.Text = ">_"
toggleBtn.TextColor3 = CONFIG.MutedColor
toggleBtn.Font = Enum.Font.Code
toggleBtn.TextSize = 20
toggleBtn.Visible = false
toggleBtn.Parent = screenGui

do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = toggleBtn
	local s = Instance.new("UIStroke")
	s.Color = CONFIG.BorderColor
	s.Thickness = 1
	s.Parent = toggleBtn
end

print("[TERMINAL] GUI created")

local function createOutputLine(text, color)
	color = color or CONFIG.TextColor
	local line = Instance.new("TextLabel")
	line.Size = UDim2.new(1, -10, 0, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.BackgroundTransparency = 1
	line.Text = text
	line.TextColor3 = color
	line.Font = CONFIG.Font
	line.TextSize = CONFIG.TextSize
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.TextWrapped = true
	line.Parent = outputFrame
	table.insert(State.outputLines, line)
	RunService.Heartbeat:Wait()
	outputFrame.CanvasPosition = Vector2.new(0, outputFrame.AbsoluteCanvasSize.Y)
	return line
end

local function printError(text)          createOutputLine("[ERROR] " .. text, CONFIG.ErrorColor) end
local function printColored(text, color) createOutputLine(text, color)                           end
local function createColor(r, g, b)      return Color3.fromRGB(r, g, b)                          end
local function printSuccess(text) createOutputLine(text, CONFIG.SuccessColor) end
local function printInfo(text)    createOutputLine(text, CONFIG.InfoColor)    end
local function printLine(text)    createOutputLine(text)                      end

local function clearConsole()
	for _, line in ipairs(State.outputLines) do line:Destroy() end
	State.outputLines = {}
end

local function getPathString(obj)
	if obj == game then return "/" end
	local path = obj.Name
	local current = obj.Parent
	while current and current ~= game do
		path = current.Name .. "/" .. path
		current = current.Parent
	end
	return "/" .. path
end

local function resolvePath(pathStr)
	if not pathStr or pathStr == "" or pathStr == "/" then return game end
	local current = State.currentDir
	if pathStr:sub(1, 1) == "/" then
		current = game
		pathStr = pathStr:sub(2)
	end
	for part in pathStr:gmatch("[^/]+") do
		if part == ".." then
			current = current.Parent
			if not current then return nil, "Invalid path: reached root" end
		elseif part ~= "." then
			local found = current:FindFirstChild(part)
			if not found then return nil, "Path not found: " .. part end
			current = found
		end
	end
	return current
end

local function updatePrompt()
	titleText.Text = player.Name .. "@linux: " .. getPathString(State.currentDir)
end

local function tween(object, props, duration)
	duration = duration or CONFIG.AnimationDuration
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local tw = TweenService:Create(object, info, props)
	tw:Play()
	return tw
end

local function minimizeTerminal()
	if State.isMinimized then return end
	State.isMinimized = true
	tween(mainFrame, {
		Size = UDim2.new(0, CONFIG.WindowSize.X, 0, 52),
		Position = UDim2.new(
			mainFrame.Position.X.Scale, mainFrame.Position.X.Offset,
			mainFrame.Position.Y.Scale, mainFrame.Position.Y.Offset + CONFIG.WindowSize.Y - 32
		),
	})
	outputFrame.Visible = false
	inputFrame.Visible  = false
end

local function restoreTerminal()
	if not State.isMinimized then return end
	State.isMinimized = false
	tween(mainFrame, {
		Size = UDim2.new(0, CONFIG.WindowSize.X, 0, CONFIG.WindowSize.Y),
		Position = UDim2.new(
			mainFrame.Position.X.Scale, mainFrame.Position.X.Offset,
			mainFrame.Position.Y.Scale, mainFrame.Position.Y.Offset - CONFIG.WindowSize.Y + 32
		),
	})
	task.delay(CONFIG.AnimationDuration * 0.5, function()
		outputFrame.Visible = true
		inputFrame.Visible  = true
	end)
end

local function closeTerminal()
	State.isVisible = false
	hideAc()
	tween(mainFrame, {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(
			mainFrame.Position.X.Scale, mainFrame.Position.X.Offset + (CONFIG.WindowSize.X) / 2,
			mainFrame.Position.Y.Scale, mainFrame.Position.Y.Offset + (CONFIG.WindowSize.Y) / 2
		),
	})
	task.delay(CONFIG.AnimationDuration, function()
		mainFrame.Visible = false
		toggleBtn.Visible = true
		tween(toggleBtn, { Size = UDim2.new(0, 50, 0, 50), BackgroundTransparency = 0 })
	end)
end

local function openTerminal()
	if State.isVisible then return end
	State.isVisible = true
	tween(toggleBtn, { Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1 })
	task.delay(CONFIG.AnimationDuration, function()
		toggleBtn.Visible = false
		mainFrame.Visible = true
		mainFrame.Size    = UDim2.new(0, 0, 0, 0)
		tween(mainFrame, {
			Size     = UDim2.new(0, CONFIG.WindowSize.X, 0, CONFIG.WindowSize.Y),
			Position = UDim2.new(0.5, -(CONFIG.WindowSize.X) / 2, 0.5, -(CONFIG.WindowSize.Y) / 2),
		})
	end)
end

local dragging, dragStart, startPos = false, nil, nil

titleBar.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging  = true
		dragStart = input.Position
		startPos  = mainFrame.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local ctx = {
	printError    = printError,
	printSuccess  = printSuccess,
	printInfo     = printInfo,
	printLine     = printLine,
	clearConsole  = clearConsole,
	getPathString = getPathString,
	resolvePath   = resolvePath,
	currentDir    = function() return State.currentDir end,
	setCurrentDir = function(dir)
		State.previousDir = State.currentDir
		State.currentDir  = dir
		updatePrompt()
	end,
	previousDir  = function() return State.previousDir end,
	printColored = printColored,
	createColor  = createColor,
	commands     = Commands,
}

local function splitArgs(str)
	local args, current, inQuotes = {}, "", false
	for i = 1, #str do
		local ch = str:sub(i, i)
		if ch == '"' then
			inQuotes = not inQuotes
		elseif ch == " " and not inQuotes then
			if #current > 0 then
				table.insert(args, current)
				current = ""
			end
		else
			current = current .. ch
		end
	end
	if #current > 0 then table.insert(args, current) end
	return args
end

local function processCommand(input)
	if not input or input == "" then return end
	createOutputLine(CONFIG.PromptTemplate:gsub("{player}", player.Name) .. input, CONFIG.AccentColor)
	table.insert(State.commandHistory, input)
	State.historyIndex = #State.commandHistory + 1
	local args    = splitArgs(input)
	local cmdName = args[1]:lower()
	table.remove(args, 1)
	local cmd = Commands[cmdName]
	if not cmd then
		for _, c in pairs(Commands) do
			if c.aliases then
				for _, alias in ipairs(c.aliases) do
					if alias == cmdName then cmd = c break end
				end
			end
			if cmd then break end
		end
	end
	if cmd then
		local ok, err = pcall(function() cmd.execute(args, ctx) end)
		if not ok then printError("Execution error: " .. tostring(err)) end
	else
		printError("Unknown command: '" .. cmdName .. "'. Type 'help' for a list of commands.")
	end
	createOutputLine("")
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if not inputBox:IsFocused() then return end

	if input.KeyCode == Enum.KeyCode.Tab then
		if acFrame.Visible and #acCurrentMatches > 0 then
			local idx = acSelectedIndex > 0 and acSelectedIndex or 1
			inputBox.Text = acCurrentMatches[idx].name
			inputBox.CursorPosition = #inputBox.Text + 1
			hideAc()
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.Up then
		if acFrame.Visible and #autocompleteItems > 0 then
			if acSelectedIndex <= 1 then
				acSelectedIndex = #autocompleteItems
			else
				acSelectedIndex = acSelectedIndex - 1
			end
			updateAcSelection()
		else
			if State.historyIndex > 1 then
				State.historyIndex = State.historyIndex - 1
				inputBox.Text = State.commandHistory[State.historyIndex]
				inputBox.CursorPosition = #inputBox.Text + 1
			end
		end
	elseif input.KeyCode == Enum.KeyCode.Down then
		if acFrame.Visible and #autocompleteItems > 0 then
			if acSelectedIndex >= #autocompleteItems then
				acSelectedIndex = 1
			else
				acSelectedIndex = acSelectedIndex + 1
			end
			updateAcSelection()
		else
			if State.historyIndex < #State.commandHistory then
				State.historyIndex = State.historyIndex + 1
				inputBox.Text = State.commandHistory[State.historyIndex]
				inputBox.CursorPosition = #inputBox.Text + 1
			elseif State.historyIndex == #State.commandHistory then
				State.historyIndex = State.historyIndex + 1
				inputBox.Text = ""
			end
		end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		hideAc()
	end
end)

inputBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		if acFrame.Visible and acSelectedIndex > 0 and acCurrentMatches[acSelectedIndex] then
			inputBox.Text = acCurrentMatches[acSelectedIndex].name
			inputBox.CursorPosition = #inputBox.Text + 1
			hideAc()
			task.wait(0.05)
			inputBox:CaptureFocus()
		else
			hideAc()
			processCommand(inputBox.Text)
			inputBox.Text = ""
			task.wait(0.05)
			inputBox:CaptureFocus()
		end
	else
		task.delay(0.15, function()
			if not inputBox:IsFocused() then hideAc() end
		end)
	end
end)

minimizeBtn.MouseButton1Click:Connect(function()
	if State.isMinimized then restoreTerminal() else minimizeTerminal() end
end)

maximizeBtn.MouseButton1Click:Connect(function()
	if mainFrame.Size.Y.Offset == CONFIG.WindowSize.Y then
		tween(mainFrame, { Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0) })
		tween(mainFrame, { Size = UDim2.new(1, -20, 1, -20) })
	else
		tween(mainFrame, {
			Size     = UDim2.new(0, CONFIG.WindowSize.X, 0, CONFIG.WindowSize.Y),
			Position = UDim2.new(0.5, -(CONFIG.WindowSize.X) / 2, 0.5, -(CONFIG.WindowSize.Y) / 2),
		})
		tween(mainFrame, { Size = UDim2.new(0, CONFIG.WindowSize.X, 0, CONFIG.WindowSize.Y) })
	end
end)

closeBtn.MouseButton1Click:Connect(closeTerminal)
toggleBtn.MouseButton1Click:Connect(openTerminal)

if UserInputService.TouchEnabled then
	toggleBtn.Size = UDim2.new(0, 60, 0, 60)
end

local function loadCommandsWithSplash(onDone)
	local SW = CONFIG.WindowSize.X / 2
	local SH = CONFIG.WindowSize.Y / 2

	local splash = Instance.new("Frame")
	splash.Name                = "SplashScreen"
	splash.Size                = UDim2.new(0, 0, 0, 0)
	splash.Position            = UDim2.new(0.5, 0, 0.5, 0)
	splash.AnchorPoint         = Vector2.new(0.5, 0.5)
	splash.BackgroundColor3    = Color3.fromRGB(17, 17, 17)
	splash.BorderSizePixel     = 0
	splash.BackgroundTransparency = 1
	splash.ZIndex              = 20
	splash.Parent              = screenGui
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = splash
		local s = Instance.new("UIStroke")
		s.Color            = Color3.fromRGB(42, 42, 42)
		s.Thickness        = 1
		s.ApplyStrokeMode  = Enum.ApplyStrokeMode.Border
		s.ZIndex           = 21
		s.Parent           = splash
	end

	local wordLabel = Instance.new("TextLabel")
	wordLabel.Size               = UDim2.new(1, -40, 0, 22)
	wordLabel.Position           = UDim2.new(0, 20, 0.5, -42)
	wordLabel.BackgroundTransparency = 1
	wordLabel.Text               = "Linux Terminal"
	wordLabel.TextColor3         = Color3.fromRGB(180, 180, 180)
	wordLabel.TextTransparency   = 1
	wordLabel.Font               = Enum.Font.Code
	wordLabel.TextSize           = 16
	wordLabel.ZIndex             = 21
	wordLabel.Parent             = splash

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size               = UDim2.new(1, -40, 0, 14)
	statusLabel.Position           = UDim2.new(0, 20, 0.5, -14)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text               = "initializing..."
	statusLabel.TextColor3         = Color3.fromRGB(60, 60, 60)
	statusLabel.TextTransparency   = 1
	statusLabel.Font               = Enum.Font.Code
	statusLabel.TextSize           = 11
	statusLabel.ZIndex             = 21
	statusLabel.Parent             = splash

	local barBg = Instance.new("Frame")
	barBg.Size               = UDim2.new(1, -40, 0, 5)
	barBg.Position           = UDim2.new(0, 20, 0.5, 10)
	barBg.BackgroundColor3   = Color3.fromRGB(30, 30, 30)
	barBg.BackgroundTransparency = 1
	barBg.BorderSizePixel    = 0
	barBg.ZIndex             = 21
	barBg.Parent             = splash
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = barBg
	end

	local barFill = Instance.new("Frame")
	barFill.Size               = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3   = Color3.fromRGB(80, 160, 255)
	barFill.BackgroundTransparency = 1
	barFill.BorderSizePixel    = 0
	barFill.ClipsDescendants   = true
	barFill.ZIndex             = 22
	barFill.Parent             = barBg
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = barFill
	end

	local shimmer = Instance.new("Frame")
	shimmer.Size               = UDim2.new(0, 50, 1, 0)
	shimmer.Position           = UDim2.new(0, -50, 0, 0)
	shimmer.BackgroundColor3   = Color3.fromRGB(160, 210, 255)
	shimmer.BackgroundTransparency = 0.55
	shimmer.BorderSizePixel    = 0
	shimmer.ZIndex             = 23
	shimmer.Parent             = barFill
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = shimmer
	end

	local function setProgress(t, label)
		statusLabel.Text = label
		local info = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		TweenService:Create(barFill, info, { Size = UDim2.new(t, 0, 1, 0) }):Play()
	end

	local shimmerRunning = true
	task.spawn(function()
		while shimmerRunning do
			local w = barFill.Size.X.Scale
			if w > 0.05 then
				shimmer.Position = UDim2.new(0, -50, 0, 0)
				local dur = math.max(0.4, w * 0.7)
				TweenService:Create(shimmer,
					TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ Position = UDim2.new(1, 0, 0, 0) }
				):Play()
				task.wait(dur + 0.2)
			else
				task.wait(0.1)
			end
		end
	end)

	local appearInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(splash,      appearInfo, { Size = UDim2.new(0, SW, 0, SH), BackgroundTransparency = 0 }):Play()
	task.wait(0.05)
	TweenService:Create(wordLabel,   appearInfo, { TextTransparency = 0 }):Play()
	TweenService:Create(statusLabel, appearInfo, { TextTransparency = 0 }):Play()
	TweenService:Create(barBg,       appearInfo, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(barFill,     appearInfo, { BackgroundTransparency = 0 }):Play()
	task.wait(0.45)

	setProgress(0.05, "fetching manifest...")
	task.wait(0.1)

	local manifestSrc = fetch(BASE_URL .. "manifest.lua")
	if not manifestSrc then
		statusLabel.Text      = "error: failed to fetch manifest"
		statusLabel.TextColor3 = Color3.fromRGB(180, 60, 60)
		shimmerRunning = false
		task.wait(2)
		splash:Destroy()
		return
	end

	local manifestFn, parseErr = loadstring(manifestSrc)
	if not manifestFn then
		statusLabel.Text      = "error: " .. tostring(parseErr)
		statusLabel.TextColor3 = Color3.fromRGB(180, 60, 60)
		shimmerRunning = false
		task.wait(2)
		splash:Destroy()
		return
	end

	local ok, manifest = pcall(manifestFn)
	if not ok or type(manifest) ~= "table" then
		statusLabel.Text      = "error: invalid manifest"
		statusLabel.TextColor3 = Color3.fromRGB(180, 60, 60)
		shimmerRunning = false
		task.wait(2)
		splash:Destroy()
		return
	end

	local total = #manifest
	local loaded, failed = 0, 0

	for i, name in ipairs(manifest) do
		setProgress(0.1 + (i / total) * 0.85, "loading " .. name .. "...")
		task.wait(0.05)
		local cmd = loadModule(BASE_URL .. "commands/" .. name .. ".lua")
		if cmd and cmd.name and cmd.execute then
			Commands[cmd.name] = cmd
			loaded = loaded + 1
			print("[TERMINAL] Loaded command: " .. cmd.name)
		else
			failed = failed + 1
		end
	end

	setProgress(1, "loaded " .. loaded .. " command(s)")
	shimmerRunning = false
	task.wait(0.6)

	local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	TweenService:Create(splash,      fadeInfo, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(wordLabel,   fadeInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(statusLabel, fadeInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(barBg,       fadeInfo, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(barFill,     fadeInfo, { BackgroundTransparency = 1 }):Play()
	task.wait(0.35)
	splash:Destroy()

	if onDone then onDone() end
end

print("[TERMINAL] Ready!")

mainFrame.Visible = false

task.wait(0.3)

loadCommandsWithSplash(function()
	createOutputLine("Linux Terminal v2.0", Color3.fromRGB(68, 68, 68))
	createOutputLine("type 'help' for a list of commands.", Color3.fromRGB(68, 68, 68))
	createOutputLine("")
	mainFrame.Visible = true
	mainFrame.BackgroundTransparency = 1
	for _, child in ipairs(mainFrame:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
			child.TextTransparency = 1
		end
		if child:IsA("Frame") or child:IsA("ScrollingFrame") then
			child.BackgroundTransparency = 1
		end
	end
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(mainFrame, tweenInfo, { BackgroundTransparency = 0 }):Play()
	task.wait(0.05)
	for _, child in ipairs(mainFrame:GetDescendants()) do
		if child:IsA("Frame") and child ~= mainFrame then
			TweenService:Create(child, tweenInfo, { BackgroundTransparency = 0 }):Play()
		end
		if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
			TweenService:Create(child, tweenInfo, { TextTransparency = 0 }):Play()
		end
	end
	task.wait(0.5)
	inputBox:CaptureFocus()
end)
