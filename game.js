/* =========================================================================
   BlobWorld — draw anything in 3D, then explore it in first person.
   Single-page game. All state persists in localStorage.
   Uses the vendored global `THREE` (see index.html). No build step, no CDN.
   ========================================================================= */
(function () {
'use strict';

/* ----------------------------- persistence ----------------------------- */
const LS_KEY = 'blobworld_v1';
const defaultData = {
  coins: 60,
  unlocks: {},          // effect/palette id -> true
  saves: [],            // { id, name, date, thumb, world }
  profile: null,        // { name, color }
  friends: [],          // { name, color }
};
function load() {
  try { return { ...structuredClone(defaultData), ...JSON.parse(localStorage.getItem(LS_KEY) || '{}') }; }
  catch { return structuredClone(defaultData); }
}
function save() { localStorage.setItem(LS_KEY, JSON.stringify(data)); }
let data = load();

/* ----------------------------- catalog ----------------------------- */
// Base colours everyone gets.
const BASE_COLORS = ['#ff595e','#ff924c','#ffd166','#8ac926','#38d996','#4cc9f0','#5a8bff','#9b5de5','#f15bb5','#ffffff','#000000','#7a5230'];
// Palettes unlockable in the shop.
const PALETTES = {
  pastel: ['#ffd6e0','#c1f0dc','#bfe3ff','#fff3bf','#e5d4ff','#ffe0c2'],
  neon:   ['#ff00e6','#00fff2','#faff00','#00ff5e','#ff2d00','#c400ff'],
  gold:   ['#ffd700','#ffec8b','#c9a227','#fff2b0'],
};

// Shop items. "effect" items add an ink effect; "palette" items add colours.
const SHOP = [
  { id:'pastel',   kind:'palette', name:'Pastel Pack',  price:40,  desc:'Soft dreamy colours.', preview:'linear-gradient(90deg,#ffd6e0,#bfe3ff,#fff3bf)' },
  { id:'neon',     kind:'palette', name:'Neon Pack',    price:60,  desc:'Loud electric colours.', preview:'linear-gradient(90deg,#ff00e6,#00fff2,#faff00)' },
  { id:'metallic', kind:'effect',  name:'Metallic Ink', price:80,  desc:'Shiny reflective ink.', preview:'linear-gradient(90deg,#b8b8b8,#f0f0f0,#8a8a8a)' },
  { id:'rainbow',  kind:'effect',  name:'Rainbow Ink',  price:100, desc:'Ink cycles through every colour.', preview:'linear-gradient(90deg,#ff0000,#ffff00,#00ff00,#00ffff,#0000ff,#ff00ff)' },
  { id:'gold',     kind:'palette', name:'Gold Pack',    price:200, desc:'Luxury golden colours.', preview:'linear-gradient(90deg,#ffd700,#fff2b0,#c9a227)' },
  { id:'glow',     kind:'effect',  name:'Glow Ink',     price:150, desc:'Ink glows in the dark — very cool.', preview:'linear-gradient(90deg,#4cffd0,#00ffea,#4cffd0)' },
];

// Drawing tools. brush = freehand; the rest place an object.
const TOOLS = [
  { id:'brush',    label:'Brush',  ico:'🖌️' },
  { id:'floor',    label:'Floor',  ico:'⬛' },
  { id:'wall',     label:'Wall',   ico:'🧱' },
  { id:'box',      label:'Block',  ico:'📦' },
  { id:'house',    label:'House',  ico:'🏠' },
  { id:'door',     label:'Door',   ico:'🚪' },
  { id:'chair',    label:'Chair',  ico:'🪑' },
  { id:'tree',     label:'Tree',   ico:'🌳' },
  { id:'sphere',   label:'Ball',   ico:'🔵' },
  { id:'cylinder', label:'Pillar', ico:'🟦' },
  { id:'erase',    label:'Erase',  ico:'🧽' },
];

/* ----------------------------- editor state ----------------------------- */
const editor = {
  color: '#4cc9f0',
  effect: 'none',
  tool: 'brush',
  height: 1.0,
  size: 0.14,
};
let world = { items: [] };     // current drawing being edited
let currentSaveId = null;      // if editing a loaded save

/* ----------------------------- three setup ----------------------------- */
const canvas = document.getElementById('scene');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const scene = new THREE.Scene();
scene.background = new THREE.Color('#12132a');
scene.fog = new THREE.Fog('#12132a', 40, 120);

const worldGroup = new THREE.Group();   // holds all drawn item meshes
scene.add(worldGroup);

// lights
const hemi = new THREE.HemisphereLight('#dfe9ff', '#2a2540', 0.9);
scene.add(hemi);
const sun = new THREE.DirectionalLight('#ffffff', 1.15);
sun.position.set(12, 22, 8);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -40; sun.shadow.camera.right = 40;
sun.shadow.camera.top = 40; sun.shadow.camera.bottom = -40;
sun.shadow.camera.far = 100;
scene.add(sun);

// cameras
const drawCamera = new THREE.PerspectiveCamera(55, 1, 0.1, 500);
drawCamera.position.set(9, 8, 12);
const fpCamera = new THREE.PerspectiveCamera(72, 1, 0.05, 500);

let activeCamera = drawCamera;

/* --- lightweight orbit controller for draw mode (right-drag rotate, wheel zoom) --- */
const orbit = {
  target: new THREE.Vector3(0, 1, 0),
  azimuth: -0.7, polar: 0.9, radius: 18,
  minR: 3, maxR: 80, minPolar: 0.15, maxPolar: Math.PI * 0.495,
  enabled: true,
  dragging: false, lastX: 0, lastY: 0,
  update() {
    this.radius = Math.max(this.minR, Math.min(this.maxR, this.radius));
    this.polar = Math.max(this.minPolar, Math.min(this.maxPolar, this.polar));
    const x = this.target.x + this.radius * Math.sin(this.polar) * Math.sin(this.azimuth);
    const y = this.target.y + this.radius * Math.cos(this.polar);
    const z = this.target.z + this.radius * Math.sin(this.polar) * Math.cos(this.azimuth);
    drawCamera.position.set(x, y, z);
    drawCamera.lookAt(this.target);
  },
};
// right-drag = rotate
canvas.addEventListener('contextmenu', e => { if (mode === 'draw' || mode === 'judge') e.preventDefault(); });
canvas.addEventListener('pointerdown', e => {
  if ((mode === 'draw' || mode === 'judge') && (e.button === 2 || e.button === 1)) {
    orbit.dragging = true; orbit.lastX = e.clientX; orbit.lastY = e.clientY;
  }
});
addEventListener('pointermove', e => {
  if (!orbit.dragging) return;
  orbit.azimuth -= (e.clientX - orbit.lastX) * 0.006;
  orbit.polar   -= (e.clientY - orbit.lastY) * 0.006;
  orbit.lastX = e.clientX; orbit.lastY = e.clientY;
});
addEventListener('pointerup', () => orbit.dragging = false);
canvas.addEventListener('wheel', e => {
  if (mode === 'draw' || mode === 'judge') { e.preventDefault(); orbit.radius *= (1 + Math.sign(e.deltaY) * 0.1); }
}, { passive: false });

// ground + grid (draw mode helpers)
const groundMat = new THREE.MeshStandardMaterial({ color: '#2b2f52', roughness: 1 });
const groundMesh = new THREE.Mesh(new THREE.PlaneGeometry(400, 400), groundMat);
groundMesh.rotation.x = -Math.PI / 2;
groundMesh.receiveShadow = true;
scene.add(groundMesh);

const grid = new THREE.GridHelper(60, 60, 0x4cc9f0, 0x2a2f5c);
grid.material.opacity = 0.35; grid.material.transparent = true;
scene.add(grid);

function resize() {
  const w = innerWidth, h = innerHeight;
  renderer.setSize(w, h);
  drawCamera.aspect = w / h; drawCamera.updateProjectionMatrix();
  fpCamera.aspect = w / h; fpCamera.updateProjectionMatrix();
}
addEventListener('resize', resize);
resize();

/* ----------------------------- materials ----------------------------- */
function makeMaterial(colorHex, effect) {
  const mat = new THREE.MeshStandardMaterial({ color: new THREE.Color(colorHex), roughness: 0.65, metalness: 0.05 });
  if (effect === 'glow') { mat.emissive = new THREE.Color(colorHex); mat.emissiveIntensity = 0.85; }
  if (effect === 'metallic') { mat.metalness = 0.9; mat.roughness = 0.18; }
  return mat;
}

/* ----------------------------- build meshes ----------------------------- */
// Returns an Object3D for an item. Meshes tagged userData.solid become colliders.
function buildItemMesh(item) {
  const g = new THREE.Group();
  g.userData.item = item;
  const mkMesh = (geo, solid = true, effect = item.effect) => {
    const m = new THREE.Mesh(geo, makeMaterial(item.color, effect));
    m.castShadow = true; m.receiveShadow = true; m.userData.solid = solid;
    return m;
  };

  switch (item.type) {
    case 'brush': {
      const pts = item.points.map(p => new THREE.Vector3(p[0], p[1], p[2]));
      if (pts.length < 2) {
        const s = new THREE.Mesh(new THREE.SphereGeometry(item.size, 12, 12), makeMaterial(item.color, item.effect));
        s.castShadow = true; g.add(s); break;
      }
      const curve = new THREE.CatmullRomCurve3(pts);
      const seg = Math.min(400, Math.max(8, pts.length * 6));
      const geo = new THREE.TubeGeometry(curve, seg, item.size, 8, false);
      let mat;
      if (item.effect === 'rainbow') {
        mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.5, emissiveIntensity: 0.3 });
        const pos = geo.attributes.position, colors = [];
        const tmp = new THREE.Color();
        // ring count = seg+1, each ring has (radialSegments+1)=9 verts
        const ring = 9;
        for (let i = 0; i < pos.count; i++) {
          const t = Math.floor(i / ring) / (seg);
          tmp.setHSL((t * 1.0) % 1, 0.85, 0.55);
          colors.push(tmp.r, tmp.g, tmp.b);
        }
        geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
      } else {
        mat = makeMaterial(item.color, item.effect);
      }
      const tube = new THREE.Mesh(geo, mat);
      tube.castShadow = true; tube.userData.solid = false;
      g.add(tube);
      break;
    }
    case 'floor': {
      const m = mkMesh(new THREE.BoxGeometry(4, 0.3, 4));
      m.userData.walkable = true;
      g.add(m); break;
    }
    case 'wall': { g.add(mkMesh(new THREE.BoxGeometry(4, 3, 0.4))); break; }
    case 'box':  { g.add(mkMesh(new THREE.BoxGeometry(1.4, 1.4, 1.4))); break; }
    case 'sphere': { g.add(mkMesh(new THREE.SphereGeometry(0.9, 24, 18))); break; }
    case 'cylinder': { g.add(mkMesh(new THREE.CylinderGeometry(0.5, 0.5, 3, 20))); break; }
    case 'tree': {
      const trunk = mkMesh(new THREE.CylinderGeometry(0.22, 0.3, 1.6, 10), true, 'none');
      trunk.material.color = new THREE.Color('#7a5230'); trunk.position.y = 0.8;
      const leaves = mkMesh(new THREE.SphereGeometry(1.1, 16, 14), false);
      leaves.position.y = 2.2;
      g.add(trunk, leaves); break;
    }
    case 'chair': {
      const c = item.color;
      const seat = mkMesh(new THREE.BoxGeometry(1, 0.18, 1)); seat.position.y = 0.9;
      const back = mkMesh(new THREE.BoxGeometry(1, 1, 0.16)); back.position.set(0, 1.4, -0.42);
      const legGeo = new THREE.BoxGeometry(0.14, 0.9, 0.14);
      const legs = [[0.4,0.45,0.4],[-0.4,0.45,0.4],[0.4,0.45,-0.4],[-0.4,0.45,-0.4]].map(p => {
        const l = mkMesh(legGeo.clone()); l.position.set(...p); return l;
      });
      g.add(seat, back, ...legs);
      g.userData.chair = true;              // sittable
      g.userData.seat = new THREE.Vector3(0, 1.05, 0);
      break;
    }
    case 'door': {
      // pivot group so it swings around the left edge
      const pivot = new THREE.Group();
      const panel = mkMesh(new THREE.BoxGeometry(1.2, 2.4, 0.14));
      panel.position.set(0.6, 1.2, 0);      // offset so pivot is the hinge edge
      const knob = new THREE.Mesh(new THREE.SphereGeometry(0.08, 10, 10), new THREE.MeshStandardMaterial({ color: '#ffd166', metalness: 0.6, roughness: 0.3 }));
      knob.position.set(1.05, 1.2, 0.09);
      pivot.add(panel, knob);
      g.add(pivot);
      g.userData.door = true; g.userData.pivot = pivot; g.userData.open = false;
      g.userData.solidMesh = panel;
      break;
    }
    case 'house': {
      // hollow room with a doorway gap on the +Z side, plus roof and an openable door
      const c = item.color;
      const W = 5, D = 5, H = 3, t = 0.3;
      const wallMat = () => makeMaterial(c, item.effect);
      const addWall = (w, h, d, x, y, z) => {
        const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), wallMat());
        m.position.set(x, y, z); m.castShadow = m.receiveShadow = true; m.userData.solid = true;
        g.add(m); return m;
      };
      // floor
      const fl = new THREE.Mesh(new THREE.BoxGeometry(W, 0.2, D), makeMaterial('#6b6f8f', 'none'));
      fl.position.y = 0.1; fl.receiveShadow = true; fl.userData.solid = true; fl.userData.walkable = true; g.add(fl);
      // back + sides
      addWall(W, H, t, 0, H/2, -D/2);
      addWall(t, H, D, -W/2, H/2, 0);
      addWall(t, H, D,  W/2, H/2, 0);
      // front wall split around a 1.4-wide doorway
      const doorW = 1.4;
      const side = (W - doorW) / 2;
      addWall(side, H, t, -(doorW/2 + side/2), H/2, D/2);
      addWall(side, H, t,  (doorW/2 + side/2), H/2, D/2);
      addWall(doorW, H - 2.2, t, 0, H - (H-2.2)/2, D/2); // lintel above door
      // roof
      const roof = new THREE.Mesh(new THREE.ConeGeometry(W * 0.85, 1.8, 4), makeMaterial(c, item.effect));
      roof.rotation.y = Math.PI / 4; roof.position.y = H + 0.8; roof.castShadow = true; roof.userData.solid = false;
      g.add(roof);
      // door in the gap
      const doorPivot = new THREE.Group();
      doorPivot.position.set(-doorW/2, 0, D/2);
      const panel = new THREE.Mesh(new THREE.BoxGeometry(doorW, 2.2, 0.12), makeMaterial('#8a5a2b', 'none'));
      panel.position.set(doorW/2, 1.1, 0); panel.castShadow = true; panel.userData.solid = true;
      doorPivot.add(panel);
      g.add(doorPivot);
      g.userData.door = true; g.userData.pivot = doorPivot; g.userData.open = false; g.userData.solidMesh = panel;
      break;
    }
    default: { g.add(mkMesh(new THREE.BoxGeometry(1,1,1))); }
  }

  if (item.pos) g.position.set(item.pos[0], item.pos[1], item.pos[2]);
  if (item.rot) g.rotation.y = item.rot;
  return g;
}

