# HANDOFF — Obby-blob / Solo Disaster

## What exists

- **Solo Disaster**, a Rojo/Luau Roblox game: per-player solo arenas, a rising
  flood disaster, a 30 s survival timer, and maths **answer-to-survive**
  gating (correct sums push the flood down). Built entirely in code — no
  Studio assets.
- **Plugin marketplace** (`.claude-plugin/marketplace.json`) exposing the
  `kids-edu-game` plugin (`plugins/kids-edu-game/`), which packages the
  build recipe skill.
- **Skills**:
  - `.claude/skills/kids-edu-game/` — the recipe this game implements.
    `plugins/kids-edu-game/skills/kids-edu-game/SKILL.md` is a byte-for-byte
    copy for plugin distribution — **keep the two in sync** when editing.
  - `.claude/skills/run-obby-blob/` — verified instructions + `driver.luau`
    for building (`rojo`) and driving (`lune`) the game headlessly.

## Architecture invariants (do not break)

1. `src/shared/RoundKernel.lua` and `src/shared/MathsProblems.lua` are
   **pure and dependency-free** — no Roblox globals, no cross-requires — so
   the same files run in Roblox and under `lune` (CI/agents). Roblox-only
   code stays in `src/server/` and `src/client/`.
2. Every long-running server loop checks `kernel:roundIsCurrent(player,
   roundId)`; `playAgain` while active is a no-op. This is what makes Play
   Again spam-safe.
3. Answers are checked server-side in `RoundKernel:submitAnswer` from raw
   client input. Never accept a client-side verdict.
4. Fail soft: wrong answers re-prompt with encouragement; no hard game-over
   on a maths slip.

## Verified state (2026-07-06, Linux container)

- `rojo build` → `build/ObbyBlobSoloDisaster.rbxlx` (Rojo 7.7.0).
- `lune run .claude/skills/run-obby-blob/driver.luau` → 21/21 PASS
  (lune 0.10.5).
- Text-mode round played end-to-end: win path, drown path, Play Again
  re-entry, piped and tmux drives.
- Not yet opened in Roblox Studio (no Windows/macOS here) — the GUI layout in
  `PlayAgainGui.client.lua` compiles and follows stock patterns but has never
  been seen rendered. First Studio session should eyeball it.

## Next steps (suggested)

- Playtest in Studio; tune `FloodRiseStep` / `QuestionEverySeconds` for real
  kids.
- Progressive difficulty: ramp `GameConfig.Maths.Max` (or switch to `mul`)
  on answer streaks — the kernel already reports correct/incorrect verdicts.
- More disasters (meteors, crumbling floor) as additional self-cancelling
  loops behind the same kernel.
- Streak rewards (cosmetics), per section 4c of the kids-edu-game skill.
