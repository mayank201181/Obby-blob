--[[
	SoloMenu.client.lua
	The main menu plus the round-over / course-complete panel.

	Menu view    -> pick a mode: Solo Disaster, Easy Obby, Hard Obby,
	                Endless Obby.
	Result view  -> shown after a disaster round ends or an obby course is
	                finished; has a big "Play Again" that restarts the SAME
	                mode, plus "Back to Menu".

	The menu hides itself when the server confirms a round/course started and
	comes back when it ends.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = GameConfig.Remotes

local PlayAgainRemote = ReplicatedStorage:WaitForChild(Remotes.PlayAgain)
local RoundStartedRemote = ReplicatedStorage:WaitForChild(Remotes.RoundStarted)
local RoundEndedRemote = ReplicatedStorage:WaitForChild(Remotes.RoundEnded)
local ObbyStartRemote = ReplicatedStorage:WaitForChild(Remotes.ObbyStart)
local ObbyEnteredRemote = ReplicatedStorage:WaitForChild(Remotes.ObbyEntered)
local ObbyLeftRemote = ReplicatedStorage:WaitForChild(Remotes.ObbyLeft)
local ObbyFinishedRemote = ReplicatedStorage:WaitForChild(Remotes.ObbyFinished)

-- ---------------------------------------------------------------------------
-- GUI construction
-- ---------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SoloMenuGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(420, 420)
panel.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(0, 24)
title.Size = UDim2.new(1, 0, 0, 44)
title.Font = Enum.Font.GothamBold
title.TextSize = 32
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "Obby Blob"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(20, 70)
subtitle.Size = UDim2.new(1, -40, 0, 40)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 18
subtitle.TextWrapped = true
subtitle.TextColor3 = Color3.fromRGB(200, 205, 220)
subtitle.Text = "Pick a mode!"
subtitle.Parent = panel

local function makeButton(parent, text, color, order)
	local button = Instance.new("TextButton")
	button.Name = text .. "Button"
	button.Size = UDim2.fromOffset(280, 54)
	button.BackgroundColor3 = color
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 22
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.LayoutOrder = order
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	return button
end

local function makeButtonColumn(name)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.new(0, 0, 0, 120)
	frame.Size = UDim2.new(1, 0, 1, -140)
	frame.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = frame
	return frame
end

-- Menu view: one button per mode.
local menuView = makeButtonColumn("MenuView")
local disasterButton = makeButton(menuView, "Solo Disaster", Color3.fromRGB(70, 180, 100), 1)
local easyButton = makeButton(menuView, "Easy Obby", Color3.fromRGB(70, 140, 220), 2)
local hardButton = makeButton(menuView, "Hard Obby", Color3.fromRGB(220, 120, 60), 3)
local endlessButton = makeButton(menuView, "Endless Obby", Color3.fromRGB(160, 90, 220), 4)

-- Result view: play the same mode again, or go back to the menu.
local resultView = makeButtonColumn("ResultView")
resultView.Visible = false
local playAgainButton = makeButton(resultView, "Play Again", Color3.fromRGB(70, 180, 100), 1)
local backToMenuButton = makeButton(resultView, "Back to Menu", Color3.fromRGB(90, 100, 120), 2)

-- ---------------------------------------------------------------------------
-- Behaviour
-- ---------------------------------------------------------------------------
local allModeButtons = { disasterButton, easyButton, hardButton, endlessButton, playAgainButton }
local buttonColors = {}
for _, button in ipairs(allModeButtons) do
	buttonColors[button] = button.BackgroundColor3
end

local locked = false
local lockGeneration = 0

local function setLocked(value)
	locked = value
	for _, button in ipairs(allModeButtons) do
		button.AutoButtonColor = not value
		button.BackgroundColor3 = value and Color3.fromRGB(90, 100, 120) or buttonColors[button]
	end
end

-- Fire a start request; if the server never answers (shouldn't happen), the
-- buttons unlock after a few seconds so the menu can't get stuck.
local function requestStart(fire)
	if locked then
		return
	end
	setLocked(true)
	lockGeneration += 1
	local generation = lockGeneration
	fire()
	task.delay(4, function()
		if screenGui.Enabled and lockGeneration == generation then
			setLocked(false)
		end
	end)
end

local function showMenu(headline, detail)
	title.Text = headline
	subtitle.Text = detail
	menuView.Visible = true
	resultView.Visible = false
	setLocked(false)
	screenGui.Enabled = true
end

-- What "Play Again" should do depends on what just ended.
local playAgainAction = function() end

local function showResult(headline, detail, action)
	title.Text = headline
	subtitle.Text = detail
	playAgainAction = action
	menuView.Visible = false
	resultView.Visible = true
	setLocked(false)
	screenGui.Enabled = true
end

local function hideMenu()
	screenGui.Enabled = false
	setLocked(false)
end

disasterButton.Activated:Connect(function()
	requestStart(function()
		PlayAgainRemote:FireServer()
	end)
end)

local function connectObbyButton(button, mode)
	button.Activated:Connect(function()
		requestStart(function()
			ObbyStartRemote:FireServer(mode)
		end)
	end)
end
connectObbyButton(easyButton, "Easy")
connectObbyButton(hardButton, "Hard")
connectObbyButton(endlessButton, "Endless")

playAgainButton.Activated:Connect(function()
	requestStart(playAgainAction)
end)

backToMenuButton.Activated:Connect(function()
	showMenu("Obby Blob", "Pick a mode!")
end)

-- ---------------------------------------------------------------------------
-- Server events
-- ---------------------------------------------------------------------------
RoundStartedRemote.OnClientEvent:Connect(hideMenu)
ObbyEnteredRemote.OnClientEvent:Connect(hideMenu)

RoundEndedRemote.OnClientEvent:Connect(function(result, disasterName)
	if result == "survived" then
		showResult("You Survived!", "You outlasted the " .. tostring(disasterName) .. ".", function()
			PlayAgainRemote:FireServer()
		end)
	elseif result == "died" then
		showResult("You Got Wiped Out!", "The " .. tostring(disasterName) .. " got you.", function()
			PlayAgainRemote:FireServer()
		end)
	else -- "ready" (just joined)
		showMenu("Obby Blob", "Pick a mode!")
	end
end)

ObbyFinishedRemote.OnClientEvent:Connect(function(mode)
	showResult("Course Complete!", "You beat the " .. tostring(mode) .. " obby!", function()
		ObbyStartRemote:FireServer(mode)
	end)
end)

ObbyLeftRemote.OnClientEvent:Connect(function()
	showMenu("Obby Blob", "Pick a mode!")
end)

-- Show the menu straight away on join; the server's "ready" ping is just a
-- backup in case this script loads late.
showMenu("Obby Blob", "Pick a mode!")