// Rebuild the entire worldGroup from world.items
function rebuildWorld() {
  worldGroup.clear();
  for (const item of world.items) worldGroup.add(buildItemMesh(item));
}

/* ============================ SCREEN ROUTER ============================ */
const screens = ['menu','color-screen','draw-ui','judge-screen','saves-screen','shop-screen','friends-screen','explore-hud'];
let mode = 'menu';   // menu | draw | judge | explore | ...
function show(id) {
  for (const s of screens) document.getElementById(s).classList.toggle('hidden', s !== id);
}
function setTopbar({ coins=false, keep=false, judge=false }) {
  document.getElementById('coin-badge').classList.toggle('hidden', !coins);
  document.getElementById('btn-keep-editing').classList.toggle('hidden', !keep);
  document.getElementById('btn-judge').classList.toggle('hidden', !judge);
}
function refreshCoins() {
  document.getElementById('coin-count').textContent = data.coins;
  document.getElementById('menu-coins').textContent = data.coins;
  document.getElementById('shop-coins').textContent = data.coins;
}
function toast(msg, ms = 1800) {
  const t = document.getElementById('toast');
  t.textContent = msg; t.classList.remove('hidden');
  clearTimeout(t._t); t._t = setTimeout(() => t.classList.add('hidden'), ms);
}

