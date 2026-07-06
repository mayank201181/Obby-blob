# Obby-blob

A kid-friendly educational Roblox game — **Solo Disaster** — plus a Claude
Code plugin marketplace that packages the reusable recipe behind it.

Each player gets their **own arena**: survive a rising flood for 30 seconds,
and push the water back by answering maths sums (Year 1–2 addition by
default). Wrong answers are fail-soft — encouraging retry, never a
punishment. One big button: **Play**, then **Play Again**.

## Play / develop the game

The game is a text-only [Rojo](https://rojo.space/) project — no Studio
assets; arenas, hazards, and UI are all generated in code.

| | |
|---|---|
| Build a place file | `rojo build default.project.json -o build/ObbyBlobSoloDisaster.rbxlx` |
| Open in Studio | open the built `.rbxlx` (Windows/macOS), or `rojo serve` + Rojo plugin |
| Headless smoke + play (Linux/CI) | see [.claude/skills/run-obby-blob/SKILL.md](.claude/skills/run-obby-blob/SKILL.md) |

Layout:

```
src/shared/GameConfig.lua        -- tuning + RemoteEvent names + maths settings
src/shared/MathsProblems.lua     -- problem generator/checker (pure, testable)
src/shared/RoundKernel.lua       -- per-player round lifecycle (pure, testable)
src/server/DisasterSolo.server.lua  -- arenas, flood, timers, remotes (authority)
src/client/PlayAgainGui.client.lua  -- menu, question prompt, feedback
```

## Use the plugin marketplace

In Claude Code:

```
/plugin marketplace add mayank201181/Obby-blob
/plugin install kids-edu-game@obby-blob
```

The **kids-edu-game** plugin ships the skill for building games like this
one: solo replay loop, re-entrant `roundId` rounds, per-player arenas, and
four patterns for gating gameplay behind maths problems, with pedagogy
guardrails.

## Docs

- [docs/HANDOFF.md](docs/HANDOFF.md) — current state, invariants, next steps
- [.claude/skills/kids-edu-game/SKILL.md](.claude/skills/kids-edu-game/SKILL.md) — the build recipe
- [.claude/skills/run-obby-blob/SKILL.md](.claude/skills/run-obby-blob/SKILL.md) — how to run/drive/test
