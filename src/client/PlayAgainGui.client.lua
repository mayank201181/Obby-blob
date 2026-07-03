--[[
	PlayAgainGui.client.lua
	Builds the round-end menu for the Solo Disaster game.

	When the server tells us a round ended (survived / died / ready), we show a
	panel with a big button. Pressing it fires PlayAgain, which asks the server
	to start a fresh solo round. The button doubles as "Play" for the very
	first round and "Play Again" afterwards.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local PlayAgainRemote = ReplicatedStorage:WaitForChild(GameConfig.Remotes.PlayAgain)
local RoundStartedRemote = ReplicatedStorage:WaitForChild(GameConfig.Remotes.RoundStarted)
local RoundEndedRemote = ReplicatedStorage:WaitForChild(GameConfig.Remotes.RoundEnded)

-- ---------------------------------------------------------------------------
-- GUI construction
-- ---------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SoloDisasterGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(420, 260)
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
title.Position = UDim2.fromOffset(0, 30)
title.Size = UDim2.new(1, 0, 0, 50)
title.Font = Enum.Font.GothamBold
title.TextSize = 34
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "Solo Disaster"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(0, 90)
subtitle.Size = UDim2.new(1, 0, 0, 40)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 20
subtitle.TextColor3 = Color3.fromRGB(200, 205, 220)
subtitle.Text = "Survive the disaster!"
subtitle.Parent = panel

local button = Instance.new("TextButton")
button.Name = "PlayButton"
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -30)
button.Size = UDim2.fromOffset(240, 64)
button.BackgroundColor3 = Color3.fromRGB(70, 180, 100)
button.AutoButtonColor = true
button.Font = Enum.Font.GothamBold
button.TextSize = 26
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Text = "Play"
button.Parent = panel

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 12)
buttonCorner.Parent = button

-- ---------------------------------------------------------------------------
-- Behaviour
-- ---------------------------------------------------------------------------
local function showMenu(headline, detail, buttonText)
	title.Text = headline
	subtitle.Text = detail
	button.Text = buttonText
	button.Active = true
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(70, 180, 100)
	screenGui.Enabled = true
end

local function hideMenu()
	screenGui.Enabled = false
end

button.Activated:Connect(function()
	-- Prevent double-fires while we wait for the round to start.
	button.Active = false
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(90, 100, 120)
	button.Text = "Starting..."
	PlayAgainRemote:FireServer()
end)

RoundStartedRemote.OnClientEvent:Connect(function(disasterName)
	hideMenu()
end)

RoundEndedRemote.OnClientEvent:Connect(function(result, disasterName)
	if result == "survived" then
		showMenu("You Survived!", "You outlasted the " .. tostring(disasterName) .. ".", "Play Again")
	elseif result == "died" then
		showMenu("You Got Wiped Out!", "The " .. tostring(disasterName) .. " got you.", "Play Again")
	else -- "ready" (first time)
		showMenu("Solo Disaster", "Survive the disaster!", "Play")
	end
end)