/* ----------------------------- go to menu ----------------------------- */
function goMenu() {
  mode = 'menu';
  exitExplore();
  show('menu');
  setTopbar({ coins: false });
  grid.visible = true;
  const u = document.getElementById('menu-user');
  u.textContent = data.profile ? `· 👤 ${data.profile.name}` : '';
  refreshCoins();
}

/* ============================ DRAW MODE ============================ */
function startNewDrawing() {
  world = { items: [] };
  currentSaveId = null;
  rebuildWorld();
  openColorScreen();
}
function openColorScreen() {
  show('color-screen');
  buildColorSwatches(document.getElementById('color-swatches'), false);
  document.getElementById('custom-color-input').value = editor.color;
}
function enterDrawMode() {
  mode = 'draw';
  activeCamera = drawCamera;
  orbit.enabled = true;
  grid.visible = true;
  groundMesh.visible = true;
  scene.background = new THREE.Color('#12132a');
  show('draw-ui');
  setTopbar({ coins: true, keep: false, judge: true });
  buildToolList();
  buildEffectSelect();
  buildColorSwatches(document.getElementById('draw-swatches'), true);
  document.getElementById('draw-color-input').value = editor.color;
  refreshCoins();
}

function buildColorSwatches(container, small) {
  container.innerHTML = '';
  const colors = [...BASE_COLORS];
  for (const [pid, cols] of Object.entries(PALETTES)) if (data.unlocks[pid]) colors.push(...cols);
  for (const c of colors) {
    const el = document.createElement('div');
    el.className = 'swatch' + (c.toLowerCase() === editor.color.toLowerCase() ? ' selected' : '');
    el.style.background = c;
    el.onclick = () => {
      editor.color = c;
      container.querySelectorAll('.swatch').forEach(s => s.classList.remove('selected'));
      el.classList.add('selected');
      const custom = document.getElementById(small ? 'draw-color-input' : 'custom-color-input');
      if (custom) custom.value = c;
    };
    container.appendChild(el);
  }
}

