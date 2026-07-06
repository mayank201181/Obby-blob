--[[
	GameConfig
	Shared configuration and remote-event names for the Solo Disaster game.
	Lives in ReplicatedStorage so both the server and client can read it.
]]

local GameConfig = {}

-- Names of the RemoteEvents the server creates in ReplicatedStorage.
GameConfig.Remotes = {
	-- Client -> Server: the player pressed "Play" / "Play Again".
	PlayAgain = "PlayAgain",
	-- Server -> Client: a new round just began.
	RoundStarted = "RoundStarted",
	-- Server -> Client: the round finished (payload: result string + disaster name).
	RoundEnded = "RoundEnded",
}

-- Round tuning.
GameConfig.RoundDuration = 30 -- seconds the player must survive to win
GameConfig.ArenaSize = 60 -- studs, width/depth of the survival platform
GameConfig.SpawnHeight = 50 -- Y position of the arena floor

-- Every disaster the solo round can randomly pick from.
GameConfig.Disasters = {
	"Flood",
	"FallingBlobs",
	"Earthquake",
}

return GameConfig
