--[[
	ObbyHud.client.lua
	On-screen HUD while playing an obby course (Easy / Hard / Endless).

	Shows the mode and your current checkpoint, plus:
	  * Restart  -- brings every red platform back and teleports you to the
	               checkpoint you last touched (also bound to the R key)
	  * Quit     -- leave the course and go back to the menu
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = GameConfig.Remotes

local ObbyEnteredRemote = ReplicatedStorage:WaitForChild(Remotes.ObbyEntered)
local ObbyCheckpointRemote = ReplicatedStorage:WaitForChild(Remotes.ObbyCheckpoint)
local ObbyRestartRemote = ReplicatedStorage:WaitForChild(Remotes.ObbyRestart)
local ObbyLeaveRemote = ReplicatedStorage:WaitForChild(Remotes.ObbyLeave)
local ObbyLeftRemote = ReplicatedStorage:WaitForChild(Remotes.ObbyLeft)
local ObbyFinishedRemote = ReplicatedStorage:WaitForChild(Remotes.ObbyFinished)

-- ---------------------------------------------------------------------------
-- GUI construction
-- ---------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ObbyHudGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Hud"
frame.AnchorPoint = Vector2.new(1, 0)
frame.Position = UDim2.new(1, -16, 0, 16)
frame.Size = UDim2.fromOffset(220, 216)
frame.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.Parent = frame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.Parent = frame

local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "ModeLabel"
modeLabel.BackgroundTransparency = 1
modeLabel.Size = UDim2.new(1, -20, 0, 26)
modeLabel.Font = Enum.Font.GothamBold
modeLabel.TextSize = 20
modeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
modeLabel.Text = "Easy Obby"
modeLabel.LayoutOrder = 1
modeLabel.Parent = frame

local checkpointLabel = Instance.new("TextLabel")
checkpointLabel.Name = "CheckpointLabel"
checkpointLabel.BackgroundTransparency = 1
checkpointLabel.Size = UDim2.new(1, -20, 0, 22)
checkpointLabel.Font = Enum.Font.Gotham
checkpointLabel.TextSize = 16
checkpointLabel.TextColor3 = Color3.fromRGB(200, 205, 220)
checkpointLabel.Text = "Checkpoint 1"
checkpointLabel.LayoutOrder = 2
checkpointLabel.Parent = frame

local restartButton = Instance.new("TextButton")
restartButton.Name = "RestartButton"
restartButton.Size = UDim2.fromOffset(190, 48)
restartButton.BackgroundColor3 = Color3.fromRGB(220, 80, 70)
restartButton.AutoButtonColor = true
restartButton.Font = Enum.Font.GothamBold
restartButton.TextSize = 20
restartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
restartButton.Text = "Restart"
restartButton.LayoutOrder = 3
restartButton.Parent = frame

local restartCorner = Instance.new("UICorner")
restartCorner.CornerRadius = UDim.new(0, 10)
restartCorner.Parent = restartButton

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.BackgroundTransparency = 1
hint.Size = UDim2.new(1, -20, 0, 16)
hint.Font = Enum.Font.Gotham
hint.TextSize = 13
hint.TextColor3 = Color3.fromRGB(160, 165, 180)
hint.Text = "(or press R)"
hint.LayoutOrder = 4
hint.Parent = frame

local quitButton = Instance.new("TextButton")
quitButton.Name = "QuitButton"
quitButton.Size = UDim2.fromOffset(190, 36)
quitButton.BackgroundColor3 = Color3.fromRGB(90, 100, 120)
quitButton.AutoButtonColor = true
quitButton.Font = Enum.Font.GothamBold
quitButton.TextSize = 16
quitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
quitButton.Text = "Quit to Menu"
quitButton.LayoutOrder = 5
quitButton.Parent = frame

local quitCorner = Instance.new("UICorner")
quitCorner.CornerRadius = UDim.new(0, 10)
quitCorner.Parent = quitButton

-- ---------------------------------------------------------------------------
-- Behaviour
-- ---------------------------------------------------------------------------
local restartDebounce = false

local function requestRestart()
	if not screenGui.Enabled or restartDebounce then
		return
	end
	restartDebounce = true
	ObbyRestartRemote:FireServer()
	task.delay(0.5, function()
		restartDebounce = false
	end)
end

restartButton.Activated:Connect(requestRestart)

quitButton.Activated:Connect(function()
	ObbyLeaveRemote:FireServer()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		requestRestart()
	end
end)

-- ---------------------------------------------------------------------------
-- Server events
-- ---------------------------------------------------------------------------
ObbyEnteredRemote.OnClientEvent:Connect(function(mode)
	modeLabel.Text = tostring(mode) .. " Obby"
	checkpointLabel.Text = "Checkpoint 1"
	screenGui.Enabled = true
end)

ObbyCheckpointRemote.OnClientEvent:Connect(function(index)
	checkpointLabel.Text = "Checkpoint " .. tostring(index)
end)

ObbyLeftRemote.OnClientEvent:Connect(function()
	screenGui.Enabled = false
end)

ObbyFinishedRemote.OnClientEvent:Connect(function()
	screenGui.Enabled = false
end)
