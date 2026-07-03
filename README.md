# Obby-blob

A single-player Roblox game with four solo modes. Pick a mode from the menu:

- **Solo Disaster** — you spawn on a private arena, a random disaster
  (`Flood`, `FallingBlobs`, or `Earthquake`) strikes, and you try to survive
  the timer. When the round ends — survive or get wiped out — a **Play
  Again** button instantly starts a fresh round (it respawns you first, so it
  always works even right after you die).
- **Easy Obby / Hard Obby** — private floating courses with green checkpoint
  pads, red platforms that vanish shortly after you step on them, and a gold
  finish pad at the end.
- **Endless Obby** — the course grows every time you reach the newest
  checkpoint, and each new segment is a little harder.

## Obby controls

- **Restart** button (or the **R** key) — instantly brings back every red
  platform and teleports you to the checkpoint you last touched, so a
  vanished red platform can never leave you stranded.
- **Quit to Menu** — leave the course and return to the mode menu.

## Project layout

This is a [Rojo](https://rojo.space/) project.

```
default.project.json                 Rojo mapping
src/shared/GameConfig.lua            Shared config + remote names (ReplicatedStorage)
src/server/DisasterSolo.server.lua   Disaster arenas, rounds, Play Again
src/server/ObbySolo.server.lua       Obby courses, checkpoints, red platforms, Restart
src/client/SoloMenu.client.lua       Mode menu + round-over / course-complete panel
src/client/ObbyHud.client.lua        In-course HUD with Restart / Quit
```

## Running it

1. Install [Rojo](https://rojo.space/docs/).
2. From the project root: `rojo serve`
3. Connect from Roblox Studio with the Rojo plugin and press Play.

Tune everything in `src/shared/GameConfig.lua` — disaster round settings
(`RoundDuration`, `ArenaSize`, …) and per-mode obby settings under
`GameConfig.Obby.Modes` (platform sizes, gaps, red-platform chance, vanish
delay, and the Endless difficulty ramp).
