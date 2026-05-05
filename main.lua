local BASE_URL = "https://raw.githubusercontent.com/vladyslawxxz/roblox_terminal/main/"

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
	BackgroundColor   = Color3.fromRGB(30, 30, 30),
	TitleBarColor     = Color3.fromRGB(50, 50, 50),
	TextColor         = Color3.fromRGB(220, 220, 220),
	ErrorColor        = Color3.fromRGB(255, 100, 100),
	SuccessColor      = Color3.fromRGB(100, 255, 100),
	InfoColor         = Color3.fromRGB(100, 200, 255),
	AccentColor       = Color3.fromRGB(80, 160, 255),
	Font              = Enum.Font.Code,
	TextSize          = 14,
	WindowSize        = Vector2.new(700, 450),
	AnimationDuration = 0.3,
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
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = mainFrame
end

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = CONFIG.TitleBarColor
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = titleBar
	local fix = Instance.new("Frame")
	fix.Size = UDim2.new(1, 0, 0.5, 0)
	fix.Position = UDim2.new(0, 0, 0.5, 0)
	fix.BackgroundColor3 = CONFIG.TitleBarColor
	fix.BorderSizePixel = 0
	fix.Parent = titleBar
end

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -120, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = player.Name .. "@linux: /Workspace"
titleText.TextColor3 = CONFIG.TextColor
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 14
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local function makeWinBtn(color, posX)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 24, 0, 24)
	btn.Position = UDim2.new(1, posX, 0, 4)
	btn.BackgroundColor3 = color
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Parent = titleBar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = btn
	return btn
end

local minimizeBtn = makeWinBtn(Color3.fromRGB(255, 190, 50), -84)
local maximizeBtn = makeWinBtn(Color3.fromRGB(50, 200, 80), -56)
local closeBtn    = makeWinBtn(Color3.fromRGB(255, 80, 80), -28)

local function addIcon(parent, text, size)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.new(0.2, 0.2, 0.2)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = size or 18
	lbl.Parent = parent
	return lbl
end

local minIcon = addIcon(minimizeBtn, "-")
addIcon(maximizeBtn, "□", 14)
addIcon(closeBtn, "×")

local outputFrame = Instance.new("ScrollingFrame")
outputFrame.Name = "Output"
outputFrame.Size = UDim2.new(1, -10, 1, -70)
outputFrame.Position = UDim2.new(0, 5, 0, 37)
outputFrame.BackgroundTransparency = 1
outputFrame.BorderSizePixel = 0
outputFrame.ScrollBarThickness = 6
outputFrame.ScrollBarImageColor3 = CONFIG.AccentColor
outputFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
outputFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
outputFrame.Parent = mainFrame

local outputLayout = Instance.new("UIListLayout")
outputLayout.SortOrder = Enum.SortOrder.LayoutOrder
outputLayout.Padding = UDim.new(0, 2)
outputLayout.Parent = outputFrame

local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, -10, 0, 28)
inputFrame.Position = UDim2.new(0, 5, 1, -33)
inputFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
inputFrame.BorderSizePixel = 0
inputFrame.Parent = mainFrame

do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = inputFrame
end

local promptLabel = Instance.new("TextLabel")
promptLabel.Size = UDim2.new(0, 0, 1, 0)
promptLabel.AutomaticSize = Enum.AutomaticSize.X
promptLabel.BackgroundTransparency = 1
promptLabel.Text = CONFIG.PromptTemplate:gsub("{player}", player.Name)
promptLabel.TextColor3 = CONFIG.AccentColor
promptLabel.Font = CONFIG.Font
promptLabel.TextSize = CONFIG.TextSize
promptLabel.TextXAlignment = Enum.TextXAlignment.Left
promptLabel.Parent = inputFrame

local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(1, -120, 1, 0)
inputBox.Position = UDim2.new(0, 115, 0, 0)
inputBox.BackgroundTransparency = 1
inputBox.Text = ""
inputBox.PlaceholderText = "Enter command..."
inputBox.TextColor3 = CONFIG.TextColor
inputBox.Font = CONFIG.Font
inputBox.TextSize = CONFIG.TextSize
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.ClearTextOnFocus = false
inputBox.Parent = inputFrame

promptLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
	local w = promptLabel.TextBounds.X
	inputBox.Position = UDim2.new(0, w + 10, 0, 0)
	inputBox.Size = UDim2.new(1, -w - 15, 1, 0)
end)
promptLabel.Text = promptLabel.Text

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 50, 0, 50)
toggleBtn.Position = UDim2.new(0, 20, 0, 20)
toggleBtn.BackgroundColor3 = CONFIG.TitleBarColor
toggleBtn.Text = ">_"
toggleBtn.TextColor3 = CONFIG.TextColor
toggleBtn.Font = Enum.Font.Code
toggleBtn.TextSize = 24
toggleBtn.Visible = false
toggleBtn.Parent = screenGui

do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = toggleBtn
	local s = Instance.new("UIStroke")
	s.Color = CONFIG.AccentColor
	s.Thickness = 2
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
local function printSuccess(text) createOutputLine(text, CONFIG.SuccessColor)              end
local function printInfo(text)    createOutputLine(text, CONFIG.InfoColor)                 end
local function printLine(text)    createOutputLine(text)                                   end

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
	inputFrame.Visible = false
	minIcon.Text = "+"
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
		inputFrame.Visible = true
	end)
	minIcon.Text = "-"
end

local function closeTerminal()
	State.isVisible = false
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
		mainFrame.Size = UDim2.new(0, 0, 0, 0)
		tween(mainFrame, {
			Size = UDim2.new(0, CONFIG.WindowSize.X, 0, CONFIG.WindowSize.Y),
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

local Commands = {}

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
	previousDir   = function() return State.previousDir end,
	printColored  = printColored,
	createColor   = createColor,
	commands      = Commands,
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

local function loadCommands()
	printInfo("Loading commands...")

	local manifestSrc = fetch(BASE_URL .. "manifest.lua")
	if not manifestSrc then
		printError("Failed to fetch manifest.lua")
		return
	end

	local manifestFn, err = loadstring(manifestSrc)
	if not manifestFn then
		printError("manifest.lua parse error: " .. tostring(err))
		return
	end

	local ok, manifest = pcall(manifestFn)
	if not ok or type(manifest) ~= "table" then
		printError("manifest.lua returned invalid data")
		return
	end

	local loaded, failed = 0, 0
	for _, name in ipairs(manifest) do
		local url = BASE_URL .. "commands/" .. name .. ".lua"
		local cmd = loadModule(url)
		if cmd and cmd.name and cmd.execute then
			Commands[cmd.name] = cmd
			loaded = loaded + 1
			print("[TERMINAL] Loaded command: " .. cmd.name)
		else
			printError("Failed to load command: " .. name)
			failed = failed + 1
		end
	end

	printSuccess(string.format("Loaded %d command(s)%s",
		loaded,
		failed > 0 and (", errors: " .. failed) or ""
	))
end

inputBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		processCommand(inputBox.Text)
		inputBox.Text = ""
		task.wait(0.05)
		inputBox:CaptureFocus()
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if not inputBox:IsFocused() then return end
	if input.KeyCode == Enum.KeyCode.Up then
		if State.historyIndex > 1 then
			State.historyIndex = State.historyIndex - 1
			inputBox.Text = State.commandHistory[State.historyIndex]
			inputBox.CursorPosition = #inputBox.Text + 1
		end
	elseif input.KeyCode == Enum.KeyCode.Down then
		if State.historyIndex < #State.commandHistory then
			State.historyIndex = State.historyIndex + 1
			inputBox.Text = State.commandHistory[State.historyIndex]
			inputBox.CursorPosition = #inputBox.Text + 1
		elseif State.historyIndex == #State.commandHistory then
			State.historyIndex = State.historyIndex + 1
			inputBox.Text = ""
		end
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
			Size = UDim2.new(0, CONFIG.WindowSize.X, 0, CONFIG.WindowSize.Y),
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

print("[TERMINAL] Ready!")

task.wait(0.3)
printInfo("=== Linux Terminal v2.0 ===")
createOutputLine("Welcome, " .. player.Name .. "!")
createOutputLine("")
loadCommands()
createOutputLine("")
createOutputLine("Type 'help' for a list of commands.")
createOutputLine("")

task.spawn(function()
	task.wait(0.5)
	inputBox:CaptureFocus()
end)
