# 🎨 Sketch to Reality

**Draw anything in 3D — then step inside and live in it.**

Sketch to Reality is a browser game. You pick a colour, draw a house / a city / a chair /
anything you want in 3D, and when you press **Done** the AI Judge scores your art
and pays you coins. Then you can **explore your drawing in first person** — walk
around, sit on your chairs, open your doors, and go inside your houses. Spend the
coins you earn on fancy ink in the **Customisation Shop**.

## ▶️ How to play

Just open **`index.html`** in a web browser (double-click it, or drag it into
Chrome/Edge/Firefox). No install, no internet needed — three.js is bundled in
`vendor/`.

> If your browser blocks anything when opening the file directly, run a tiny
> local server instead and visit `http://localhost:8000`:
> ```bash
> python3 -m http.server 8000
> ```

## 🕹️ What you can do

### Drawing
1. Press **Start Drawing** and **pick any colour** (or a custom one).
2. Choose a tool on the left:
   - **🖌️ Brush** – free-draw glowing 3D lines (left-drag).
   - **🏠 House, 🚪 Door, 🪑 Chair, 🌳 Tree, 🧱 Wall, ⬛ Floor, 📦 Block, 🔵 Ball, 🟦 Pillar** – click to place.
   - **🧽 Erase** – click something to remove it.
3. **Right-drag** to orbit the camera, **scroll** to zoom, and use the
   **Height** slider to draw higher or lower.

### AI Judge (top-right 🤖)
Press **AI Judge** any time. It scores your art fast (0–100) and pays you:
- **Amazing (70+) → 🪙 100 coins**
- **Pretty good (40–69) → 🪙 50 coins**
- **Keep practising (under 40) → 🪙 10 coins**

It also shows a **score breakdown** and marks exactly **where you lost coins**
(e.g. "not enough colour variety") so you know what to improve.

### Keep Editing (top-left ✏️)
Not finished? Press **Keep Editing** to jump straight back into your drawing.

### Explore in real life 🌍
Press **Explore in Real Life** to walk through your creation in first person:
- **WASD / arrows** move, **mouse** looks, **Space** jumps.
- **E** to **sit on a chair** or **open/close a door**.
- Walk through doorways to go **inside your houses**.

### Save 💾
Press **Save** to keep a drawing. Find all your worlds under **Saves**, where you
can re-explore, edit, or delete them (each with a thumbnail).

### Customisation Shop 🛒
Spend your coins on better ink — the good stuff costs more:
| Item | Price | Effect |
|------|------:|--------|
| Pastel Pack | 🪙 40 | soft dreamy colours |
| Neon Pack | 🪙 60 | loud electric colours |
| Metallic Ink | 🪙 80 | shiny reflective ink |
| Rainbow Ink | 🪙 100 | ink cycles through every colour |
| Gold Pack | 🪙 200 | luxury golden colours |
| Glow Ink | 🪙 150 | ink glows in the dark |

### 🌐 Draw with Friends (real-time multiplayer)
Press **Draw with Friends** to build together live:
1. Enter a username + colour.
2. **Create Room** to get a room code, then **Copy invite link** and send it to a
   friend (the link opens the game with the code pre-filled). Or your friend can
   **Join a Room** by typing the code.
3. Press **Start Drawing Together** — now whatever either of you draws appears for
   both of you instantly, each in your own colour.
4. When you **Explore**, you'll see each other walking around as little avatars
   with name tags. 🧑‍🤝‍🧑

> Multiplayer is peer-to-peer (via [PeerJS](https://peerjs.com)'s free public
> signaling — no accounts or servers to run). Both players need to be online at
> the same time and share the room code, and it works best on normal home
> networks.

### Friends 👥
Make a **username** and pick your profile **colour**. To friend someone, type
their username and pick their colour — **your colours must match** to become
friends!

## 🧱 How it's built

- Plain HTML/CSS/JavaScript — no build step.
- 3D powered by [three.js](https://threejs.org) (bundled in `vendor/three.min.js`).
- All progress (coins, unlocks, saves, friends) is stored locally in your
  browser via `localStorage`.

```
index.html      # markup + all the game screens
style.css       # styling
game.js         # the whole game (drawing, judge, explore, shop, friends, saves)
vendor/three.min.js
```
