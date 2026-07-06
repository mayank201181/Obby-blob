--!strict
-- Per-player solo round lifecycle: the server-authoritative brain.
-- Pure module (no Roblox globals) so the same code that runs in game is
-- driven headlessly by .claude/skills/run-obby-blob/smoke.luau.
--
-- Load-bearing rules (see .claude/skills/kids-edu-game/SKILL.md section 2):
--   * every long-running loop must check roundIsCurrent(playerId, roundId)
--   * playAgain() while a round is active is a no-op — spam-safe
--   * answers are checked here, server-side; clients only submit raw input
--
-- Deliberately requires nothing: Roblox and lune resolve module paths
-- differently, and a dependency-free kernel loads identically in both.

export type Hooks = {
	onRoundStarted: ((playerId: any, roundId: number) -> ())?,
	onRoundEnded: ((playerId: any, result: string, detail: string) -> ())?,
	onAskQuestion: ((playerId: any, text: string) -> ())?,
	onAnswerFeedback: ((playerId: any, verdict: string, detail: string) -> ())?,
}

local RoundKernel = {}
RoundKernel.__index = RoundKernel

function RoundKernel.new(hooks: Hooks?)
	return setmetatable({
		_players = {}, -- playerId -> { roundId, active }
		_pending = {}, -- playerId -> { problem, roundId, onCorrect }
		_hooks = hooks or {},
	}, RoundKernel)
end

function RoundKernel:addPlayer(playerId)
	self._players[playerId] = { roundId = 0, active = false }
end

function RoundKernel:removePlayer(playerId)
	self._players[playerId] = nil
	self._pending[playerId] = nil
end

function RoundKernel:getState(playerId)
	return self._players[playerId]
end

function RoundKernel:roundIsCurrent(playerId, roundId: number): boolean
	local s = self._players[playerId]
	return s ~= nil and s.active and s.roundId == roundId
end

-- Play Again: starts a fresh solo round. Returns the new roundId, or nil if
-- ignored (unknown player, or double-tap while a round is already running).
function RoundKernel:playAgain(playerId): number?
	local s = self._players[playerId]
	if not s then
		return nil
	end
	if s.active then
		return nil -- ignore double-taps mid-round
	end
	s.roundId += 1 -- cancels every stale loop still holding the old id
	s.active = true
	self._pending[playerId] = nil
	if self._hooks.onRoundStarted then
		self._hooks.onRoundStarted(playerId, s.roundId)
	end
	return s.roundId
end

function RoundKernel:endRound(playerId, result: string, detail: string)
	local s = self._players[playerId]
	if not s or not s.active then
		return
	end
	s.active = false -- stops timer + hazard loops via roundIsCurrent
	self._pending[playerId] = nil
	if self._hooks.onRoundEnded then
		self._hooks.onRoundEnded(playerId, result, detail)
	end
end

-- Ask a maths problem tied to the current round; onCorrect fires when the
-- child eventually gets it right (answer-to-survive gating).
function RoundKernel:askQuestion(playerId, problem, roundId: number, onCorrect: () -> ())
	if not self:roundIsCurrent(playerId, roundId) then
		return
	end
	self._pending[playerId] = { problem = problem, roundId = roundId, onCorrect = onCorrect }
	if self._hooks.onAskQuestion then
		self._hooks.onAskQuestion(playerId, problem.text)
	end
end

-- Raw client input lands here. Returns "correct" | "incorrect" | "ignored".
function RoundKernel:submitAnswer(playerId, submitted): string
	local q = self._pending[playerId]
	if not q or not self:roundIsCurrent(playerId, q.roundId) then
		return "ignored"
	end
	local n = tonumber(submitted)
	if n ~= nil and n == q.problem.answer then
		self._pending[playerId] = nil
		if self._hooks.onAnswerFeedback then
			self._hooks.onAnswerFeedback(playerId, "correct", "Nice!")
		end
		q.onCorrect()
		return "correct"
	end
	-- Fail soft: keep the same problem live, encourage a retry (section 4c).
	if self._hooks.onAnswerFeedback then
		self._hooks.onAnswerFeedback(playerId, "incorrect", "So close \226\128\148 try again!")
	end
	return "incorrect"
end

return RoundKernel
