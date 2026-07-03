--[[
	DisasterSolo.server.lua
	Runs the SOLO disaster experience.

	Each player gets their own private arena and their own round, so pressing
	"Play Again" simply tears down the current round and starts a fresh one for
	that single player -- no waiting on anyone else, no shared timer.

	Flow per player:
		join            -> build a private arena, show them the round-end menu
		press Play      -> start a round (random disaster)
		survive / die   -> round ends, menu with "Play Again" appears again
		press Play Again -> start another round (this is the requested feature)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- ---------------------------------------------------------------------------
-- RemoteEvents
-- ---------------------------------------------------------------------------
local function makeRemote(name)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote
end

local PlayAgainRemote = makeRemote(GameConfig.Remotes.PlayAgain)
local RoundStartedRemote = makeRemote(GameConfig.Remotes.RoundStarted)
local RoundEndedRemote = makeRemote(GameConfig.Remotes.RoundEnded)

-- ---------------------------------------------------------------------------
-- Per-player state
-- ---------------------------------------------------------------------------
-- state[player] = {
--   arena = Model,        -- the private arena for this player
--   floorTop = number,    -- Y of the arena floor surface (spawn on top)
--   roundId = number,     -- increments each round; used to cancel stale rounds
--   active = boolean,     -- is a round currently running
-- }
local state = {}

local ARENA_SPACING = 400 -- studs between each player's private arena
local nextArenaSlot = 0

local function arenaOrigin(slot)
	-- Spread arenas out along X so they never overlap.
	return Vector3.new(slot * ARENA_SPACING, GameConfig.SpawnHeight, 0)
end

-- ---------------------------------------------------------------------------
-- Arena construction
-- ---------------------------------------------------------------------------
local function buildArena(origin)
	local arena = Instance.new("Model")
	arena.Name = "SoloArena"

	local size = GameConfig.ArenaSize

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(size, 3, size)
	floor.Position = origin
	floor.Material = Enum.Material.Grass
	floor.Color = Color3.fromRGB(86, 160, 78)
	floor.Parent = arena

	arena.PrimaryPart = floor
	arena.Parent = workspace

	local floorTop = origin.Y + floor.Size.Y / 2
	return arena, floorTop
end

local function teleportToArena(player, origin, floorTop)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(origin.X, floorTop + 5, origin.Z)
	end
end

-- ---------------------------------------------------------------------------
-- Disasters
-- Each disaster returns quickly; it spawns its hazards and relies on the
-- roundId check so it stops the moment the round is cancelled/restarted.
-- ---------------------------------------------------------------------------
local Disasters = {}

local function roundIsCurrent(player, roundId)
	local s = state[player]
	return s ~= nil and s.active and s.roundId == roundId
end

-- Rising flood: a water block climbs from below; touching it is lethal.
function Disasters.Flood(player, origin, floorTop, roundId)
	local size = GameConfig.ArenaSize
	local water = Instance.new("Part")
	water.Name = "Flood"
	water.Anchored = true
	water.CanCollide = false
	water.Transparency = 0.35
	water.Material = Enum.Material.Water
	water.Color = Color3.fromRGB(60, 130, 220)
	water.Size = Vector3.new(size + 20, 2, size + 20)
	water.Position = Vector3.new(origin.X, floorTop - 20, origin.Z)
	water.Parent = state[player].arena

	water.Touched:Connect(function(hit)
		local character = player.Character
		if character and hit:IsDescendantOf(character) then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end
	end)

	task.spawn(function()
		local rise = (GameConfig.ArenaSize) / GameConfig.RoundDuration
		while roundIsCurrent(player, roundId) do
			if water.Size.Y >= GameConfig.ArenaSize + 30 then
				break
			end
			water.Size = water.Size + Vector3.new(0, rise, 0)
			water.Position = water.Position + Vector3.new(0, rise / 2, 0)
			RunService.Heartbeat:Wait()
		end
	end)
end

-- Falling blobs: parts drop from the sky and squash the player on contact.
function Disasters.FallingBlobs(player, origin, floorTop, roundId)
	task.spawn(function()
		while roundIsCurrent(player, roundId) do
			local blob = Instance.new("Part")
			blob.Shape = Enum.PartType.Ball
			blob.Name = "Blob"
			blob.Size = Vector3.new(6, 6, 6)
			blob.Material = Enum.Material.SmoothPlastic
			blob.Color = Color3.fromRGB(200, 70, 90)
			local half = GameConfig.ArenaSize / 2
			blob.Position = Vector3.new(
				origin.X + math.random(-half, half),
				floorTop + 60,
				origin.Z + math.random(-half, half)
			)
			blob.Parent = state[player].arena

			blob.Touched:Connect(function(hit)
				local character = player.Character
				if character and hit:IsDescendantOf(character) then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.Health = 0
					end
				end
			end)

			game:GetService("Debris"):AddItem(blob, 8)
			task.wait(0.6)
		end
	end)
end

-- Earthquake: floor tiles randomly drop away, so the player must keep moving.
function Disasters.Earthquake(player, origin, floorTop, roundId)
	local floor = state[player].arena:FindFirstChild("Floor")
	if not floor then
		return
	end
	floor.Transparency = 1
	floor.CanCollide = false

	local tiles = {}
	local tileSize = 10
	local size = GameConfig.ArenaSize
	local half = size / 2
	for x = -half + tileSize / 2, half - tileSize / 2, tileSize do
		for z = -half + tileSize / 2, half - tileSize / 2, tileSize do
			local tile = Instance.new("Part")
			tile.Anchored = true
			tile.Size = Vector3.new(tileSize - 0.5, 3, tileSize - 0.5)
			tile.Position = Vector3.new(origin.X + x, floorTop - 1.5, origin.Z + z)
			tile.Material = Enum.Material.Slate
			tile.Color = Color3.fromRGB(120, 110, 100)
			tile.Parent = state[player].arena
			table.insert(tiles, tile)
		end
	end

	task.spawn(function()
		while roundIsCurrent(player, roundId) and #tiles > 2 do
			local index = math.random(1, #tiles)
			local tile = table.remove(tiles, index)
			if tile and tile.Parent then
				tile.Anchored = false
				tile.CanCollide = false
				game:GetService("Debris"):AddItem(tile, 4)
			end
			task.wait(0.5)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Round lifecycle
-- ---------------------------------------------------------------------------
local function clearHazards(player)
	local s = state[player]
	if not s or not s.arena then
		return
	end
	for _, child in ipairs(s.arena:GetChildren()) do
		if child.Name ~= "Floor" then
			child:Destroy()
		end
	end
	-- Restore the floor in case a disaster (Earthquake) hid it.
	local floor = s.arena:FindFirstChild("Floor")
	if floor then
		floor.Transparency = 0
		floor.CanCollide = true
	end
end

local function endRound(player, result, disasterName)
	local s = state[player]
	if not s or not s.active then
		return
	end
	s.active = false
	clearHazards(player)
	RoundEndedRemote:FireClient(player, result, disasterName)
end

local function startRound(player)
	local s = state[player]
	if not s then
		return
	end

	-- Bump the round id so any lingering disaster loops from a previous round
	-- stop immediately -- this is what makes "Play Again" safe to spam.
	s.roundId += 1
	local roundId = s.roundId
	s.active = true

	clearHazards(player)

	local origin = Vector3.new(
		s.arena.PrimaryPart.Position.X,
		GameConfig.SpawnHeight,
		s.arena.PrimaryPart.Position.Z
	)
	teleportToArena(player, origin, s.floorTop)

	local disasterName = GameConfig.Disasters[math.random(1, #GameConfig.Disasters)]
	local disaster = Disasters[disasterName]

	RoundStartedRemote:FireClient(player, disasterName)

	if disaster then
		disaster(player, origin, s.floorTop, roundId)
	end

	-- Watch the humanoid for death.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local conn
		conn = humanoid.Died:Connect(function()
			if conn then
				conn:Disconnect()
			end
			if roundIsCurrent(player, roundId) then
				endRound(player, "died", disasterName)
			end
		end)
	end

	-- Survival timer.
	task.spawn(function()
		local elapsed = 0
		while elapsed < GameConfig.RoundDuration do
			if not roundIsCurrent(player, roundId) then
				return -- round was restarted or player left
			end
			task.wait(0.25)
			elapsed += 0.25
		end
		if roundIsCurrent(player, roundId) then
			endRound(player, "survived", disasterName)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Player connections
-- ---------------------------------------------------------------------------
local function onCharacterAdded(player, character)
	local s = state[player]
	if not s then
		return
	end
	-- Land the fresh character on their arena; wait for the root part first.
	character:WaitForChild("HumanoidRootPart")
	local origin = Vector3.new(
		s.arena.PrimaryPart.Position.X,
		GameConfig.SpawnHeight,
		s.arena.PrimaryPart.Position.Z
	)
	teleportToArena(player, origin, s.floorTop)
end

local function onPlayerAdded(player)
	local slot = nextArenaSlot
	nextArenaSlot += 1

	local origin = arenaOrigin(slot)
	local arena, floorTop = buildArena(origin)

	state[player] = {
		arena = arena,
		floorTop = floorTop,
		roundId = 0,
		active = false,
	}

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	-- Show the start menu; the player triggers the first round via "Play".
	task.defer(function()
		RoundEndedRemote:FireClient(player, "ready", nil)
	end)
end

local function onPlayerRemoving(player)
	local s = state[player]
	if s then
		s.active = false
		if s.arena then
			s.arena:Destroy()
		end
		state[player] = nil
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- The core of the request: "Play Again" starts another solo round.
PlayAgainRemote.OnServerEvent:Connect(function(player)
	local s = state[player]
	if not s then
		return
	end
	-- Ignore if a round is already running so a double-tap can't stack rounds.
	if s.active then
		return
	end
	startRound(player)
end)
