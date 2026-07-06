-- Solo Disaster: each player survives a rising flood on their own arena,
-- and clearing the water is gated behind maths problems (answer-to-survive).
-- All truth lives here; the client only renders and sends intents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local MathsProblems = require(ReplicatedStorage:WaitForChild("MathsProblems"))
local RoundKernel = require(ReplicatedStorage:WaitForChild("RoundKernel"))

-- RemoteEvents are created in code so the game runs with zero Studio assets.
local remotes = {}
for _, name in GameConfig.Remotes do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	remotes[name] = remote
end

local kernel = RoundKernel.new({
	onRoundStarted = function(player, _roundId)
		remotes.RoundStarted:FireClient(player, "Survive the flood for " .. GameConfig.RoundDuration .. "s!")
	end,
	onRoundEnded = function(player, result, detail)
		remotes.RoundEnded:FireClient(player, result, detail)
	end,
	onAskQuestion = function(player, text)
		remotes.AskQuestion:FireClient(player, text)
	end,
	onAnswerFeedback = function(player, verdict, detail)
		remotes.AnswerFeedback:FireClient(player, verdict, detail)
	end,
})

-- worldState[player] = { arena, floor, water, arenaIndex }
local worldState = {}
local nextArenaIndex = 0

local function buildArena(player)
	nextArenaIndex += 1
	local index = nextArenaIndex
	local origin = Vector3.new(index * GameConfig.ArenaSpacing, 0, 0)

	local arena = Instance.new("Folder")
	arena.Name = "Arena_" .. player.Name

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(GameConfig.ArenaSize, 2, GameConfig.ArenaSize)
	floor.Position = origin
	floor.Color = Color3.fromRGB(120, 200, 120)
	floor.Parent = arena

	local water = Instance.new("Part")
	water.Name = "Water"
	water.Anchored = true
	water.CanCollide = false
	water.Transparency = 0.4
	water.Color = Color3.fromRGB(60, 120, 255)
	water.Size = Vector3.new(GameConfig.ArenaSize, 1, GameConfig.ArenaSize)
	-- Parked well below the floor between rounds.
	water.Position = origin - Vector3.new(0, 30, 0)
	water.Parent = arena

	arena.Parent = Workspace
	worldState[player] = { arena = arena, floor = floor, water = water, arenaIndex = index }
end

local function teleportToArena(player)
	local w = worldState[player]
	local character = player.Character
	if not w or not character then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root then
		root.CFrame = CFrame.new(w.floor.Position + Vector3.new(0, GameConfig.SpawnHeight, 0))
	end
end

local function resetWater(player)
	local w = worldState[player]
	if w then
		w.water.Position = w.floor.Position - Vector3.new(0, 30, 0)
	end
end

-- One self-cancelling flood loop per round (skill section 3b shape).
local function runFlood(player, roundId)
	local w = worldState[player]
	if not w then
		return
	end
	w.water.Position = w.floor.Position - Vector3.new(0, 6, 0)
	task.spawn(function()
		while kernel:roundIsCurrent(player, roundId) do
			w.water.Position += Vector3.new(0, GameConfig.FloodRiseStep, 0)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and root.Position.Y < w.water.Position.Y + w.water.Size.Y / 2 then
				humanoid.Health = 0 -- drowned; Died handler ends the round
			end
			task.wait(GameConfig.FloodTickSeconds)
		end
	end)
end

-- Maths cadence: every few seconds ask a problem; a correct answer drops the
-- flood back down. Wrong answers are fail-soft — the kernel keeps the same
-- problem live and the child just tries again.
local function runQuestions(player, roundId)
	if not GameConfig.Maths.Enabled then
		return
	end
	task.spawn(function()
		while kernel:roundIsCurrent(player, roundId) do
			task.wait(GameConfig.QuestionEverySeconds)
			if not kernel:roundIsCurrent(player, roundId) then
				break
			end
			local problem = MathsProblems.make(GameConfig.Maths)
			kernel:askQuestion(player, problem, roundId, function()
				local w = worldState[player]
				if w and kernel:roundIsCurrent(player, roundId) then
					w.water.Position -= Vector3.new(0, GameConfig.FloodDropOnCorrect, 0)
				end
			end)
		end
	end)
end

local function runTimer(player, roundId)
	task.delay(GameConfig.RoundDuration, function()
		if kernel:roundIsCurrent(player, roundId) then
			kernel:endRound(player, "survived", "You beat the flood!")
			resetWater(player)
		end
	end)
end

remotes.PlayAgain.OnServerEvent:Connect(function(player)
	local roundId = kernel:playAgain(player)
	if not roundId then
		return -- mid-round double-tap, or player not registered yet
	end
	resetWater(player)
	teleportToArena(player)
	runFlood(player, roundId)
	runQuestions(player, roundId)
	runTimer(player, roundId)
end)

remotes.AnswerQuestion.OnServerEvent:Connect(function(player, submitted)
	kernel:submitAnswer(player, submitted)
end)

Players.PlayerAdded:Connect(function(player)
	kernel:addPlayer(player)
	buildArena(player)
	player.CharacterAdded:Connect(function(character)
		-- Respawn drops players at the default spawn otherwise.
		teleportToArena(player)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			kernel:endRound(player, "died", "The flood got you \226\128\148 have another go!")
			resetWater(player)
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	kernel:removePlayer(player)
	local w = worldState[player]
	if w then
		w.arena:Destroy()
		worldState[player] = nil
	end
end)
