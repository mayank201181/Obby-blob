# Obby-blob — Solo Disaster · Handoff Document

**Repo:** `mayank201181/Obby-blob`
**Branch:** `claude/solo-disaster-replay-5oxk5k` · **PR:** [#1](https://github.com/mayank201181/Obby-blob/pull/1)
**Engine:** Roblox (Luau) · **Sync:** [Rojo](https://rojo.space/)

---

## 1. What the game is

**Solo Disaster** is a single-player Roblox disaster-survival mode. A player
spawns on a private arena, a random disaster strikes, and they try to survive a
timer. When the round ends — survive **or** get wiped out — a **Play Again**
button appears so they can immediately start another round on their own.

The headline feature (the original request) is the **Play Again** loop: in solo
mode, finishing a round should let you replay instantly without waiting on
anyone else.

---

## 2. Player experience (round flow)

```
join ─────────────► private arena built, round-end menu shown ("Play")
  │
  ▼
press Play ────────► random disaster runs on the arena
  │
  ├── survive timer ─► "You Survived!"  + Play Again
  └── die ───────────► "You Got Wiped Out!" + Play Again
                         │
                         ▼
                   press Play Again ─► fresh round (loops back up)
```

- **Solo:** every player gets their **own** arena and their **own** round, so
  one player's *Play Again* never affects or waits on another.
- **Play Again button:** one button in the round-end menu. Reads **Play** for the
  first round and **Play Again** afterwards.
- **Disasters:** each round randomly picks one of `Flood`, `FallingBlobs`,
  `Earthquake`.

---

## 3. Architecture

Three scripts split by boundary (server authority, client UI, shared constants):

| File | Runs on | Responsibility |
| --- | --- | --- |
| `src/shared/GameConfig.lua` | Both (ReplicatedStorage) | Tuning values + RemoteEvent names |
| `src/server/DisasterSolo.server.lua` | Server | Arenas, disasters, round lifecycle, `PlayAgain` remote |
| `src/client/PlayAgainGui.client.lua` | Client | Round-end menu + Play Again button |
| `default.project.json` | — | Rojo mapping of the above into the DataModel |

### RemoteEvents (created by the server in `ReplicatedStorage`)

| Name | Direction | Payload | Meaning |
| --- | --- | --- | --- |
| `PlayAgain` | client → server | — | player pressed Play / Play Again |
| `RoundStarted` | server → client | `disasterName` | a round began (hide the menu) |
| `RoundEnded` | server → client | `result`, `disasterName` | round finished (`"survived"` / `"died"` / `"ready"`) |

### Server round lifecycle (the important bit)

Each player has server-side state:

```lua
state[player] = {
  arena    = Model,   -- their private arena
  floorTop = number,  -- Y of the arena floor surface
  roundId  = number,  -- increments every round
  active   = boolean, -- is a round running
}
```

The key safety mechanism is **`roundId`**. Every disaster runs its own loop
(`while roundIsCurrent(player, roundId) do ...`). When a new round starts,
`roundId` is bumped, which makes every leftover loop from the previous round
exit immediately. That is what makes **Play Again safe to spam** — you can't
stack two rounds' hazards on top of each other. The server also ignores
`PlayAgain` while a round is already `active`.

### Disasters (all spawned in code — no Studio-built assets needed)

- **Flood** — a `Water` part rises from below the floor; touching it is lethal.
- **FallingBlobs** — red balls drop from above on a timer; touch = death.
- **Earthquake** — the solid floor is hidden and replaced with tiles that
  randomly drop away, forcing the player to keep moving.

---

## 4. How to run it

1. Install [Rojo](https://rojo.space/docs/).
2. From the repo root: `rojo serve`
3. In Roblox Studio, connect via the Rojo plugin and press **Play**.

Tune everything in `src/shared/GameConfig.lua`:

| Value | Effect |
| --- | --- |
| `RoundDuration` | seconds you must survive to win |
| `ArenaSize` | width/depth of the arena (studs) |
| `SpawnHeight` | Y height the arena floats at |
| `Disasters` | the list a round randomly picks from |

---

## 5. Build process (how this was made)

This is the repeatable process — captured in full in the **`kids-edu-game`
skill** (`.claude/skills/kids-edu-game/SKILL.md`) so it can be reused.

1. **Clarify the core loop.** The request was "in solo, Play Again lets you play
   again." Everything else (arena, disasters, GUI) exists to serve that loop.
2. **Choose a sync-friendly layout.** Rojo project with `src/shared`,
   `src/server`, `src/client`. No binary `.rbxl` — everything is text and
   diff-able.
3. **Model state per player.** Solo means per-player arenas + per-player rounds,
   not one shared world.
4. **Make the loop re-entrant.** A monotonic `roundId` cancels stale work so the
   replay button can't corrupt state.
5. **Generate content in code.** Arenas and hazards are built at runtime, so the
   game runs with zero pre-built assets.
6. **Split client/server on authority.** Server owns truth (health, hazards,
   timer); client only renders the menu and sends button presses.
7. **Ship as a draft PR** with a full description, then verify state on a loop.

### Verification note

No Luau linter/toolchain was available in the build environment, so scripts were
reviewed manually rather than statically analysed. The logic was walked through
by hand (round lifecycle, `roundId` guards, remote wiring). A real Studio
playtest is the recommended final check before merge.

---

## 6. Extending it (next steps / ideas)

- **Add maths concepts** (the reason the skill exists): gate survival behind
  solving a problem — e.g. a falling-blob only clears when you answer its sum, or
  a flood recedes each time you solve a question. See the skill's "Weaving in
  maths" section for drop-in patterns.
- **Score / streak tracking** across replays (leaderstats).
- **More disasters** — add a function to the `Disasters` table and its name to
  `GameConfig.Disasters`; no other wiring needed.
- **Difficulty ramp** — scale `RoundDuration` or hazard rate by streak.
- **Persistence** — DataStore for high scores / longest survival.

---

## 7. Status

- Code complete on `claude/solo-disaster-replay-5oxk5k`, pushed.
- Draft PR #1 open; no CI configured on the repo, no review comments.
- Awaiting Studio playtest + review/merge.
