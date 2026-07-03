--[[
	ObbySolo.server.lua
	Solo obby courses: Easy, Hard and Endless.

	Every course is private to one player and floats far away from the
	disaster arenas. Courses are made of anchored platforms:
	  * plain platforms  -- safe to stand on
	  * red platforms    -- vanish shortly after you step on them, then
	                        come back after a few seconds
	  * green pads       -- checkpoints that save your progress
	  * a gold pad       -- the finish (Easy / Hard only)

	The Restart button (ObbyRestart remote) instantly brings back every red
	platform in your course and teleports you to the checkpoint you last
	touched -- so a vanished red platform never leaves you stranded.

	Endless mode has no finish pad; a new segment is generated every time you
	reach the newest checkpoint, and each segment is a little harder.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local ObbyConfig = GameConfig.Obby

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

local ObbyStartRemote = makeRemote(GameConfig.Remotes.ObbyStart)
local ObbyEnteredRemote = makeRemote(GameConfig.Remotes.ObbyEntered)
local ObbyCheckpointRemote = makeRemote(GameConfig.Remotes.ObbyCheckpoint)
local ObbyRestartRemote = makeRemote(GameConfig.Remotes.ObbyRestart)
local ObbyLeaveRemote = makeRemote(GameConfig.Remotes.ObbyLeave)
local ObbyLeftRemote = makeRemote(GameConfig.Remotes.ObbyLeft)
local ObbyFinishedRemote = makeRemote(GameConfig.Remotes.ObbyFinished)

-- ---------------------------------------------------------------------------
-- Per-player state
-- ---------------------------------------------------------------------------
-- state[player] = {
--   mode = "Easy" | "Hard" | "Endless",
--   course = Model,             -- all parts of this player's course
--   origin = Vector3,           -- where the start pad sits
--   cursor = Vector3,           -- where the next platform will be placed
--   checkpoints = {Vector3},    -- teleport spots, checkpoints[1] = start pad
--   checkpointIndex = number,   -- highest checkpoint the player has touched
--   redParts = {Part},          -- every red platform, for Restart
--   segments = number,          -- Endless: how many segments exist so far
--   finished = boolean,         -- debounce for the finish pad
-- }
local state = {}

-- Sticky course slot per player so rebuilding a course reuses the same spot.
local slots = {}
local nextSlot = 0

local function courseOrigin(player)
	local slot = slots[player]
	if not slot then
		slot = nextSlot
		nextSlot += 1
		slots[player] = slot
	end
	return Vector3.new(slot * ObbyConfig.CourseSpacing, ObbyConfig.SpawnHeight, ObbyConfig.BaseZ)
end

-- Forward declarations: these are called from Touched handlers that are set
-- up before the functions are defined below.
local buildEndlessSegment
local exitObby

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function ensureAliveCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and character.Parent and humanoid and humanoid.Health > 0 then
		return character
	end
	player:LoadCharacter()
	character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")
	return character
end

local function teleportTo(player, spot)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(spot + Vector3.new(0, 4, 0))
	end
end

-- Bring back every red platform and cancel any vanish timers in flight.
local function restoreRedParts(s)
	for _, part in ipairs(s.redParts) do
		if part.Parent then
			part:SetAttribute("VanishToken", part:GetAttribute("VanishToken") + 1)
			part.Transparency = 0
			part.CanCollide = true
		end
	end
end

local function sendToCheckpoint(player, s)
	local spot = s.checkpoints[s.checkpointIndex]
	if not spot then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid and humanoid.Health > 0) then
		-- Dead or missing: respawn instead; onCharacterAdded lands them on
		-- the checkpoint.
		player:LoadCharacter()
		return
	end
	teleportTo(player, spot)
end

-- ---------------------------------------------------------------------------
-- Course construction
-- ---------------------------------------------------------------------------
local function makePlatform(s, size, position)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = s.course
	return part
end

local function addNormalPlatform(s, conf)
	local part = makePlatform(s, Vector3.new(conf.PlatformSize, 1, conf.PlatformSize), s.cursor)
	part.Name = "Platform"
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(120, 150, 200)
end

-- The "red thing": stand on it and it flickers, vanishes, then comes back a
-- few seconds later. The VanishToken attribute lets Restart cancel a vanish
-- that is already in progress.
local function addRedPlatform(s, player, conf)
	local part = makePlatform(s, Vector3.new(conf.PlatformSize, 1, conf.PlatformSize), s.cursor)
	part.Name = "RedPlatform"
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(210, 55, 55)
	part:SetAttribute("VanishToken", 0)
	table.insert(s.redParts, part)

	part.Touched:Connect(function(hit)
		if not part.CanCollide then
			return -- already vanished
		end
		local character = player.Character
		if not (character and hit:IsDescendantOf(character)) then
			return
		end
		local token = part:GetAttribute("VanishToken") + 1
		part:SetAttribute("VanishToken", token)

		task.spawn(function()
			-- Flicker as a warning while the delay runs down.
			local flashes = math.max(2, math.floor(conf.VanishDelay / 0.15))
			local step = conf.VanishDelay / flashes / 2
			for _ = 1, flashes do
				if part:GetAttribute("VanishToken") ~= token or not part.Parent then
					return
				end
				part.Transparency = 0.5
				task.wait(step)
				part.Transparency = 0
				task.wait(step)
			end
			if part:GetAttribute("VanishToken") ~= token or not part.Parent then
				return
			end
			part.Transparency = 1
			part.CanCollide = false
			task.wait(conf.RedRespawn)
			if part:GetAttribute("VanishToken") ~= token or not part.Parent then
				return
			end
			part.Transparency = 0
			part.CanCollide = true
		end)
	end)
end

local function addCheckpoint(s, player, conf)
	local size = conf.PlatformSize + 2
	local part = makePlatform(s, Vector3.new(size, 1, size), s.cursor)
	part.Name = "Checkpoint"
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(70, 200, 110)

	table.insert(s.checkpoints, part.Position + Vector3.new(0, 0.5, 0))
	local index = #s.checkpoints

	part.Touched:Connect(function(hit)
		local current = state[player]
		if current ~= s then
			return -- stale course
		end
		local character = player.Character
		if not (character and hit:IsDescendantOf(character)) then
			return
		end
		if index > s.checkpointIndex then
			s.checkpointIndex = index
			ObbyCheckpointRemote:FireClient(player, index)
			-- Endless: reaching the newest checkpoint grows the course.
			if s.mode == "Endless" and index == #s.checkpoints then
				s.segments += 1
				buildEndlessSegment(s, player)
			end
		end
	end)
end

local function addFinishPad(s, player, conf)
	local size = conf.PlatformSize + 4
	local part = makePlatform(s, Vector3.new(size, 1, size), s.cursor)
	part.Name = "Finish"
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(240, 200, 70)

	part.Touched:Connect(function(hit)
		local current = state[player]
		if current ~= s or s.finished then
			return
		end
		local character = player.Character
		if not (character and hit:IsDescendantOf(character)) then
			return
		end
		s.finished = true
		local mode = s.mode
		exitObby(player)
		ObbyFinishedRemote:FireClient(player, mode)
	end)
end

-- Move the build cursor one platform forward. Rising jumps get a shorter gap
-- so every jump stays makeable.
local function advanceCursor(s, conf)
	local gap = conf.GapMin + math.random() * (conf.GapMax - conf.GapMin)
	local x = s.cursor.X + (math.random() - 0.5) * 8
	x = math.clamp(x, s.origin.X - 25, s.origin.X + 25)
	local y = s.cursor.Y + (math.random() - 0.5) * 2 * conf.HeightJitter
	y = math.clamp(y, s.origin.Y - 8, s.origin.Y + 20)
	local rise = y - s.cursor.Y
	if rise > 0 then
		gap = math.max(2, gap - rise * 1.5)
	end
	local z = s.cursor.Z + gap + conf.PlatformSize
	s.cursor = Vector3.new(x, y, z)
end

local function addStartPad(s, conf)
	local size = conf.PlatformSize + 4
	local part = makePlatform(s, Vector3.new(size, 1, size), s.origin)
	part.Name = "Start"
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(235, 235, 235)
	-- The start pad is checkpoint 1, so Restart before any checkpoint sends
	-- the player back to the beginning.
	table.insert(s.checkpoints, part.Position + Vector3.new(0, 0.5, 0))
end

-- Endless difficulty: each finished segment nudges gaps and red-platform
-- density up toward the caps.
local function endlessConf(base, segmentIndex)
	local conf = table.clone(base)
	local ramp = segmentIndex - 1
	conf.GapMin = math.min(base.GapMin + ramp * base.GapRamp, base.GapCap - 1.5)
	conf.GapMax = math.min(base.GapMax + ramp * base.GapRamp, base.GapCap)
	conf.RedChance = math.min(base.RedChance + ramp * base.RedChanceRamp, base.RedChanceCap)
	return conf
end

function buildEndlessSegment(s, player) -- luacheck: ignore (declared above)
	local conf = endlessConf(ObbyConfig.Modes.Endless, s.segments)
	for _ = 1, conf.SegmentLength do
		advanceCursor(s, conf)
		if math.random() < conf.RedChance then
			addRedPlatform(s, player, conf)
		else
			addNormalPlatform(s, conf)
		end
	end
	advanceCursor(s, conf)
	addCheckpoint(s, player, conf)
end

local function buildCourse(s, player)
	if s.mode == "Endless" then
		buildEndlessSegment(s, player)
		return
	end

	local conf = ObbyConfig.Modes[s.mode]
	for i = 1, conf.PlatformCount do
		advanceCursor(s, conf)
		if i % conf.CheckpointEvery == 0 then
			addCheckpoint(s, player, conf)
		elseif math.random() < conf.RedChance then
			addRedPlatform(s, player, conf)
		else
			addNormalPlatform(s, conf)
		end
	end
	advanceCursor(s, conf)
	addFinishPad(s, player, conf)
end

-- ---------------------------------------------------------------------------
-- Entering / leaving
-- ---------------------------------------------------------------------------
local function destroyCourse(player)
	local s = state[player]
	if s then
		if s.course then
			s.course:Destroy()
		end
		state[player] = nil
	end
end

function exitObby(player) -- luacheck: ignore (declared above)
	destroyCourse(player)
	player:SetAttribute(GameConfig.ModeAttribute, nil)
	-- Respawn to return to the lobby; DisasterSolo's CharacterAdded handler
	-- lands the fresh character on the player's arena now that the mode
	-- attribute is cleared.
	task.defer(function()
		if player.Parent then
			player:LoadCharacter()
		end
	end)
end

local function enterObby(player, mode)
	local conf = ObbyConfig.Modes[mode]
	if not conf then
		return
	end

	destroyCourse(player)

	local course = Instance.new("Model")
	course.Name = player.Name .. "_ObbyCourse"

	local origin = courseOrigin(player)
	local s = {
		mode = mode,
		course = course,
		origin = origin,
		cursor = origin,
		checkpoints = {},
		checkpointIndex = 1,
		redParts = {},
		segments = 1,
		finished = false,
	}
	state[player] = s

	addStartPad(s, conf)
	buildCourse(s, player)
	course.Parent = workspace

	player:SetAttribute(GameConfig.ModeAttribute, "Obby")

	ensureAliveCharacter(player)
	if state[player] ~= s then
		return -- player left or switched courses while respawning
	end
	teleportTo(player, s.checkpoints[1])
	ObbyEnteredRemote:FireClient(player, mode)
end

-- ---------------------------------------------------------------------------
-- Player connections
-- ---------------------------------------------------------------------------
local function onCharacterAdded(player, character)
	local s = state[player]
	if not s then
		return
	end
	-- Died on the course: bring the red platforms back and land the fresh
	-- character on the last checkpoint.
	character:WaitForChild("HumanoidRootPart")
	if state[player] ~= s then
		return
	end
	restoreRedParts(s)
	teleportTo(player, s.checkpoints[s.checkpointIndex])
end

local function hookPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

Players.PlayerAdded:Connect(hookPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	destroyCourse(player)
	slots[player] = nil
end)

-- Falling off the course counts as a death straight away instead of waiting
-- for the world's fall limit.
RunService.Heartbeat:Connect(function()
	for player, s in pairs(state) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root.Position.Y < s.origin.Y - ObbyConfig.KillDepth then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
				-- Quick respawn onto the checkpoint instead of sitting out
				-- the full default respawn wait.
				task.delay(1, function()
					if state[player] and player.Character == character then
						player:LoadCharacter()
					end
				end)
			end
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Remote handlers
-- ---------------------------------------------------------------------------
ObbyStartRemote.OnServerEvent:Connect(function(player, mode)
	if typeof(mode) ~= "string" then
		return
	end
	enterObby(player, mode)
end)

-- The requested Restart button: every red platform comes back instantly and
-- the player returns to the checkpoint they last touched.
ObbyRestartRemote.OnServerEvent:Connect(function(player)
	local s = state[player]
	if not s then
		return
	end
	restoreRedParts(s)
	sendToCheckpoint(player, s)
end)

ObbyLeaveRemote.OnServerEvent:Connect(function(player)
	if not state[player] then
		return
	end
	exitObby(player)
	ObbyLeftRemote:FireClient(player)
end)
