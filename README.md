# Obby-blob — Solo Disaster

A single-player Roblox disaster-survival mode. You spawn on a private arena, a
random disaster strikes, and you try to survive the timer. When the round ends
— whether you survive or get wiped out — a **Play Again** button appears so you
can jump straight into another round on your own.

## How it works

- **Solo:** every player gets their own private arena and their own round, so
  pressing *Play Again* restarts *your* round instantly without waiting on
  anyone else.
- **Play Again:** the round-end menu shows a big button that starts a fresh
  round. It says *Play* the first time and *Play Again* after every round.
- **Disasters:** each round randomly picks one of `Flood`, `FallingBlobs`, or
  `Earthquake`.

## Project layout

This is a [Rojo](https://rojo.space/) project.

```
default.project.json                 Rojo mapping
src/shared/GameConfig.lua            Shared config + remote names (ReplicatedStorage)
src/server/DisasterSolo.server.lua   Round logic, arenas, disasters, Play Again
src/client/PlayAgainGui.client.lua   Round-end menu + Play Again button
```

## Running it

1. Install [Rojo](https://rojo.space/docs/).
2. From the project root: `rojo serve`
3. Connect from Roblox Studio with the Rojo plugin and press Play.

Tune the round in `src/shared/GameConfig.lua` (`RoundDuration`, `ArenaSize`,
`SpawnHeight`, and the `Disasters` list).