function buildToolList() {
  const list = document.getElementById('tool-list');
  list.innerHTML = '';
  for (const t of TOOLS) {
    const b = document.createElement('button');
    b.className = 'tool-btn' + (t.id === editor.tool ? ' selected' : '');
    b.innerHTML = `<span class="ico">${t.ico}</span>${t.label}`;
    b.onclick = () => { editor.tool = t.id; buildToolList(); };
    list.appendChild(b);
  }
}
function buildEffectSelect() {
  const sel = document.getElementById('effect-select');
  const opts = [['none','None']];
  if (data.unlocks.glow) opts.push(['glow','Glow ✨']);
  if (data.unlocks.rainbow) opts.push(['rainbow','Rainbow 🌈']);
  if (data.unlocks.metallic) opts.push(['metallic','Metallic']);
  sel.innerHTML = opts.map(([v,l]) => `<option value="${v}">${l}</option>`).join('');
  if (!opts.find(o => o[0] === editor.effect)) editor.effect = 'none';
  sel.value = editor.effect;
}

/* ---- pointer interaction for drawing ---- */
const raycaster = new THREE.Raycaster();
const ndc = new THREE.Vector2();
let drawPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
let activeStroke = null;      // { item, mesh }
let isDrawing = false;

function pointerToPlane(ev) {
  const r = canvas.getBoundingClientRect();
  ndc.x = ((ev.clientX - r.left) / r.width) * 2 - 1;
  ndc.y = -((ev.clientY - r.top) / r.height) * 2 + 1;
  raycaster.setFromCamera(ndc, drawCamera);
  drawPlane.constant = -editor.height;
  const hit = new THREE.Vector3();
  return raycaster.ray.intersectPlane(drawPlane, hit) ? hit : null;
}
function pointerPickItem(ev) {
  const r = canvas.getBoundingClientRect();
  ndc.x = ((ev.clientX - r.left) / r.width) * 2 - 1;
  ndc.y = -((ev.clientY - r.top) / r.height) * 2 + 1;
  raycaster.setFromCamera(ndc, drawCamera);
  const hits = raycaster.intersectObjects(worldGroup.children, true);
  if (!hits.length) return null;
  let o = hits[0].object;
  while (o && !o.userData.item && o.parent) o = o.parent;
  return o && o.userData.item ? o : null;
}

canvas.addEventListener('pointerdown', (ev) => {
  if (mode !== 'draw' || ev.button !== 0) return;
  const tool = editor.tool;
  if (tool === 'erase') {
    const obj = pointerPickItem(ev);
    if (obj) {
      const idx = world.items.indexOf(obj.userData.item);
      if (idx >= 0) { world.items.splice(idx, 1); worldGroup.remove(obj); toast('Erased'); }
    }
    return;
  }
  if (tool === 'brush') {
    const p = pointerToPlane(ev);
    if (!p) return;
    isDrawing = true;
    orbit.enabled = false;
    const item = { type: 'brush', color: editor.color, effect: editor.effect, size: editor.size, points: [[p.x, p.y, p.z]] };
    world.items.push(item);
    const mesh = buildItemMesh(item);
    worldGroup.add(mesh);
    activeStroke = { item, mesh };
  } else {
    // placeable object
    const p = pointerToPlane(ev);
    if (!p) return;
    const yBase = (tool === 'house' || tool === 'tree' || tool === 'door') ? 0 : editor.height;
    const item = { type: tool, color: editor.color, effect: editor.effect, pos: [p.x, yBase, p.z], rot: 0 };
    world.items.push(item);
    worldGroup.add(buildItemMesh(item));
    toast(TOOLS.find(t => t.id === tool).label + ' placed');
  }
});

