--[[
	GameConfig
	Shared configuration and remote-event names for the solo game modes.
	Lives in ReplicatedStorage so both the server and client can read it.
]]

local GameConfig = {}

-- Player attribute that says which solo mode currently owns the player
-- ("Disaster", "Obby", or nil while they sit in the menu/lobby). The two
-- server scripts use it to stay out of each other's way on respawns.
GameConfig.ModeAttribute = "SoloMode"

-- Names of the RemoteEvents the server creates in ReplicatedStorage.
GameConfig.Remotes = {
	-- Client -> Server: the player pressed "Play" / "Play Again" (disaster).
	PlayAgain = "PlayAgain",
	-- Server -> Client: a new disaster round just began.
	RoundStarted = "RoundStarted",
	-- Server -> Client: the disaster round finished (result + disaster name).
	RoundEnded = "RoundEnded",

	-- Client -> Server: start an obby course ("Easy" | "Hard" | "Endless").
	ObbyStart = "ObbyStart",
	-- Server -> Client: the course is built and the player is standing on it.
	ObbyEntered = "ObbyEntered",
	-- Server -> Client: the player reached checkpoint N.
	ObbyCheckpoint = "ObbyCheckpoint",
	-- Client -> Server: the Restart button -- bring every red platform back
	-- and send the player to the checkpoint they last touched.
	ObbyRestart = "ObbyRestart",
	-- Client -> Server: quit the course back to the menu.
	ObbyLeave = "ObbyLeave",
	-- Server -> Client: the player left the course (show the menu again).
	ObbyLeft = "ObbyLeft",
	-- Server -> Client: the player touched the finish pad.
	ObbyFinished = "ObbyFinished",
}

-- Disaster round tuning.
GameConfig.RoundDuration = 30 -- seconds the player must survive to win
GameConfig.ArenaSize = 60 -- studs, width/depth of the survival platform
GameConfig.SpawnHeight = 50 -- Y position of the arena floor

-- Every disaster the solo round can randomly pick from.
GameConfig.Disasters = {
	"Flood",
	"FallingBlobs",
	"Earthquake",
}

-- Obby tuning. Each player gets a private floating course far away from the
-- disaster arenas.
GameConfig.Obby = {
	SpawnHeight = 150, -- Y of the course platforms
	BaseZ = 1500, -- courses live far from the arenas along Z
	CourseSpacing = 300, -- studs between two players' courses along X
	KillDepth = 45, -- fall this far below the course and you die

	Modes = {
		Easy = {
			PlatformSize = 8,
			GapMin = 4,
			GapMax = 6,
			HeightJitter = 1,
			PlatformCount = 24,
			CheckpointEvery = 6,
			RedChance = 0.25,
			VanishDelay = 0.9, -- seconds a red platform holds after you step on it
			RedRespawn = 3, -- seconds until a vanished red platform returns on its own
		},
		Hard = {
			PlatformSize = 5,
			GapMin = 7,
			GapMax = 9,
			HeightJitter = 2,
			PlatformCount = 30,
			CheckpointEvery = 6,
			RedChance = 0.4,
			VanishDelay = 0.5,
			RedRespawn = 4,
		},
		Endless = {
			PlatformSize = 7,
			GapMin = 4,
			GapMax = 6,
			HeightJitter = 1.5,
			SegmentLength = 8, -- platforms per segment; every segment ends in a checkpoint
			RedChance = 0.3,
			VanishDelay = 0.8,
			RedRespawn = 3,
			-- Difficulty ramp applied for each completed segment.
			GapRamp = 0.25,
			GapCap = 9,
			RedChanceRamp = 0.03,
			RedChanceCap = 0.55,
		},
	},
}

return GameConfig
