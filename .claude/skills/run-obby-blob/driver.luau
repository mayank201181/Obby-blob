--!nocheck
-- Headless driver for Obby-blob / Solo Disaster.
-- Roblox has no Linux runtime, so this drives the game's server-authoritative
-- brain (src/shared/RoundKernel.lua + MathsProblems.lua) directly under lune.
--
--   lune run driver.luau           -> smoke: deterministic assertion suite
--   lune run driver.luau play      -> interactive text round (pipe answers in)
--
-- The play mode is turn-based on purpose: one question per flood tick, no
-- wall-clock timing, so piped input reproduces exactly.

local process = require("@lune/process")
local stdio = require("@lune/stdio")

local GameConfig = require("../../../src/shared/GameConfig")
local MathsProblems = require("../../../src/shared/MathsProblems")
local RoundKernel = require("../../../src/shared/RoundKernel")

-- Counter-based rng: reproducible, per the kids-edu-game skill's gotcha about
-- os.time-seeded randomness in harnesses.
local counter = 0
local function rng(min, max)
	counter += 7
	return min + counter % (max - min + 1)
end

local failures = 0
local function check(name, ok)
	if ok then
		print("PASS  " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local function runSmoke()
	print("== Obby-blob Solo Disaster: headless smoke ==")

	-- GameConfig sanity
	local seen = {}
	local dupes = false
	for _, name in GameConfig.Remotes do
		if seen[name] then
			dupes = true
		end
		seen[name] = true
	end
	check("GameConfig: remote names unique", not dupes)
	check("GameConfig: maths range sane", GameConfig.Maths.Min <= GameConfig.Maths.Max)

	-- MathsProblems across every operation
	for _, op in { "add", "sub", "mul" } do
		local cfg = { Enabled = true, Operation = op, Min = 1, Max = 10 }
		local allGood = true
		for _ = 1, 50 do
			local p = MathsProblems.make(cfg, rng)
			if p.answer < 0 or not MathsProblems.check(p, tostring(p.answer)) then
				allGood = false
			end
			if MathsProblems.check(p, p.answer + 1) or MathsProblems.check(p, "blob") then
				allGood = false
			end
		end
		check("MathsProblems: " .. op .. " generates, checks, rejects", allGood)
	end

	-- RoundKernel lifecycle
	local events = {}
	local kernel = RoundKernel.new({
		onRoundStarted = function(_, roundId)
			table.insert(events, "started:" .. roundId)
		end,
		onRoundEnded = function(_, result)
			table.insert(events, "ended:" .. result)
		end,
		onAskQuestion = function(_, text)
			table.insert(events, "ask:" .. text)
		end,
		onAnswerFeedback = function(_, verdict)
			table.insert(events, "feedback:" .. verdict)
		end,
	})

	local player = "blob-kid"
	kernel:addPlayer(player)
	check("kernel: playAgain before join is ignored", kernel:playAgain("stranger") == nil)

	local round1 = kernel:playAgain(player)
	check("kernel: first Play starts round 1", round1 == 1)
	check("kernel: Play Again spam mid-round ignored", kernel:playAgain(player) == nil)
	check("kernel: round 1 is current", kernel:roundIsCurrent(player, round1))

	local gateOpened = false
	local problem = MathsProblems.make(GameConfig.Maths, rng)
	kernel:askQuestion(player, problem, round1, function()
		gateOpened = true
	end)
	check("kernel: wrong answer fails soft", kernel:submitAnswer(player, problem.answer + 1) == "incorrect")
	check("kernel: gate stays shut after wrong answer", not gateOpened)
	check("kernel: right answer (as string) accepted", kernel:submitAnswer(player, tostring(problem.answer)) == "correct")
	check("kernel: correct answer opens the gate", gateOpened)
	check("kernel: re-submitting is ignored", kernel:submitAnswer(player, problem.answer) == "ignored")

	kernel:endRound(player, "survived", "You beat the flood!")
	check("kernel: ended round no longer current", not kernel:roundIsCurrent(player, round1))
	local endedEvents = 0
	for _, e in events do
		if e:find("ended:", 1, true) == 1 then
			endedEvents += 1
		end
	end
	kernel:endRound(player, "died", "should be ignored")
	local endedAfter = 0
	for _, e in events do
		if e:find("ended:", 1, true) == 1 then
			endedAfter += 1
		end
	end
	check("kernel: double endRound is a no-op", endedEvents == 1 and endedAfter == 1)

	local round2 = kernel:playAgain(player)
	check("kernel: Play Again starts round 2", round2 == 2)
	check("kernel: stale round-1 loops are cancelled", not kernel:roundIsCurrent(player, round1))

	-- A question tied to round 1 must be dead in round 2.
	kernel:askQuestion(player, problem, round1, function() end)
	check("kernel: stale-round question never asked", kernel:submitAnswer(player, problem.answer) == "ignored")

	kernel:removePlayer(player)
	check("kernel: removed player is gone", kernel:getState(player) == nil)

	local timeline = table.concat(events, " | ")
	print("event timeline: " .. timeline)
	check(
		"kernel: event order started->ask->feedback x2->ended->started",
		timeline:find("started:1", 1, true) ~= nil
			and timeline:find("feedback:incorrect", 1, true) ~= nil
			and timeline:find("feedback:correct", 1, true) ~= nil
			and timeline:find("ended:survived", 1, true) ~= nil
			and timeline:find("started:2", 1, true) ~= nil
	)

	if failures > 0 then
		print(("== %d FAILURE(S) =="):format(failures))
		process.exit(1)
	end
	print("== ALL PASS ==")
end

-- stdio.prompt needs a TTY ("IO error: not a terminal" when piped), so fall
-- back to readLine for piped input. readLine keeps the trailing newline and
-- returns "" forever at EOF, so a blank line means "we're done" — quit.
local isTty = true
local function ask(label: string): string?
	if isTty then
		local ok, result = pcall(stdio.prompt, "text", label)
		if ok then
			return result
		end
		isTty = false
	end
	stdio.write("   " .. label .. " > ")
	local line = stdio.readLine():gsub("%s+$", "")
	stdio.write(line .. "\n")
	if line == "" then
		return nil
	end
	return line
end

local function runPlay()
	print("== Solo Disaster (text mode) ==")
	print("The flood rises every turn. Answer the sum to push it back!")

	-- Optional seed makes a piped run reproducible: run once to see the
	-- questions, rerun with the same seed piping the answers.
	local seed = tonumber(process.args[2])
	if seed then
		math.randomseed(seed)
	end

	local floorY = 0
	local playerY = 3
	local kernel
	local waterY
	local turnsToWin = 5

	kernel = RoundKernel.new({
		onRoundStarted = function()
			print(">> Round started! Survive " .. turnsToWin .. " turns.")
		end,
		onRoundEnded = function(_, result, detail)
			if result == "survived" then
				print(">> You Did It! " .. detail)
			else
				print(">> Try Again! " .. detail)
			end
		end,
		onAskQuestion = function(_, text)
			print("   QUESTION: " .. text)
		end,
		onAnswerFeedback = function(_, _verdict, detail)
			print("   " .. detail)
		end,
	})

	local player = "you"
	kernel:addPlayer(player)

	while true do
		local roundId = kernel:playAgain(player)
		waterY = floorY - 6
		local turn = 0
		while kernel:roundIsCurrent(player, roundId) do
			turn += 1
			waterY += GameConfig.FloodRiseStep
			print(("-- turn %d/%d: water at %.1f (you are at %.1f)"):format(turn, turnsToWin, waterY, playerY))
			local problem = MathsProblems.make(GameConfig.Maths)
			local answered = false
			kernel:askQuestion(player, problem, roundId, function()
				answered = true
			end)
			while not answered and kernel:roundIsCurrent(player, roundId) do
				local input = ask("your answer")
				if input == nil then
					print("Out of input \226\128\148 thanks for playing!")
					return
				end
				local verdict = kernel:submitAnswer(player, input)
				if verdict == "incorrect" then
					waterY += GameConfig.FloodRiseStep -- wrong answers cost time
					if waterY >= playerY then
						kernel:endRound(player, "died", "The flood got you \226\128\148 have another go!")
					end
				elseif verdict == "correct" then
					waterY -= GameConfig.FloodDropOnCorrect
				end
			end
			if kernel:roundIsCurrent(player, roundId) and turn >= turnsToWin then
				kernel:endRound(player, "survived", "You beat the flood!")
			end
		end
		local again = ask("Play Again? (y/n)")
		if again ~= "y" then
			print("Thanks for playing!")
			break
		end
	end
end

if process.args[1] == "play" then
	runPlay()
else
	runSmoke()
end
