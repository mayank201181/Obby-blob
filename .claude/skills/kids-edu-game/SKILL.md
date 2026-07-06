---
name: kids-edu-game
description: Build a kid-friendly educational Roblox (Luau) game with a solo replay loop and optional embedded maths concepts. Use when the user wants to create a Roblox game for kids — survival/obby/collection/quiz style — especially one that teaches or practises maths (addition, subtraction, multiplication, fractions, number sense, etc.), or wants a "Play Again"/solo-replay experience. Produces a Rojo project with per-player arenas, a re-entrant round lifecycle, and a Play Again menu, plus drop-in patterns for gating gameplay behind maths problems.
---

# kids-edu-game

A repeatable recipe for building a **kid-friendly educational Roblox game** in
Luau, synced with [Rojo](https://rojo.space/). It codifies the pattern first
built for *Obby-blob → Solo Disaster*: per-player solo arenas, a re-entrant
round lifecycle, and a **Play Again** menu — then extends it with reusable ways
to **weave maths concepts into the gameplay**.

Use this whenever the ask is "make a Roblox game for kids" and especially when
maths practice (sums, times tables, fractions, number sense) should be part of
the fun.

---

## 0. Before you build — clarify these

Ask (or pick sensible defaults) for:

1. **Age / year group** → sets maths difficulty and reading level.
2. **Maths concept(s)** → addition, subtraction, times tables, fractions,
   place value, comparison (`<`/`>`), etc.
3. **Game shape** → survival (disaster), obby (obstacle course), collection
   (grab correct answers), or quiz-arena. All four fit the same skeleton.
4. **How maths gates play** → answer-to-survive, answer-to-advance,
   answer-to-score, or answer-to-unlock. (See §4.)
5. **Solo or shared?** → for kids, default to **solo per-player** so no child is
   blocked by another. This skill assumes solo.

Keep the **core loop** front and centre: *attempt → succeed/fail → Play Again*.
Everything else serves that loop.

---

## 1. Project layout (Rojo, text-only, diff-able)

```
default.project.json
src/shared/GameConfig.lua            -- tuning + RemoteEvent names
src/server/<Game>.server.lua         -- authority: arenas, rounds, maths checks
src/client/<Game>Gui.client.lua      -- UI: menu, question prompt, Play Again
docs/HANDOFF.md                      -- always leave a handoff
.claude/skills/kids-edu-game/        -- this skill
```

`default.project.json`:

```json
{
  "name": "<GameName>",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": { "$path": "src/shared" },
    "ServerScriptService": { "$path": "src/server" },
    "StarterPlayer": {
      "StarterPlayerScripts": { "$path": "src/client" }
    }
  }
}
```

**Never** commit a binary `.rbxl` as the source of truth — keep everything Luau
so it is reviewable and diff-able. Generate arenas/hazards **in code** so the
game runs with zero pre-built Studio assets.

---

## 2. The five load-bearing principles

1. **Per-player state.** Solo = each player gets their own arena + round.
   Offset arenas in world space so they never overlap.
2. **Re-entrant rounds via a monotonic `roundId`.** Every long-running loop
   checks `roundIsCurrent(player, roundId)`. Bumping `roundId` on a new round
   cancels all stale work — this is what makes **Play Again safe to spam**.
3. **Server owns truth.** Health, hazards, timers, and **answer-checking** live
   on the server. The client only renders and sends intents. Never trust a
   client-submitted "I answered correctly".
4. **Generate content in code.** Arenas, hazards, and question props are built
   at runtime.
5. **One button, clear states.** The round-end menu's single button reads
   **Play** first, **Play Again** after. Kids should never hunt for how to retry.

---

## 3. Reusable skeletons

### 3a. `GameConfig.lua` (shared)

```lua
local GameConfig = {}

GameConfig.Remotes = {
  PlayAgain     = "PlayAgain",     -- client -> server: play / replay
  RoundStarted  = "RoundStarted",  -- server -> client: hide menu
  RoundEnded    = "RoundEnded",    -- server -> client: result + detail
  AskQuestion   = "AskQuestion",   -- server -> client: show a maths problem
  AnswerQuestion= "AnswerQuestion",-- client -> server: submit an answer
}

GameConfig.RoundDuration = 30
GameConfig.ArenaSize     = 60
GameConfig.SpawnHeight   = 50

-- Maths settings (see §4)
GameConfig.Maths = {
  Enabled   = true,
  Operation = "add",   -- "add" | "sub" | "mul"
  Min       = 1,
  Max       = 10,
}

return GameConfig
```

### 3b. Server round lifecycle (authority)

```lua
-- Per player: { arena, floorTop, roundId, active }
local state = {}

local function roundIsCurrent(player, roundId)
  local s = state[player]
  return s ~= nil and s.active and s.roundId == roundId
end

local function startRound(player)
  local s = state[player]; if not s then return end
  s.roundId += 1                 -- cancels every stale loop
  local roundId = s.roundId
  s.active = true
  -- clear hazards, teleport player onto their arena, pick + run content...
  RoundStartedRemote:FireClient(player, detail)
end

local function endRound(player, result, detail)
  local s = state[player]; if not s or not s.active then return end
  s.active = false               -- stops timer + hazard loops
  -- clear hazards...
  RoundEndedRemote:FireClient(player, result, detail)
end

-- THE core feature: Play Again starts a fresh solo round.
PlayAgainRemote.OnServerEvent:Connect(function(player)
  local s = state[player]; if not s then return end
  if s.active then return end    -- ignore double-taps mid-round
  startRound(player)
end)
```

Any hazard loop follows this shape so it self-cancels:

```lua
task.spawn(function()
  while roundIsCurrent(player, roundId) do
    -- spawn/advance one hazard tick
    task.wait(0.5)
  end
end)
```

### 3c. Client Play Again menu

```lua
button.Activated:Connect(function()
  button.Active = false          -- debounce until the round starts
  PlayAgainRemote:FireServer()
end)

RoundStartedRemote.OnClientEvent:Connect(hideMenu)

RoundEndedRemote.OnClientEvent:Connect(function(result, detail)
  if result == "survived" then showMenu("You Did It!", detail, "Play Again")
  elseif result == "died"  then showMenu("Try Again!",  detail, "Play Again")
  else                          showMenu("Ready?",      "",     "Play") end
end)
```

---

## 4. Weaving in maths (the educational core)

Keep maths **generation and checking on the server**. Four gating patterns —
pick per game shape:

| Pattern | Fits | How it works |
| --- | --- | --- |
| **Answer-to-survive** | survival/disaster | a hazard only clears when the child solves its problem |
| **Answer-to-advance** | obby | a gate/door opens on a correct answer |
| **Answer-to-score** | collection | grab the block with the correct answer; wrong = penalty |
| **Answer-to-unlock** | quiz-arena | streak of N correct unlocks a reward/new area |

### 4a. Problem generator (server)

```lua
-- Deterministic-free randomness: vary by an incrementing counter, NOT os.time,
-- so it stays testable. In Roblox, math.random is fine at runtime.
local function makeProblem(cfg)
  local a = math.random(cfg.Min, cfg.Max)
  local b = math.random(cfg.Min, cfg.Max)
  local op, answer = cfg.Operation, nil
  if op == "add" then answer = a + b
  elseif op == "sub" then if b > a then a, b = b, a end; answer = a - b
  elseif op == "mul" then answer = a * b end
  local symbol = ({ add = "+", sub = "-", mul = "×" })[op]
  return { text = string.format("%d %s %d = ?", a, symbol, b), answer = answer }
end
```

### 4b. Gate a hazard behind a correct answer (answer-to-survive)

```lua
-- pendingAnswer[player] = { answer = n, onCorrect = fn, roundId = n }
local pendingAnswer = {}

local function askAndGate(player, roundId, onCorrect)
  local p = makeProblem(GameConfig.Maths)
  pendingAnswer[player] = { answer = p.answer, onCorrect = onCorrect, roundId = roundId }
  AskQuestionRemote:FireClient(player, p.text)
end

AnswerQuestionRemote.OnServerEvent:Connect(function(player, submitted)
  local q = pendingAnswer[player]
  if not q or not roundIsCurrent(player, q.roundId) then return end
  if tonumber(submitted) == q.answer then          -- SERVER checks, never client
    pendingAnswer[player] = nil
    q.onCorrect()                                    -- clear the flood / open the gate
  else
    -- gentle fail: reduce timer, replay the question, or small penalty
    AskQuestionRemote:FireClient(player, "Try again! " .. tostring(q.answer and "" or ""))
  end
end)
```

### 4c. Pedagogy guardrails (make it good learning, not just a quiz skin)

- **Age-appropriate ranges.** Y1–2: sums to 20. Y3–4: times tables to 12.
  Y5–6: fractions, multi-step. Drive it from `GameConfig.Maths`.
- **Fail soft.** Wrong answers should teach, not punish — show the correct
  answer, let them retry, never a hard game-over on a maths slip for young kids.
- **Progressive difficulty.** Ramp `Min`/`Max` or switch `Operation` as a streak
  grows.
- **Readable + friendly UI.** Big fonts, high contrast, encouraging copy
  ("Nice!", "So close — try again!"). No dense text.
- **Immediate feedback.** Correct/incorrect must be instant and visible.
- **Reward mastery.** Track streaks; unlock cosmetics/areas for consistency, not
  speed alone (avoid punishing slower kids).

---

## 5. Build order (checklist)

1. Confirm age, maths concept, game shape, gating pattern (§0).
2. Create `default.project.json` + `src/{shared,server,client}`.
3. Write `GameConfig.lua` (tuning + remotes + maths settings).
4. Server: per-player arenas, `roundId` lifecycle, Play Again handler.
5. Server: content (hazards/obstacles/collectibles) as self-cancelling loops.
6. Server: maths generator + answer-checking gate (§4).
7. Client: round-end menu (Play/Play Again) + question prompt UI.
8. Wire the RemoteEvents on both ends.
9. Verify by walking the loop by hand; if a Luau toolchain (`selene`,
   `luau-analyze`, `rojo`) exists, run it — otherwise note manual review only.
10. Write `docs/HANDOFF.md` (see the Obby-blob one as a template).
11. Commit, push to the feature branch, open a **draft PR** with a full body.

---

## 6. Gotchas learned

- **Spam-proof replay:** always guard loops with `roundId` and ignore
  `PlayAgain` while `active`. Without this, replays stack hazards.
- **Respawn teleport:** on `CharacterAdded`, wait for `HumanoidRootPart` then
  teleport onto the player's arena, or Roblox drops them at the default spawn.
- **Server-authoritative answers:** never let the client tell the server it was
  right — send the raw answer, check server-side.
- **No assets required:** building arenas/props in code means the game runs the
  moment Rojo syncs, with nothing to import.
- **Randomness in workflow/test contexts:** `os.time`/`os.clock`-seeded RNG is
  fine at Roblox runtime, but if you generate problems in a testable/replayable
  harness, vary by an incrementing index instead so runs reproduce.

---

## 7. Reference implementation

The *Solo Disaster* game in this repo is the canonical example of §1–§3:

- `src/shared/GameConfig.lua`
- `src/server/DisasterSolo.server.lua`
- `src/client/PlayAgainGui.client.lua`
- `docs/HANDOFF.md`

It ships the solo + Play Again loop; the maths layer in §4 is the drop-in
extension to turn it (or any new game built from this skill) into a maths-
teaching game.
