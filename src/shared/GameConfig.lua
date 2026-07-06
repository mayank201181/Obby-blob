local GameConfig = {}

GameConfig.Remotes = {
	PlayAgain = "PlayAgain", -- client -> server: play / replay
	RoundStarted = "RoundStarted", -- server -> client: hide menu
	RoundEnded = "RoundEnded", -- server -> client: result + detail
	AskQuestion = "AskQuestion", -- server -> client: show a maths problem
	AnswerQuestion = "AnswerQuestion", -- client -> server: submit an answer
	AnswerFeedback = "AnswerFeedback", -- server -> client: correct / try-again
}

GameConfig.RoundDuration = 30 -- seconds a child must survive
GameConfig.ArenaSize = 60 -- studs, square platform per player
GameConfig.ArenaSpacing = 200 -- world-space gap between solo arenas
GameConfig.SpawnHeight = 6 -- studs above the arena floor
GameConfig.FloodRiseStep = 1.5 -- studs the flood rises per tick
GameConfig.FloodTickSeconds = 1 -- seconds between flood ticks
GameConfig.FloodDropOnCorrect = 6 -- studs the flood drops per correct answer
GameConfig.QuestionEverySeconds = 8 -- cadence of maths prompts mid-round

-- Maths settings: Year 1-2 friendly sums by default (see skill section 4c).
GameConfig.Maths = {
	Enabled = true,
	Operation = "add", -- "add" | "sub" | "mul"
	Min = 1,
	Max = 10,
}

return GameConfig