canvas.addEventListener('pointermove', (ev) => {
  if (mode !== 'draw' || !isDrawing || !activeStroke) return;
  const p = pointerToPlane(ev);
  if (!p) return;
  const pts = activeStroke.item.points;
  const last = pts[pts.length - 1];
  const dx = p.x - last[0], dy = p.y - last[1], dz = p.z - last[2];
  if (dx*dx + dy*dy + dz*dz < 0.02) return; // throttle by distance
  pts.push([p.x, p.y, p.z]);
  worldGroup.remove(activeStroke.mesh);
  activeStroke.mesh = buildItemMesh(activeStroke.item);
  worldGroup.add(activeStroke.mesh);
});
function endStroke() {
  if (isDrawing) { isDrawing = false; activeStroke = null; orbit.enabled = true; }
}
canvas.addEventListener('pointerup', endStroke);
canvas.addEventListener('pointerleave', endStroke);

/* ---- draw UI controls ---- */
document.getElementById('effect-select').onchange = e => editor.effect = e.target.value;
document.getElementById('height-slider').oninput = e => {
  editor.height = parseFloat(e.target.value);
  document.getElementById('height-val').textContent = editor.height.toFixed(2);
};
document.getElementById('size-slider').oninput = e => editor.size = parseFloat(e.target.value);
document.getElementById('draw-color-input').oninput = e => {
  editor.color = e.target.value;
  document.querySelectorAll('#draw-swatches .swatch').forEach(s => s.classList.remove('selected'));
};
document.getElementById('custom-color-input').oninput = e => editor.color = e.target.value;

/* ============================ AI JUDGE ============================ */
function analyzeWorld() {
  const items = world.items;
  const brushes = items.filter(i => i.type === 'brush');
  const objects = items.filter(i => i.type !== 'brush');
  const structures = items.filter(i => ['house','chair','door','tree','floor','wall'].includes(i.type));

  // distinct colours
  const colorSet = new Set(items.map(i => (i.color || '').toLowerCase()));
  // total brush length
  let strokeLen = 0;
  for (const b of brushes) for (let i = 1; i < b.points.length; i++) {
    const a = b.points[i-1], c = b.points[i];
    strokeLen += Math.hypot(a[0]-c[0], a[1]-c[1], a[2]-c[2]);
  }
  // bounding box spread
  const box = new THREE.Box3();
  if (worldGroup.children.length) box.setFromObject(worldGroup);
  const size = new THREE.Vector3(); if (!box.isEmpty()) box.getSize(size);
  const spread = size.x * size.y * size.z;
  const typeSet = new Set(items.map(i => i.type));
  const effectsUsed = new Set(items.map(i => i.effect).filter(e => e && e !== 'none'));

  const clamp = v => Math.max(0, Math.min(100, v));
  const cats = [
    { key: 'Effort',        score: clamp((items.length * 7) + strokeLen * 4),
      weakNote: 'Not much drawn yet — add more strokes and objects.' },
    { key: 'Colour variety',score: clamp(colorSet.size * 22),
      weakNote: 'Try using more different colours.' },
    { key: 'Structures',    score: clamp(structures.length * 26),
      weakNote: 'Add real things — houses, chairs, doors, trees.' },
    { key: 'Size & scale',  score: clamp(Math.cbrt(spread + 1) * 26),
      weakNote: 'Make it bigger and more spread out.' },
    { key: 'Polish',        score: clamp(typeSet.size * 14 + effectsUsed.size * 22),
      weakNote: 'Use fancy ink effects and a mix of tools.' },
  ];
  const overall = Math.round(cats.reduce((s, c) => s + c.score, 0) / cats.length);
  return { cats, overall, empty: items.length === 0 };
}

function runJudge() {
  if (world.items.length === 0) { toast("Draw something first! ✏️"); return; }
  mode = 'judge';
  orbit.enabled = false;
  show('judge-screen');
  setTopbar({ coins: true, keep: true, judge: false });

  // quick "thinking" flash so it feels like the AI is judging — but fast
  const titleEl = document.getElementById('judge-title');
  titleEl.textContent = '🤖 AI is judging…';
  document.getElementById('judge-verdict').textContent = '';
  document.getElementById('judge-coins').textContent = '';
  document.getElementById('judge-breakdown').innerHTML = '';

  setTimeout(() => {
    const res = analyzeWorld();
    let tier, coins, verdict, emoji;
    if (res.overall >= 70) { tier = 'good'; coins = 100; verdict = 'Amazing artwork!'; emoji = '🤩'; }
    else if (res.overall >= 40) { tier = 'mid'; coins = 50; verdict = "It's pretty good."; emoji = '🙂'; }
    else { tier = 'low'; coins = 10; verdict = 'Keep practising!'; emoji = '💪'; }

    data.coins += coins; save(); refreshCoins();

    titleEl.textContent = `🤖 AI Judge — ${res.overall}/100`;
    document.getElementById('judge-verdict').textContent = `${emoji} ${verdict}`;
    const lost = 100 - coins;
    document.getElementById('judge-coins').innerHTML =
      `+${coins} coins earned 🪙` +
      (lost > 0 ? `<span class="lost">You missed out on ${lost} coins — the weak spots below are where you lost money.</span>` : '');

    const bd = document.getElementById('judge-breakdown');
    bd.innerHTML = '';
    for (const c of res.cats) {
      const weak = c.score < 50;
      const row = document.createElement('div');
      row.className = 'bd-row' + (weak ? ' weak' : '');
      row.innerHTML = `<span>${c.key}</span>
        <span class="bd-bar"><span class="bd-fill" style="width:${Math.round(c.score)}%"></span></span>
        <span>${Math.round(c.score)}</span>`;
      bd.appendChild(row);
      if (weak) {
        const note = document.createElement('div');
        note.className = 'bd-note';
        note.textContent = '💸 Lost coins here — ' + c.weakNote;
        bd.appendChild(note);
      }
    }
  }, 650);
}

