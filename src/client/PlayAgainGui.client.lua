-- Round-end menu (one big Play / Play Again button), maths question prompt,
-- and instant feedback. Renders only — every decision comes from the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local remotes = {}
for _, name in GameConfig.Remotes do
	remotes[name] = ReplicatedStorage:WaitForChild(name)
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SoloDisasterGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Menu: big, friendly, one button.
local menu = Instance.new("Frame")
menu.Size = UDim2.fromScale(0.4, 0.35)
menu.Position = UDim2.fromScale(0.3, 0.3)
menu.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
menu.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.35)
title.BackgroundTransparency = 1
title.TextScaled = true
title.Font = Enum.Font.FredokaOne
title.TextColor3 = Color3.fromRGB(60, 60, 90)
title.Text = "Ready?"
title.Parent = menu

local detail = Instance.new("TextLabel")
detail.Size = UDim2.fromScale(1, 0.25)
detail.Position = UDim2.fromScale(0, 0.35)
detail.BackgroundTransparency = 1
detail.TextScaled = true
detail.Font = Enum.Font.GothamMedium
detail.TextColor3 = Color3.fromRGB(90, 90, 120)
detail.Text = "Dodge the flood. Answer sums to push it back!"
detail.Parent = menu

local button = Instance.new("TextButton")
button.Size = UDim2.fromScale(0.6, 0.28)
button.Position = UDim2.fromScale(0.2, 0.65)
button.BackgroundColor3 = Color3.fromRGB(90, 200, 120)
button.TextScaled = true
button.Font = Enum.Font.FredokaOne
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Text = "Play"
button.Parent = menu

-- Question prompt: hidden until the server asks.
local questionFrame = Instance.new("Frame")
questionFrame.Size = UDim2.fromScale(0.32, 0.22)
questionFrame.Position = UDim2.fromScale(0.34, 0.05)
questionFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
questionFrame.Visible = false
questionFrame.Parent = screenGui

local questionLabel = Instance.new("TextLabel")
questionLabel.Size = UDim2.fromScale(1, 0.45)
questionLabel.BackgroundTransparency = 1
questionLabel.TextScaled = true
questionLabel.Font = Enum.Font.FredokaOne
questionLabel.TextColor3 = Color3.fromRGB(60, 60, 90)
questionLabel.Parent = questionFrame

local answerBox = Instance.new("TextBox")
answerBox.Size = UDim2.fromScale(0.5, 0.4)
answerBox.Position = UDim2.fromScale(0.05, 0.52)
answerBox.PlaceholderText = "?"
answerBox.TextScaled = true
answerBox.Font = Enum.Font.GothamBold
answerBox.Parent = questionFrame

local submit = Instance.new("TextButton")
submit.Size = UDim2.fromScale(0.35, 0.4)
submit.Position = UDim2.fromScale(0.6, 0.52)
submit.BackgroundColor3 = Color3.fromRGB(90, 160, 255)
submit.TextScaled = true
submit.Font = Enum.Font.FredokaOne
submit.TextColor3 = Color3.fromRGB(255, 255, 255)
submit.Text = "Go!"
submit.Parent = questionFrame

local feedback = Instance.new("TextLabel")
feedback.Size = UDim2.fromScale(0.32, 0.06)
feedback.Position = UDim2.fromScale(0.34, 0.28)
feedback.BackgroundTransparency = 1
feedback.TextScaled = true
feedback.Font = Enum.Font.FredokaOne
feedback.TextColor3 = Color3.fromRGB(90, 200, 120)
feedback.Text = ""
feedback.Parent = screenGui

local function showMenu(titleText, detailText, buttonText)
	title.Text = titleText
	detail.Text = detailText
	button.Text = buttonText
	button.Active = true
	menu.Visible = true
	questionFrame.Visible = false
end

button.Activated:Connect(function()
	button.Active = false -- debounce until RoundStarted arrives
	remotes.PlayAgain:FireServer()
end)

submit.Activated:Connect(function()
	remotes.AnswerQuestion:FireServer(answerBox.Text)
end)

answerBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		remotes.AnswerQuestion:FireServer(answerBox.Text)
	end
end)

remotes.RoundStarted.OnClientEvent:Connect(function(_detail)
	menu.Visible = false
	feedback.Text = ""
end)

remotes.RoundEnded.OnClientEvent:Connect(function(result, detailText)
	if result == "survived" then
		showMenu("You Did It!", detailText, "Play Again")
	elseif result == "died" then
		showMenu("Try Again!", detailText, "Play Again")
	else
		showMenu("Ready?", detailText or "", "Play")
	end
end)

remotes.AskQuestion.OnClientEvent:Connect(function(text)
	questionLabel.Text = text
	answerBox.Text = ""
	questionFrame.Visible = true
	feedback.Text = ""
end)

remotes.AnswerFeedback.OnClientEvent:Connect(function(verdict, detailText)
	if verdict == "correct" then
		feedback.TextColor3 = Color3.fromRGB(90, 200, 120)
		feedback.Text = detailText
		questionFrame.Visible = false
	else
		feedback.TextColor3 = Color3.fromRGB(240, 140, 90)
		feedback.Text = detailText
		answerBox.Text = ""
	end
end)
