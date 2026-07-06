--!strict
-- Server-side maths problem generation and checking.
-- Pure module: no Roblox globals, so it runs under lune/CI as well as in game.
-- `rng(min, max) -> integer` is injectable so harnesses can reproduce runs;
-- in Roblox, omit it and math.random is used.

export type Problem = {
	text: string,
	answer: number,
	a: number,
	b: number,
	op: string,
}

export type MathsConfig = {
	Enabled: boolean,
	Operation: string,
	Min: number,
	Max: number,
}

local SYMBOLS = { add = "+", sub = "-", mul = "\195\151" } -- × as UTF-8

local MathsProblems = {}

function MathsProblems.make(cfg: MathsConfig, rng: ((number, number) -> number)?): Problem
	local roll = rng or function(min: number, max: number)
		return math.random(min, max)
	end
	local a = roll(cfg.Min, cfg.Max)
	local b = roll(cfg.Min, cfg.Max)
	local op = cfg.Operation
	local answer
	if op == "add" then
		answer = a + b
	elseif op == "sub" then
		-- Keep answers non-negative for young kids.
		if b > a then
			a, b = b, a
		end
		answer = a - b
	elseif op == "mul" then
		answer = a * b
	else
		error(("MathsProblems: unknown operation %q"):format(tostring(op)))
	end
	return {
		text = string.format("%d %s %d = ?", a, SYMBOLS[op], b),
		answer = answer,
		a = a,
		b = b,
		op = op,
	}
end

-- The server checks raw client input here — never trust a client-side verdict.
function MathsProblems.check(problem: Problem, submitted: unknown): boolean
	local n = tonumber(submitted)
	return n ~= nil and n == problem.answer
end

return MathsProblems