/* ============================ SAVES ============================ */
function captureThumb() {
  renderer.render(scene, activeCamera);
  try {
    const tmp = document.createElement('canvas');
    tmp.width = 240; tmp.height = 150;
    tmp.getContext('2d').drawImage(canvas, 0, 0, 240, 150);
    return tmp.toDataURL('image/jpeg', 0.6);
  } catch { return ''; }
}
function doSave() {
  const thumb = captureThumb();
  if (currentSaveId) {
    const s = data.saves.find(s => s.id === currentSaveId);
    if (s) { s.world = world; s.thumb = thumb; s.date = new Date().toISOString(); toast('Save updated 💾'); }
  } else {
    const name = 'Drawing ' + (data.saves.length + 1);
    const id = 'sv_' + Math.floor(performance.now()) + '_' + data.saves.length;
    data.saves.push({ id, name, date: new Date().toISOString(), thumb, world });
    currentSaveId = id;
    toast('Saved! Find it in Saves 💾');
  }
  save();
}
function openSaves() {
  show('saves-screen');
  setTopbar({ coins: false });
  grid.visible = false;
  const list = document.getElementById('saves-list');
  list.innerHTML = '';
  if (!data.saves.length) { list.innerHTML = '<div class="empty-note">No saves yet. Draw something and press Save!</div>'; return; }
  for (const s of [...data.saves].reverse()) {
    const card = document.createElement('div');
    card.className = 'save-card';
    const d = new Date(s.date);
    card.innerHTML = `
      <img src="${s.thumb || ''}" alt="">
      <div class="save-meta"><div class="name">${s.name}</div><div class="date">${d.toLocaleDateString()} ${d.toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'})}</div></div>
      <div class="save-actions">
        <button data-a="explore">🌍 Explore</button>
        <button data-a="edit">✏️ Edit</button>
        <button data-a="del" class="del">🗑</button>
      </div>`;
    card.querySelector('[data-a=explore]').onclick = () => { loadSave(s); enterExplore(); };
    card.querySelector('[data-a=edit]').onclick = () => { loadSave(s); enterDrawMode(); };
    card.querySelector('[data-a=del]').onclick = () => {
      data.saves = data.saves.filter(x => x.id !== s.id); save(); openSaves();
    };
    list.appendChild(card);
  }
}
function loadSave(s) {
  world = structuredClone(s.world);
  currentSaveId = s.id;
  rebuildWorld();
}

/* ============================ SHOP ============================ */
function openShop() {
  show('shop-screen');
  setTopbar({ coins: false });
  grid.visible = false;
  refreshCoins();
  const list = document.getElementById('shop-list');
  list.innerHTML = '';
  for (const it of SHOP) {
    const owned = !!data.unlocks[it.id];
    const el = document.createElement('div');
    el.className = 'shop-item';
    const canAfford = data.coins >= it.price;
    el.innerHTML = `
      <div class="swatch-preview" style="background:${it.preview}"></div>
      <div class="name">${it.name}</div>
      <div class="desc">${it.desc}</div>
      <div class="price">🪙 ${it.price}</div>
      <button class="${owned ? 'owned' : (canAfford ? '' : 'cant')}">${owned ? '✓ Owned' : (canAfford ? 'Buy' : 'Need more coins')}</button>`;
    const btn = el.querySelector('button');
    if (!owned && canAfford) btn.onclick = () => {
      data.coins -= it.price; data.unlocks[it.id] = true; save(); toast(`Unlocked ${it.name}! 🎉`); openShop();
    };
    list.appendChild(el);
  }
}

/* ============================ FRIENDS ============================ */
function openFriends() {
  show('friends-screen');
  setTopbar({ coins: false });
  grid.visible = false;
  document.getElementById('friend-msg').textContent = '';
  const hasProfile = !!data.profile;
  document.getElementById('friend-setup').classList.toggle('hidden', hasProfile);
  document.getElementById('friend-add').classList.toggle('hidden', !hasProfile);
  if (hasProfile) {
    document.getElementById('me-name').textContent = data.profile.name;
    document.getElementById('me-color').style.background = data.profile.color;
    document.getElementById('friend-color-input').value = data.profile.color;
    renderFriends();
  } else {
    document.getElementById('username-input').value = '';
  }
}
function renderFriends() {
  const list = document.getElementById('friends-list');
  list.innerHTML = '';
  if (!data.friends.length) { list.innerHTML = '<div class="empty-note" style="padding:12px">No friends yet.</div>'; return; }
  for (const f of data.friends) {
    const row = document.createElement('div');
    row.className = 'friend-row';
    row.innerHTML = `<span class="color-dot" style="background:${f.color}"></span> <b>${f.name}</b> <span style="color:var(--muted);margin-left:auto">same colour ✓</span>`;
    list.appendChild(row);
  }
}
function saveProfile() {
  const name = document.getElementById('username-input').value.trim();
  const color = document.getElementById('profile-color-input').value;
  if (!name) { toast('Enter a username first'); return; }
  data.profile = { name, color }; save();
  toast(`Welcome, ${name}! 👋`);
  openFriends();
}
function addFriend() {
  const name = document.getElementById('friend-name-input').value.trim();
  const color = document.getElementById('friend-color-input').value;
  const msg = document.getElementById('friend-msg');
  if (!name) { msg.className = 'friend-msg bad'; msg.textContent = 'Type their username.'; return; }
  if (name.toLowerCase() === data.profile.name.toLowerCase()) { msg.className='friend-msg bad'; msg.textContent="That's you!"; return; }
  if (color.toLowerCase() !== data.profile.color.toLowerCase()) {
    msg.className = 'friend-msg bad';
    msg.textContent = "❌ Colours don't match! You both need the same colour to be friends.";
    return;
  }
  if (data.friends.find(f => f.name.toLowerCase() === name.toLowerCase())) {
    msg.className = 'friend-msg bad'; msg.textContent = 'Already friends with ' + name; return;
  }
  data.friends.push({ name, color }); save();
  msg.className = 'friend-msg ok';
  msg.textContent = `✅ You and ${name} are now friends!`;
  document.getElementById('friend-name-input').value = '';
  renderFriends();
}

