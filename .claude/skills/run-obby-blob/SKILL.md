---
name: run-obby-blob
description: Build, run, test, and drive Obby-blob (Solo Disaster), the kid-friendly educational Roblox game in this repo. Use when asked to run the game, play a round, run the smoke tests, build the .rbxlx place file, or verify a change to the round lifecycle or maths gating.
---

Obby-blob / Solo Disaster is a Roblox (Luau) game synced with Rojo. Roblox has
no Linux runtime, so on this container you drive it headlessly with `lune`
through `.claude/skills/run-obby-blob/driver.luau`, which exercises the real
game brain (`src/shared/RoundKernel.lua` + `MathsProblems.lua` — the layer
almost every PR touches). `rojo build` verifies the full project tree compiles
into a place file.

All paths are relative to the repo root.

## Prerequisites

`rojo` and `lune` are Rust tools. GitHub release downloads are blocked by the
egress proxy in Claude Code cloud containers, but crates.io is allowlisted, so
install from source (each takes ~4–6 min; run them in parallel, in the
background):

```bash
cargo install rojo --locked   # Rojo 7.7.0 verified
cargo install lune --locked   # lune 0.10.5 verified
export PATH="$HOME/.cargo/bin:$PATH"
```

## Build

```bash
rojo build default.project.json -o build/ObbyBlobSoloDisaster.rbxlx
```

Produces the openable Studio place file (~19 KB). `build/` is gitignored —
Luau sources are the source of truth.

## Run (agent path)

**Smoke suite** — 21 assertions over the round lifecycle (Play Again spam
guard, stale-round cancellation, answer gating, fail-soft feedback) and the
maths generator (all three operations). Exits non-zero on failure:

```bash
lune run .claude/skills/run-obby-blob/driver.luau
# ...
# == ALL PASS ==
```

**Play a round** — turn-based text mode over the same kernel. With a seed the
question sequence is reproducible, so you can drive it blind over a pipe: run
once with empty input to see the questions, then pipe the answers. For seed 42
the sums are 6+3, 5+6, 6+8, 5+7, 7+9:

```bash
printf '9\n11\n14\n12\n16\nn\n' | lune run .claude/skills/run-obby-blob/driver.luau play 42
# >> You Did It! You beat the flood!   (exit 0)
```

Wrong answers raise the water (five in a row from the start drowns you —
useful for testing the "died" path):

```bash
printf '0\n0\n0\n0\n0\nn\n' | lune run .claude/skills/run-obby-blob/driver.luau play 42
# >> Try Again! The flood got you — have another go!
```

For adaptive interactive play, use tmux — but run the whole exchange in a
single shell invocation (see Gotchas):

```bash
tmux new-session -d -s obby -x 100 -y 40 "PATH=$HOME/.cargo/bin:$PATH lune run .claude/skills/run-obby-blob/driver.luau play"
timeout 15 bash -c 'until tmux capture-pane -t obby -p | grep -q "your answer"; do sleep 0.2; done'
tmux capture-pane -t obby -p | grep QUESTION:   # read the sum
tmux send-keys -t obby "9" Enter                # answer it
```

## Run (human path)

Open `build/ObbyBlobSoloDisaster.rbxlx` in Roblox Studio (Windows/macOS only)
and press Play, or `rojo serve` + the Rojo Studio plugin for live sync. Not
possible on this container — Roblox ships no Linux client.

## Test

The smoke suite above is the test suite (`lune run
.claude/skills/run-obby-blob/driver.luau`). No other test runner exists.

## Gotchas

- **GitHub releases are proxy-blocked** in cloud containers (403 with a JSON
  "access not enabled" body), so `rokit`/`aftman`/binary downloads for rojo and
  lune all fail. `cargo install` from crates.io is the working path.
- **tmux sessions die between separate Bash tool invocations** in this
  sandbox ("no server running on /tmp/tmux-0/default"). Do the whole
  launch → interact → capture dance in one invocation, or prefer the piped
  mode, which needs no tmux.
- **`stdio.prompt` requires a TTY** — piped stdin throws "IO error: not a
  terminal". The driver catches that and falls back to `stdio.readLine`
  (which keeps the trailing `\n` and returns `""` forever at EOF; the driver
  treats a blank line as quit).
- **Keep shared modules dependency-free.** Roblox resolves `require` by
  Instance, lune by path — `RoundKernel.lua` and `MathsProblems.lua` require
  nothing so both runtimes load them unchanged. If you add a cross-module
  require to `src/shared/`, the lune driver will break.
- **Luau-only syntax is fine** (`+=`, generalized iteration, `--!strict`):
  lune runs real Luau, including in `.lua`-extension files.

## Troubleshooting

- **`error: could not find ... in registry` / 403 JSON from GitHub**: you
  tried a release download; use `cargo install` (see Prerequisites).
- **`IO error: not a terminal`**: you're on an old driver revision piping into
  `stdio.prompt`; current driver falls back automatically.
- **Smoke prints `FAIL kernel: ...`**: a lifecycle invariant broke — almost
  always a change to `RoundKernel.lua` that skipped the `roundIsCurrent`
  guard or the `active` flag. The failing line names the invariant.
