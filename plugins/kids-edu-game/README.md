# kids-edu-game (Claude Code plugin)

Reusable recipe for building **kid-friendly educational Roblox (Luau) games**
with a solo **Play Again** loop and drop-in patterns for embedding maths
concepts (addition, subtraction, times tables, fractions, number sense).

Once installed, invoke it in any session with `/kids-edu-game`.

## Install (one time, in your local Claude Code)

```
/plugin marketplace add mayank201181/Obby-blob
/plugin install kids-edu-game
```

After that it is registered globally in `~/.claude/` and available in **every
new session, any repo**.

## What it contains

- `skills/kids-edu-game/SKILL.md` — the full build recipe (project layout,
  re-entrant round lifecycle, Play Again menu, and maths-gating patterns).

## Reference implementation

The *Solo Disaster* game in the repo root (`src/`) is the canonical example the
skill is based on.