/* ============================ EXPLORE MODE ============================ */
const player = {
  pos: new THREE.Vector3(0, 1.6, 8),
  vel: new THREE.Vector3(),
  yaw: Math.PI, pitch: 0,
  onGround: false,
  sitting: null,     // chair group when seated
  standPos: null,
};
const keys = {};
let colliders = [];   // { box: Box3, group } for solid meshes
let doorGroups = [];
let chairGroups = [];
let exploreGround = null;

function buildColliders() {
  colliders = []; doorGroups = []; chairGroups = [];
  worldGroup.updateWorldMatrix(true, true);
  worldGroup.traverse(o => {
    if (o.isMesh && o.userData.solid) {
      colliders.push({ box: new THREE.Box3().setFromObject(o), mesh: o });
    }
  });
  worldGroup.children.forEach(g => {
    if (g.userData.door) doorGroups.push(g);
    if (g.userData.chair) chairGroups.push(g);
  });
}

function enterExplore() {
  mode = 'explore';
  activeCamera = fpCamera;
  orbit.enabled = false;
  grid.visible = false;
  groundMesh.visible = true;
  scene.background = new THREE.Color('#8fc9ff');   // sky
  scene.fog = new THREE.Fog('#a9d4ff', 50, 160);
  groundMat.color = new THREE.Color('#3f7a3f');    // grass
  show('explore-hud');
  setTopbar({ coins: false, keep: true, judge: false });

  // start position: just outside the drawing, looking at it
  const box = new THREE.Box3().setFromObject(worldGroup);
  const center = new THREE.Vector3(); const size = new THREE.Vector3();
  if (!box.isEmpty()) { box.getCenter(center); box.getSize(size); }
  const dist = Math.max(6, size.z / 2 + 5);
  player.pos.set(center.x, 1.6, center.z + dist);
  player.vel.set(0, 0, 0);
  player.sitting = null; player.onGround = false;
  const dir = new THREE.Vector3().subVectors(center, player.pos);
  player.yaw = Math.atan2(-dir.x, -dir.z);
  player.pitch = -0.1;

  buildColliders();
  document.getElementById('click-to-play').classList.remove('hidden');
  document.getElementById('interact-hint').classList.add('hidden');
}
function exitExplore() {
  if (document.pointerLockElement) document.exitPointerLock();
  scene.background = new THREE.Color('#12132a');
  scene.fog = new THREE.Fog('#12132a', 40, 120);
  groundMat.color = new THREE.Color('#2b2f52');
}

// pointer lock look
canvas.addEventListener('click', () => {
  if (mode === 'explore' && !document.pointerLockElement) canvas.requestPointerLock();
});
document.addEventListener('pointerlockchange', () => {
  const cta = document.getElementById('click-to-play');
  if (cta) cta.classList.toggle('hidden', !!document.pointerLockElement || mode !== 'explore');
});
document.addEventListener('mousemove', (e) => {
  if (mode !== 'explore' || !document.pointerLockElement) return;
  player.yaw   -= e.movementX * 0.0022;
  player.pitch -= e.movementY * 0.0022;
  player.pitch = Math.max(-1.4, Math.min(1.4, player.pitch));
});

addEventListener('keydown', (e) => {
  keys[e.code] = true;
  if (mode === 'explore') {
    if (e.code === 'KeyE') tryInteract();
    if (e.code === 'Escape' && document.pointerLockElement) document.exitPointerLock();
  }
});
addEventListener('keyup', (e) => keys[e.code] = false);

function tryInteract() {
  // sit / stand
  if (player.sitting) {
    player.pos.copy(player.standPos);
    player.sitting = null;
    return;
  }
  // nearest door within 2.2m
  let bestDoor = null, bd = 2.2;
  for (const g of doorGroups) {
    const p = new THREE.Vector3(); g.getWorldPosition(p);
    const dd = p.distanceTo(player.pos);
    if (dd < bd) { bd = dd; bestDoor = g; }
  }
  if (bestDoor) { toggleDoor(bestDoor); return; }
  // nearest chair within 1.8m
  let bestChair = null, bc = 1.8;
  for (const g of chairGroups) {
    const p = new THREE.Vector3(); g.getWorldPosition(p);
    const dd = p.distanceTo(player.pos);
    if (dd < bc) { bc = dd; bestChair = g; }
  }
  if (bestChair) sitOn(bestChair);
}
function toggleDoor(g) {
  g.userData.open = !g.userData.open;
  g.userData.pivot.rotation.y = g.userData.open ? -Math.PI / 2 : 0;
  if (g.userData.solidMesh) g.userData.solidMesh.userData.solid = !g.userData.open;
  buildColliders();
  toast(g.userData.open ? 'Door opened 🚪' : 'Door closed');
}
function sitOn(g) {
  player.standPos = player.pos.clone();
  const seat = new THREE.Vector3(); g.getWorldPosition(seat);
  seat.y += 1.1;
  player.pos.copy(seat);
  player.vel.set(0, 0, 0);
  player.sitting = g;
  toast('Sitting — press E to stand');
}

// ground height under the player (top of highest walkable surface within radius)
function groundHeightAt(x, z, feetY) {
  let h = 0; // base plane
  const R = 0.35;
  for (const c of colliders) {
    const b = c.box;
    if (x > b.min.x - R && x < b.max.x + R && z > b.min.z - R && z < b.max.z + R) {
      if (b.max.y <= feetY + 0.45 && b.max.y > h) h = b.max.y;
    }
  }
  return h;
}
function collideHorizontal(next, feetY, headY) {
  const R = 0.32;
  for (const c of colliders) {
    const b = c.box;
    // ignore surfaces we can just step onto
    if (b.max.y <= feetY + 0.45) continue;
    if (b.min.y >= headY) continue;
    if (next.x > b.min.x - R && next.x < b.max.x + R && next.z > b.min.z - R && next.z < b.max.z + R) {
      // push out along the smallest penetration axis
      const dxMin = Math.abs(next.x - (b.min.x - R));
      const dxMax = Math.abs(next.x - (b.max.x + R));
      const dzMin = Math.abs(next.z - (b.min.z - R));
      const dzMax = Math.abs(next.z - (b.max.z + R));
      const m = Math.min(dxMin, dxMax, dzMin, dzMax);
      if (m === dxMin) next.x = b.min.x - R;
      else if (m === dxMax) next.x = b.max.x + R;
      else if (m === dzMin) next.z = b.min.z - R;
      else next.z = b.max.z + R;
    }
  }
}

let lastT = performance.now();
function updatePlayer(dt) {
  if (mode !== 'explore') return;
  if (player.sitting) return; // frozen while seated

  const speed = 5;
  const forward = new THREE.Vector3(-Math.sin(player.yaw), 0, -Math.cos(player.yaw));
  const right = new THREE.Vector3(Math.cos(player.yaw), 0, -Math.sin(player.yaw));
  const move = new THREE.Vector3();
  if (keys['KeyW'] || keys['ArrowUp']) move.add(forward);
  if (keys['KeyS'] || keys['ArrowDown']) move.sub(forward);
  if (keys['KeyD'] || keys['ArrowRight']) move.add(right);
  if (keys['KeyA'] || keys['ArrowLeft']) move.sub(right);
  if (move.lengthSq() > 0) move.normalize().multiplyScalar(speed);

  // gravity
  player.vel.y -= 20 * dt;
  if ((keys['Space']) && player.onGround) { player.vel.y = 7.2; player.onGround = false; }

  const feetY = player.pos.y - 1.6;
  const headY = player.pos.y;

  // horizontal move + collision
  const next = player.pos.clone();
  next.x += move.x * dt;
  next.z += move.z * dt;
  collideHorizontal(next, feetY, headY);
  player.pos.x = next.x; player.pos.z = next.z;

  // vertical
  player.pos.y += player.vel.y * dt;
  const gh = groundHeightAt(player.pos.x, player.pos.z, player.pos.y - 1.6);
  const floorEye = gh + 1.6;
  if (player.pos.y <= floorEye) {
    player.pos.y = floorEye; player.vel.y = 0; player.onGround = true;
  } else {
    player.onGround = false;
  }

  // interaction hint
  updateHint();
}

function updateHint() {
  const hint = document.getElementById('interact-hint');
  if (player.sitting) { hint.textContent = '[E] Stand up'; hint.classList.remove('hidden'); return; }
  let text = null;
  for (const g of doorGroups) {
    const p = new THREE.Vector3(); g.getWorldPosition(p);
    if (p.distanceTo(player.pos) < 2.2) { text = g.userData.open ? '[E] Close door' : '[E] Open door'; break; }
  }
  if (!text) for (const g of chairGroups) {
    const p = new THREE.Vector3(); g.getWorldPosition(p);
    if (p.distanceTo(player.pos) < 1.8) { text = '[E] Sit down'; break; }
  }
  hint.textContent = text || '';
  hint.classList.toggle('hidden', !text);
}

/* ============================ RENDER LOOP ============================ */
function animate() {
  requestAnimationFrame(animate);
  const now = performance.now();
  const dt = Math.min(0.05, (now - lastT) / 1000);
  lastT = now;

  if (mode === 'draw' || mode === 'judge') orbit.update();
  if (mode === 'explore') {
    updatePlayer(dt);
    fpCamera.position.copy(player.pos);
    const dir = new THREE.Vector3(
      -Math.sin(player.yaw) * Math.cos(player.pitch),
      Math.sin(player.pitch),
      -Math.cos(player.yaw) * Math.cos(player.pitch)
    );
    fpCamera.lookAt(player.pos.clone().add(dir));
  }
  renderer.render(scene, activeCamera);
}
animate();

/* ============================ UI WIRING ============================ */
document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-action]');
  if (!el) return;
  const a = el.dataset.action;
  switch (a) {
    case 'start': startNewDrawing(); break;
    case 'go-draw': enterDrawMode(); break;
    case 'menu': goMenu(); break;
    case 'saves': openSaves(); break;
    case 'shop': openShop(); break;
    case 'friends': openFriends(); break;
    case 'explore': enterExplore(); break;
    case 'save': doSave(); break;
    case 'keep-editing': enterDrawMode(); break;
    case 'undo': undo(); break;
    case 'clear': clearAll(); break;
    case 'save-profile': saveProfile(); break;
    case 'add-friend': addFriend(); break;
  }
});
document.getElementById('btn-judge').onclick = runJudge;
document.getElementById('btn-keep-editing').onclick = enterDrawMode;
document.getElementById('explore-menu-btn').onclick = goMenu;

function undo() {
  if (!world.items.length) return;
  const item = world.items.pop();
  const child = worldGroup.children.find(c => c.userData.item === item);
  if (child) worldGroup.remove(child);
  toast('Undone');
}
function clearAll() {
  if (!world.items.length) return;
  world.items = []; worldGroup.clear(); toast('Cleared');
}

/* small hooks for automated testing / debugging */
window.__BW = {
  itemCount: () => world.items.length,
  playerPos: () => ({ x: player.pos.x, y: player.pos.y, z: player.pos.z }),
  goMenu,
};

/* start on the menu */
goMenu();

})();
