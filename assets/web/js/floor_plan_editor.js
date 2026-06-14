
'use strict';

let scene, renderer, currentCamera;
let camera3D, camera2D, cameraFPS;
let orbitControls;
let roomWidth = 4.0, roomLength = 4.0, roomHeight = 2.8;
let wallGroup, floorMesh, ceilingMesh, gridHelper;
let furnitureItems = [];
let selectedItem = null;
let is3DMode = false;
let viewMode = '2d';
let raycaster, mouse;
let dragPlane, isDragging = false;
let dragOffset = new THREE.Vector3();
let gltfLoader;

let wallColor = new THREE.Color(0xF5F0E8);

const fpsState = {
  moveF: false, moveB: false, moveL: false, moveR: false,
  yaw: 0,   
  pitch: 0, 
  speed: 2.5,
  height: 1.6,
  joystickActive: false,
  joyStartX: 0, joyStartY: 0,
  joyDeltaX: 0, joyDeltaY: 0,
  lookStartX: 0, lookStartY: 0,
  lookDeltaX: 0, lookDeltaY: 0,
  lookActive: false,
};
let lastFPSTime = performance.now();
const FURNITURE_PRESETS = {
  sofa: {
    label: 'Sofa', w: 2.1, h: 0.85, d: 0.9,
    build: (w, h, d) => buildSofa(w, h, d),
  },
  armchair: {
    label: 'Armchair', w: 0.85, h: 0.85, d: 0.85,
    build: (w, h, d) => buildArmchair(w, h, d),
  },
  coffeeTable: {
    label: 'Coffee Table', w: 1.1, h: 0.42, d: 0.6,
    build: (w, h, d) => buildCoffeeTable(w, h, d),
  },
  diningTable: {
    label: 'Dining Table', w: 1.6, h: 0.76, d: 0.9,
    build: (w, h, d) => buildDiningTable(w, h, d),
  },
  diningChair: {
    label: 'Dining Chair', w: 0.45, h: 0.9, d: 0.45,
    build: (w, h, d) => buildDiningChair(w, h, d),
  },
  bedDouble: {
    label: 'Double Bed', w: 1.6, h: 0.55, d: 2.0,
    build: (w, h, d) => buildBed(w, h, d, 'double'),
  },
  bedSingle: {
    label: 'Single Bed', w: 0.95, h: 0.55, d: 2.0,
    build: (w, h, d) => buildBed(w, h, d, 'single'),
  },
  wardrobe: {
    label: 'Wardrobe', w: 1.8, h: 2.1, d: 0.6,
    build: (w, h, d) => buildWardrobe(w, h, d),
  },
  tvUnit: {
    label: 'TV Unit', w: 1.6, h: 0.45, d: 0.4,
    build: (w, h, d) => buildTVUnit(w, h, d),
  },
  bookshelf: {
    label: 'Bookshelf', w: 0.8, h: 1.8, d: 0.3,
    build: (w, h, d) => buildBookshelf(w, h, d),
  },
  plant: {
    label: 'Plant', w: 0.4, h: 0.9, d: 0.4,
    build: (w, h, d) => buildPlant(w, h, d),
  },
  rug: {
    label: 'Rug', w: 1.8, h: 0.01, d: 1.2,
    build: (w, h, d) => buildRug(w, h, d),
  },
  door: {
    label: 'Door', w: 0.9, h: 2.0, d: 0.1,
    build: (w, h, d) => buildDoor(w, h, d),
    elevation: 0,
  },
  window: {
    label: 'Window', w: 1.2, h: 1.0, d: 0.1,
    build: (w, h, d) => buildWindow(w, h, d),
    elevation: 0.9,
  },
};

function mat(color, rough = 0.7, metal = 0.0, opts = {}) {
  return new THREE.MeshStandardMaterial({ color, roughness: rough, metalness: metal, ...opts });
}
function makeWoodTexture(w = 512, h = 512) {
  const canvas = document.createElement('canvas');
  canvas.width = w; canvas.height = h;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#8B6340';
  ctx.fillRect(0, 0, w, h);
  const plankW = 80;
  ctx.strokeStyle = 'rgba(60,35,15,0.35)';
  ctx.lineWidth = 1.5;
  for (let x = 0; x < w; x += plankW) {
    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke();
    for (let y = 0; y < h; y += 200) {
      ctx.beginPath();
      ctx.moveTo(x, y + (Math.random() * 80));
      ctx.lineTo(x + plankW, y + (Math.random() * 80));
      ctx.stroke();
    }
  }

  for (let i = 0; i < 120; i++) {
    const y0 = Math.random() * h;
    const alpha = 0.04 + Math.random() * 0.1;
    ctx.strokeStyle = `rgba(50,25,10,${alpha})`;
    ctx.lineWidth = 0.5 + Math.random();
    ctx.beginPath();
    ctx.moveTo(0, y0);
    for (let x = 0; x <= w; x += 8) {
      ctx.lineTo(x, y0 + Math.sin(x / 30 + Math.random()) * 3);
    }
    ctx.stroke();
  }

  for (let k = 0; k < 4; k++) {
    const kx = Math.random() * w, ky = Math.random() * h;
    const rg = ctx.createRadialGradient(kx, ky, 0, kx, ky, 12);
    rg.addColorStop(0, 'rgba(50,25,10,0.5)');
    rg.addColorStop(1, 'rgba(50,25,10,0)');
    ctx.fillStyle = rg;
    ctx.beginPath(); ctx.ellipse(kx, ky, 12, 8, Math.random() * Math.PI, 0, Math.PI * 2);
    ctx.fill();
  }

  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  return tex;
}

// ── Init ──────────────────────────────────────────────────────
function init() {
  const container = document.getElementById('canvas-container');

  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x111827); // Very dark gray/slate

  const aspect = window.innerWidth / window.innerHeight;

  // 3D orbit camera
  camera3D = new THREE.PerspectiveCamera(50, aspect, 0.05, 80);
  camera3D.position.set(0, 7, 9);

  // 2D top-down
  const d = 5;
  camera2D = new THREE.OrthographicCamera(-d * aspect, d * aspect, d, -d, 0.1, 100);
  camera2D.position.set(0, 20, 0);
  camera2D.lookAt(0, 0, 0);

  // FPS first-person
  cameraFPS = new THREE.PerspectiveCamera(75, aspect, 0.05, 80);

  currentCamera = camera2D;

  // Renderer
  renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.1;
  if (THREE.ColorManagement) THREE.ColorManagement.enabled = true;
  if (renderer.outputEncoding !== undefined) {
    renderer.outputEncoding = THREE.sRGBEncoding;
  } else if (renderer.outputColorSpace !== undefined) {
    renderer.outputColorSpace = THREE.SRGBColorSpace;
  }
  container.appendChild(renderer.domElement);

  orbitControls = new THREE.OrbitControls(camera3D, renderer.domElement);
  orbitControls.enableDamping = true;
  orbitControls.dampingFactor = 0.06;
  orbitControls.maxPolarAngle = Math.PI / 2.05;
  orbitControls.minDistance = 1.5;
  orbitControls.maxDistance = 25;
  orbitControls.enabled = false;

  const ambient = new THREE.AmbientLight(0xfff5e0, 0.65);
  scene.add(ambient);

  const sun = new THREE.DirectionalLight(0xfff0d0, 1.2);
  sun.position.set(4, 10, 6);
  sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  sun.shadow.camera.near = 0.5;
  sun.shadow.camera.far = 40;
  sun.shadow.camera.left = -12;
  sun.shadow.camera.right = 12;
  sun.shadow.camera.top = 12;
  sun.shadow.camera.bottom = -12;
  sun.shadow.bias = -0.001;
  scene.add(sun);

  const fillLight = new THREE.DirectionalLight(0xc8e0ff, 0.4);
  fillLight.position.set(-4, 5, -4);
  scene.add(fillLight);

  // Groups
  wallGroup = new THREE.Group();
  scene.add(wallGroup);

  // Drag plane (invisible, y=0)
  dragPlane = new THREE.Mesh(
    new THREE.PlaneGeometry(200, 200),
    new THREE.MeshBasicMaterial({ visible: false, side: THREE.DoubleSide })
  );
  dragPlane.rotation.x = -Math.PI / 2;
  scene.add(dragPlane);

  raycaster = new THREE.Raycaster();
  mouse = new THREE.Vector2();
  gltfLoader = (typeof THREE.GLTFLoader !== 'undefined') ? new THREE.GLTFLoader() : null;

  rebuildRoom();

  window.addEventListener('resize', onWindowResize);
  renderer.domElement.addEventListener('pointerdown', onPointerDown);
  renderer.domElement.addEventListener('pointermove', onPointerMove);

  // Bind pointerup and cancel globally to window to avoid sticky drags when fingers leave canvas
  window.addEventListener('pointerup', onPointerUp);
  window.addEventListener('pointercancel', onPointerUp);

  // FPS joystick setup
  setupJoystick();

  // Bind UI control elements using pointerdown/touchstart/click to ensure immediate response on mobile & desktop
  const walkBtn = document.getElementById('walk-btn');
  if (walkBtn) {
    const startWalk = (e) => {
      e.preventDefault();
      e.stopPropagation();
      window.setView('fps');
    };
    walkBtn.addEventListener('pointerdown', startWalk);
    walkBtn.addEventListener('touchstart', startWalk, { passive: false });
    walkBtn.addEventListener('click', startWalk);
  }

  const exitWalkBtn = document.getElementById('exit-walk-btn');
  if (exitWalkBtn) {
    const exitWalk = (e) => {
      e.preventDefault();
      e.stopPropagation();
      window.setView('3d');
    };
    exitWalkBtn.addEventListener('pointerdown', exitWalk);
    exitWalkBtn.addEventListener('touchstart', exitWalk, { passive: false });
    exitWalkBtn.addEventListener('click', exitWalk);
  }

  const colorToggleBtn = document.getElementById('color-toggle-btn');
  const colorPalette = document.getElementById('color-picker-palette');
  if (colorToggleBtn && colorPalette) {
    const toggleColor = (e) => {
      e.preventDefault();
      e.stopPropagation();
      console.log('toggle clicked, current display:', colorPalette.style.display);
      const isHidden = colorPalette.style.display === 'none' || colorPalette.style.display === '';
      colorPalette.style.display = isHidden ? 'flex' : 'none';
      console.log('new display:', colorPalette.style.display);
    };
    colorToggleBtn.addEventListener('pointerdown', toggleColor);
    colorToggleBtn.addEventListener('touchstart', toggleColor, { passive: false });
    colorToggleBtn.addEventListener('click', toggleColor);
  }

  // Bind doors and windows buttons
  const addDoorBtn = document.getElementById('add-door-btn');
  if (addDoorBtn) {
    const addDoor = (e) => {
      e.preventDefault();
      e.stopPropagation();
      const id = 'door_' + Date.now();
      window.addFurniture(id, 'door', 'Door', 0.9, 0.1, '');
    };
    addDoorBtn.addEventListener('pointerdown', addDoor);
    addDoorBtn.addEventListener('touchstart', addDoor, { passive: false });
    addDoorBtn.addEventListener('click', addDoor);
  }

  const addWindowBtn = document.getElementById('add-window-btn');
  if (addWindowBtn) {
    const addWindow = (e) => {
      e.preventDefault();
      e.stopPropagation();
      const id = 'window_' + Date.now();
      window.addFurniture(id, 'window', 'Window', 1.2, 0.1, '');
    };
    addWindowBtn.addEventListener('pointerdown', addWindow);
    addWindowBtn.addEventListener('touchstart', addWindow, { passive: false });
    addWindowBtn.addEventListener('click', addWindow);
  }

  // Bind color swatches
  document.querySelectorAll('.color-swatch').forEach(swatch => {
    const changeColor = (e) => {
      e.preventDefault();
      e.stopPropagation();
      document.querySelectorAll('.color-swatch').forEach(el => el.classList.remove('active'));
      swatch.classList.add('active');
      const hex = swatch.getAttribute('data-color');
      window.setWallColor(hex);
    };
    swatch.addEventListener('pointerdown', changeColor);
    swatch.addEventListener('touchstart', changeColor, { passive: false });
    swatch.addEventListener('click', changeColor);
  });

  // Hide loader
  const loader = document.getElementById('loading-indicator');
  if (loader) loader.style.opacity = '0';
  setTimeout(() => { if (loader) loader.style.display = 'none'; }, 400);

  // Set initial view state to 2D
  window.setView('2d');

  sendMessageToFlutter('onUnityReady', {});
  animate();
}

// ── Room builder ──────────────────────────────────────────────
function rebuildRoom() {
  // Clear walls, baseboards, lamps, pointlights
  while (wallGroup.children.length) wallGroup.remove(wallGroup.children[0]);
  if (gridHelper) { scene.remove(gridHelper); gridHelper = null; }
  if (floorMesh) { scene.remove(floorMesh); floorMesh = null; }
  if (ceilingMesh) { scene.remove(ceilingMesh); ceilingMesh = null; }

  const W = roomWidth, L = roomLength, H = roomHeight, T = 0.1;

  // ── FLOOR — wood ───────────────────────────────────────────
  const woodTex = makeWoodTexture(512, 512);
  woodTex.repeat.set(W / 1.5, L / 1.5);
  const floorMat = new THREE.MeshStandardMaterial({
    map: woodTex,
    roughness: 0.55,
    metalness: 0.05,
  });
  floorMesh = new THREE.Mesh(new THREE.PlaneGeometry(W, L), floorMat);
  floorMesh.rotation.x = -Math.PI / 2;
  floorMesh.receiveShadow = true;
  floorMesh.name = 'floor';
  scene.add(floorMesh);

  // ── CEILING ────────────────────────────────────────────────
  const ceilMat = new THREE.MeshStandardMaterial({ color: 0xfafafa, roughness: 1 });
  ceilingMesh = new THREE.Mesh(new THREE.PlaneGeometry(W, L), ceilMat);
  ceilingMesh.rotation.x = Math.PI / 2;
  ceilingMesh.position.y = H;
  ceilingMesh.receiveShadow = false;
  scene.add(ceilingMesh);

  // ── WALLS ──────────────────────────────────────────────────
  const wallMat = () => new THREE.MeshStandardMaterial({
    color: wallColor,
    roughness: 0.85,
    metalness: 0.0,
    side: (viewMode === 'fps') ? THREE.BackSide : THREE.FrontSide,
  });

  const makeWall = (geoArgs, pos, rotY = 0) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(...geoArgs), wallMat());
    mesh.position.set(...pos);
    if (rotY) mesh.rotation.y = rotY;
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    mesh.name = 'wall';
    wallGroup.add(mesh);
  };

  // North / South / East / West
  makeWall([W + T * 2, H, T], [0, H / 2, -L / 2]);
  makeWall([W + T * 2, H, T], [0, H / 2, L / 2]);
  makeWall([T, H, L], [W / 2, H / 2, 0]);
  makeWall([T, H, L], [-W / 2, H / 2, 0]);

  // Baseboards (dark wood slim strip) - Added to wallGroup so it is cleared on rebuild
  const baseColor = 0x4a3728;
  const baseMat = new THREE.MeshStandardMaterial({ color: baseColor, roughness: 0.9 });
  const baseH = 0.08;

  const bMesh = (w, x, z, ry) => {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, baseH, 0.025), baseMat);
    m.position.set(x, baseH / 2, z);
    if (ry) m.rotation.y = ry;
    wallGroup.add(m);
  };
  bMesh(W, 0, -L / 2 + 0.05, 0);
  bMesh(W, 0, L / 2 - 0.05, 0);
  bMesh(L, W / 2 - 0.05, 0, Math.PI / 2);
  bMesh(L, -W / 2 + 0.05, 0, Math.PI / 2);

  // ── GRID (2D mode only) ────────────────────────────────────
  gridHelper = new THREE.GridHelper(Math.max(W, L) + 1, Math.ceil(Math.max(W, L) + 1), 0x94a3b8, 0x334155);
  gridHelper.position.y = 0.002;
  gridHelper.visible = viewMode === '2d';
  scene.add(gridHelper);

  // Subtle ceiling lamp - Added to wallGroup for rebuild clearance
  const lampGeo = new THREE.CylinderGeometry(0.18, 0.22, 0.06, 16);
  const lampMat = new THREE.MeshStandardMaterial({ color: 0xe0d8c8, metalness: 0.5, roughness: 0.3 });
  const lamp = new THREE.Mesh(lampGeo, lampMat);
  lamp.position.set(0, H - 0.03, 0);
  wallGroup.add(lamp);

  const pointLight = new THREE.PointLight(0xfff5d0, 1.2, Math.max(W, L) * 2);
  pointLight.position.set(0, H - 0.2, 0);
  pointLight.castShadow = true;
  wallGroup.add(pointLight);

  orbitControls.target.set(0, H / 2, 0);
  sendMessageToFlutter('onRoomBuilt', {});
}

// ── Furniture builders ────────────────────────────────────────

function buildSofa(W, H, D) {
  const g = new THREE.Group();
  const fabric = mat(0x6B7B8D, 0.85);
  const leg = mat(0x3D2B1F, 0.9);
  const legH = 0.12, legR = 0.025;

  // Seat
  add(g, [W, 0.22, D * 0.62], [0, 0.11 + legH, 0], fabric);
  // Back
  add(g, [W, H * 0.55, 0.12], [0, legH + 0.11 + (H * 0.55) / 2, -(D / 2) + 0.06], fabric);
  // Arms
  [-W / 2 + 0.08, W / 2 - 0.08].forEach(x =>
    add(g, [0.14, H * 0.38, D * 0.62], [x, legH + (H * 0.38) / 2, 0], fabric)
  );
  // Cushions
  const cushion = mat(0x5A6A7A, 0.9);
  for (let i = 0; i < 3; i++) {
    const cx = (i - 1) * (W / 3 - 0.01);
    add(g, [W / 3 - 0.04, 0.12, D * 0.55], [cx, legH + 0.22 + 0.06, 0.02], cushion);
  }
  // Legs
  [[W / 2 - 0.1, D / 2 - 0.08], [W / 2 - 0.1, -D / 2 + 0.08],
  [-W / 2 + 0.1, D / 2 - 0.08], [-W / 2 + 0.1, -D / 2 + 0.08]].forEach(([x, z]) =>
    addCyl(g, legR, legH, [x, legH / 2, z], leg)
  );
  return g;
}

function buildArmchair(W, H, D) {
  const g = new THREE.Group();
  const fabric = mat(0x8B6F52, 0.85);
  const legM = mat(0x3D2B1F, 0.9);
  const legH = 0.12;
  add(g, [W, 0.2, D * 0.6], [0, legH + 0.1, 0], fabric);
  add(g, [W, H * 0.5, 0.1], [0, legH + 0.1 + H * 0.25, -(D / 2) + 0.05], fabric);
  [-W / 2 + 0.07, W / 2 - 0.07].forEach(x =>
    add(g, [0.12, H * 0.32, D * 0.6], [x, legH + H * 0.16, 0], fabric)
  );
  add(g, [W - 0.06, 0.1, D * 0.52], [0, legH + 0.24, 0.02], mat(0x7A5F44, 0.9));
  [[W / 2 - 0.08, D / 2 - 0.07], [W / 2 - 0.08, -D / 2 + 0.07], [-W / 2 + 0.08, D / 2 - 0.07], [-W / 2 + 0.08, -D / 2 + 0.07]]
    .forEach(([x, z]) => addCyl(g, 0.025, legH, [x, legH / 2, z], legM));
  return g;
}

function buildCoffeeTable(W, H, D) {
  const g = new THREE.Group();
  const top = mat(0xC8A882, 0.4, 0.1);
  const legM = mat(0x3D2B1F, 0.85);
  add(g, [W, 0.04, D], [0, H - 0.02, 0], top);
  // shelf
  add(g, [W * 0.8, 0.025, D * 0.7], [0, H * 0.35, 0], mat(0xB8986E, 0.5));
  [[W / 2 - 0.05, D / 2 - 0.05], [W / 2 - 0.05, -D / 2 + 0.05], [-W / 2 + 0.05, D / 2 - 0.05], [-W / 2 + 0.05, -D / 2 + 0.05]]
    .forEach(([x, z]) => addCyl(g, 0.028, H, [x, H / 2, z], legM));
  return g;
}

function buildDiningTable(W, H, D) {
  const g = new THREE.Group();
  const topM = mat(0xC4935A, 0.35, 0.05);
  const legM = mat(0x5C3D1E, 0.85);
  // Tabletop
  add(g, [W, 0.05, D], [0, H, 0], topM);
  // Apron
  add(g, [W - 0.1, 0.07, 0.04], [0, H - 0.06, D / 2 - 0.05], legM);
  add(g, [W - 0.1, 0.07, 0.04], [0, H - 0.06, -D / 2 + 0.05], legM);
  add(g, [0.04, 0.07, D - 0.1], [W / 2 - 0.05, H - 0.06, 0], legM);
  add(g, [0.04, 0.07, D - 0.1], [-W / 2 + 0.05, H - 0.06, 0], legM);
  // Legs
  [[W / 2 - 0.07, D / 2 - 0.07], [W / 2 - 0.07, -D / 2 + 0.07], [-W / 2 + 0.07, D / 2 - 0.07], [-W / 2 + 0.07, -D / 2 + 0.07]]
    .forEach(([x, z]) => add(g, [0.06, H, 0.06], [x, H / 2, z], legM));
  return g;
}

function buildDiningChair(W, H, D) {
  const g = new THREE.Group();
  const wood = mat(0xA0714A, 0.8);
  const fabric = mat(0xD4C5A9, 0.9);
  const legH = 0.45;
  add(g, [W, 0.04, D], [0, legH, 0], wood); // seat
  add(g, [W * 0.05, 0.04, D], [0, legH, 0], fabric); // pad
  // Back posts
  [-W / 2 + 0.04, W / 2 - 0.04].forEach(x => {
    add(g, [0.03, H - legH, 0.03], [x, legH + (H - legH) / 2, -D / 2 + 0.04], wood);
  });
  // Back slats
  for (let i = 0; i < 3; i++) {
    const sy = legH + 0.07 + i * 0.1;
    add(g, [W - 0.1, 0.025, 0.025], [0, sy, -D / 2 + 0.04], wood);
  }
  // 4 legs
  [[W / 2 - 0.04, D / 2 - 0.04], [W / 2 - 0.04, -D / 2 + 0.04], [-W / 2 + 0.04, D / 2 - 0.04], [-W / 2 + 0.04, -D / 2 + 0.04]]
    .forEach(([x, z]) => add(g, [0.035, legH, 0.035], [x, legH / 2, z], wood));
  return g;
}

function buildBed(W, H, D, type) {
  const g = new THREE.Group();
  const frame = mat(0x5C3D1E, 0.85);
  const mattress = mat(0xEEE8DC, 0.9);
  const pillow = mat(0xFAF7F0, 0.95);
  const blanket = mat(type === 'double' ? 0x6B7FA6 : 0x8A6F9A, 0.9);
  const legH = 0.15;
  // Frame
  add(g, [W, legH, D], [0, legH / 2, 0], frame);
  // Headboard
  add(g, [W, H, 0.08], [0, H / 2, -D / 2 + 0.04], frame);
  // Footboard
  add(g, [W, H * 0.45, 0.06], [0, H * 0.225, D / 2 - 0.03], frame);
  // Mattress
  add(g, [W - 0.06, 0.2, D - 0.08], [0, legH + 0.1, 0.04], mattress);
  // Blanket
  add(g, [W - 0.08, 0.06, D * 0.55], [0, legH + 0.23, D * 0.15], blanket);
  // Pillows
  const pCount = type === 'double' ? 2 : 1;
  const pOff = type === 'double' ? W / 4 : 0;
  for (let i = 0; i < pCount; i++) {
    const px = pCount === 2 ? (i === 0 ? -pOff : pOff) : 0;
    add(g, [W / pCount - 0.12, 0.08, 0.4], [px, legH + 0.25, -D / 2 + 0.26], pillow);
  }
  return g;
}

function buildWardrobe(W, H, D) {
  const g = new THREE.Group();
  const wood = mat(0xD4B896, 0.7, 0.05);
  const dark = mat(0x6B4C30, 0.8);
  const handle = mat(0xC0A060, 0.3, 0.7);
  add(g, [W, H, D], [0, H / 2, 0], wood);
  // Door lines
  add(g, [0.015, H - 0.06, D + 0.01], [0, H / 2, 0], dark);
  add(g, [W + 0.01, 0.015, D + 0.01], [0, H * 0.3, 0], dark);
  // Handles
  addCyl(g, 0.015, 0.12, [-W / 4, H / 2, D / 2 + 0.01], handle);
  addCyl(g, 0.015, 0.12, [W / 4, H / 2, D / 2 + 0.01], handle);
  // Top cornice
  add(g, [W + 0.04, 0.05, D + 0.04], [0, H + 0.025, 0], dark);
  // Feet
  [[-W / 2 + 0.08, 0.06], [W / 2 - 0.08, 0.06]].forEach(([x]) =>
    add(g, [0.08, 0.06, D - 0.1], [x, 0.03, 0], dark)
  );
  return g;
}

function buildTVUnit(W, H, D) {
  const g = new THREE.Group();
  const wood = mat(0xC4A882, 0.6, 0.05);
  const dark = mat(0x2A2A2A, 0.7);
  const leg = mat(0x1A1A1A, 0.5, 0.3);
  // Cabinet body
  add(g, [W, H, D], [0, H / 2, 0], wood);
  // Panels (doors)
  add(g, [W / 3 - 0.02, H - 0.06, 0.01], [-W / 3, H / 2, D / 2 + 0.005], dark);
  add(g, [W / 3 - 0.02, H - 0.06, 0.01], [W / 3, H / 2, D / 2 + 0.005], dark);
  // Hairpin legs
  [[-W / 2 + 0.1, W / 2 - 0.1]].flat().forEach((x, i) => {
    [D / 2 - 0.05, -D / 2 + 0.05].forEach(z => {
      addCyl(g, 0.012, H * 0.35, [x, H * 0.175, z], leg);
    });
  });
  return g;
}

function buildBookshelf(W, H, D) {
  const g = new THREE.Group();
  const wood = mat(0xD4AA78, 0.75);
  const bookColors = [0xC0392B, 0x2980B9, 0x27AE60, 0xF39C12, 0x8E44AD, 0xE74C3C, 0x1ABC9C];
  // Sides, top, bottom, back
  [[-W / 2 + 0.015, 0], [W / 2 - 0.015, 0]].forEach(([x]) =>
    add(g, [0.03, H, D], [x, H / 2, 0], wood)
  );
  add(g, [W, 0.025, D], [0, H, 0], wood);
  add(g, [W, 0.025, D], [0, 0, 0], wood);
  add(g, [W, H, 0.015], [0, H / 2, -D / 2 + 0.008], mat(0xB8906A, 0.9));
  // Shelves
  const shelfCount = 4;
  for (let i = 1; i < shelfCount; i++) {
    const sy = (H / shelfCount) * i;
    add(g, [W - 0.04, 0.02, D - 0.01], [0, sy, 0], wood);
    // Books on shelf
    const bookCount = 5 + Math.floor(Math.random() * 4);
    let bx = -W / 2 + 0.04;
    for (let b = 0; b < bookCount && bx < W / 2 - 0.06; b++) {
      const bw = 0.03 + Math.random() * 0.025;
      const bh = 0.12 + Math.random() * 0.08;
      add(g, [bw, bh, D * 0.75], [bx + bw / 2, sy + bh / 2 + 0.01, 0],
        mat(bookColors[b % bookColors.length], 0.9));
      bx += bw + 0.005;
    }
  }
  return g;
}

function buildPlant(W, H, D) {
  const g = new THREE.Group();
  const pot = mat(0xC17F54, 0.85);
  const soil = mat(0x3D2B1F, 0.95);
  const stem = mat(0x2D5A27, 0.8);
  const leaf = mat(0x3A7D44, 0.75);
  const potH = H * 0.28;
  // Pot
  addCyl(g, W * 0.36, potH, [0, potH / 2, 0], pot, W * 0.28);
  addCyl(g, W * 0.34, 0.03, [0, potH - 0.01, 0], soil);
  // Stem
  addCyl(g, 0.025, H * 0.45, [0, potH + H * 0.225, 0], stem);
  // Leaves
  for (let i = 0; i < 7; i++) {
    const angle = (i / 7) * Math.PI * 2;
    const lh = potH + H * 0.3 + (i % 3) * H * 0.1;
    const lr = W * 0.28;
    const lx = Math.cos(angle) * lr * 0.5;
    const lz = Math.sin(angle) * lr * 0.5;
    const lMesh = new THREE.Mesh(
      new THREE.SphereGeometry(lr * 0.55, 8, 6),
      mat(i % 2 === 0 ? 0x3A7D44 : 0x4A9455, 0.75)
    );
    lMesh.scale.y = 0.25;
    lMesh.position.set(lx, lh, lz);
    lMesh.rotation.z = angle;
    g.add(lMesh);
  }
  return g;
}

function buildRug(W, H, D) {
  const g = new THREE.Group();
  const rugColors = [0xC0392B, 0xE8D5A3, 0x2C3E50];
  // Base
  add(g, [W, 0.015, D], [0, 0.008, 0], mat(rugColors[0], 0.98));
  // Pattern border
  add(g, [W - 0.1, 0.016, 0.06], [0, 0.009, D / 2 - 0.08], mat(rugColors[1], 0.98));
  add(g, [W - 0.1, 0.016, 0.06], [0, 0.009, -D / 2 + 0.08], mat(rugColors[1], 0.98));
  add(g, [0.06, 0.016, D - 0.1], [W / 2 - 0.08, 0.009, 0], mat(rugColors[1], 0.98));
  add(g, [0.06, 0.016, D - 0.1], [-W / 2 + 0.08, 0.009, 0], mat(rugColors[1], 0.98));
  // Center medallion
  const cMesh = new THREE.Mesh(
    new THREE.CylinderGeometry(Math.min(W, D) * 0.22, Math.min(W, D) * 0.22, 0.017, 12),
    mat(rugColors[2], 0.98)
  );
  cMesh.position.y = 0.009;
  g.add(cMesh);
  return g;
}

function buildDoor(W, H, D) {
  const g = new THREE.Group();
  const frameMat = mat(0x4a3728, 0.85); // rich brown wood frame
  const panelMat = mat(0x6b4c30, 0.7);  // warm wood panel
  const handleMat = mat(0xffd700, 0.2, 0.8); // gold brass handle

  const fT = 0.04; // frame thickness
  // Frame top
  add(g, [W, fT, D + 0.02], [0, H - fT / 2, 0], frameMat);
  // Frame left
  add(g, [fT, H, D + 0.02], [-W / 2 + fT / 2, H / 2, 0], frameMat);
  // Frame right
  add(g, [fT, H, D + 0.02], [W / 2 - fT / 2, H / 2, 0], frameMat);

  // Door panel (slightly open, rotating around the left hinge)
  const panelW = W - fT * 2;
  const panelH = H - fT;
  const panelD = 0.035;

  const panelGroup = new THREE.Group();
  panelGroup.position.set(-W / 2 + fT, 0, 0); // hinge pivot
  g.add(panelGroup);

  // Panel mesh
  add(panelGroup, [panelW, panelH, panelD], [panelW / 2, panelH / 2, 0], panelMat);

  // Handles
  addCyl(panelGroup, 0.012, 0.05, [panelW - 0.08, H / 2, 0.025], handleMat);
  addCyl(panelGroup, 0.012, 0.05, [panelW - 0.08, H / 2, -0.025], handleMat);

  // Open 35 degrees inside
  panelGroup.rotation.y = Math.PI / 5;

  return g;
}

function buildWindow(W, H, D) {
  const g = new THREE.Group();
  const frameMat = mat(0xeeeeee, 0.5); // white frame
  const glassMat = new THREE.MeshStandardMaterial({
    color: 0xe0f2fe,
    roughness: 0.05,
    metalness: 0.9,
    transparent: true,
    opacity: 0.35,
  });

  const fT = 0.05; // frame thickness
  // Outer frame
  add(g, [W, fT, D + 0.02], [0, H - fT / 2, 0], frameMat); // Top
  add(g, [W, fT, D + 0.02], [0, fT / 2, 0], frameMat); // Bottom
  add(g, [fT, H, D + 0.02], [-W / 2 + fT / 2, H / 2, 0], frameMat); // Left
  add(g, [fT, H, D + 0.02], [W / 2 - fT / 2, H / 2, 0], frameMat); // Right

  // Horizontal frame splitter
  add(g, [W - fT * 2, fT, D * 0.8], [0, H / 2, 0], frameMat);

  // Glass panes (top and bottom)
  const paneW = W - fT * 2;
  const paneH = (H - fT * 3) / 2;
  add(g, [paneW, paneH, 0.01], [0, H * 0.75 - fT / 4, 0], glassMat); // Top pane
  add(g, [paneW, paneH, 0.01], [0, H * 0.25 + fT / 4, 0], glassMat); // Bottom pane

  return g;
}

// ── Geometry helpers ──────────────────────────────────────────
function add(group, dims, pos, material) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(...dims), material);
  m.position.set(...pos);
  m.castShadow = true;
  m.receiveShadow = true;
  group.add(m);
  return m;
}
function addCyl(group, rTop, h, pos, material, rBot) {
  const m = new THREE.Mesh(
    new THREE.CylinderGeometry(rTop, rBot !== undefined ? rBot : rTop, h, 12),
    material
  );
  m.position.set(...pos);
  m.castShadow = true;
  m.receiveShadow = true;
  group.add(m);
  return m;
}

// ── Pointer / Drag ────────────────────────────────────────────
function onPointerDown(e) {
  if (viewMode === 'fps') return;

  // Make sure we didn't tap on the left sidebar panel to prevent deselecting furniture
  const leftControls = document.getElementById('left-controls');
  if (leftControls && leftControls.contains(e.target)) {
    return;
  }

  mouse.x = (e.clientX / window.innerWidth) * 2 - 1;
  mouse.y = -(e.clientY / window.innerHeight) * 2 + 1;
  raycaster.setFromCamera(mouse, currentCamera);

  const draggable = furnitureItems.map(i => i.group);
  const hits = raycaster.intersectObjects(draggable, true);

  if (hits.length > 0) {
    orbitControls.enabled = false;
    let hitObj = hits[0].object;
    while (hitObj.parent && !draggable.includes(hitObj)) hitObj = hitObj.parent;
    const match = furnitureItems.find(i => i.group === hitObj);
    if (match) {
      selectItem(match);
      isDragging = true;
      const pi = raycaster.intersectObject(dragPlane);
      if (pi.length > 0) dragOffset.copy(pi[0].point).sub(hitObj.position);
    }
  } else {
    deselectItem();
  }
}

function onPointerMove(e) {
  if (!isDragging || !selectedItem || viewMode === 'fps') return;
  mouse.x = (e.clientX / window.innerWidth) * 2 - 1;
  mouse.y = -(e.clientY / window.innerHeight) * 2 + 1;
  raycaster.setFromCamera(mouse, currentCamera);
  const pi = raycaster.intersectObject(dragPlane);
  if (pi.length > 0) {
    const np = pi[0].point.clone().sub(dragOffset);

    // Snapping logic for doors and windows to walls
    if (selectedItem.type === 'door' || selectedItem.type === 'window') {
      const W = roomWidth;
      const L = roomLength;

      // Calculate distances to North, South, East, West wall plane center lines
      const distNorth = Math.abs(np.z - (-L / 2));
      const distSouth = Math.abs(np.z - (L / 2));
      const distEast = Math.abs(np.x - (W / 2));
      const distWest = Math.abs(np.x - (-W / 2));

      const minDist = Math.min(distNorth, distSouth, distEast, distWest);

      if (minDist === distNorth) {
        np.z = -L / 2;
        selectedItem.group.rotation.y = 0;
      } else if (minDist === distSouth) {
        np.z = L / 2;
        selectedItem.group.rotation.y = Math.PI;
      } else if (minDist === distEast) {
        np.x = W / 2;
        selectedItem.group.rotation.y = Math.PI / 2;
      } else if (minDist === distWest) {
        np.x = -W / 2;
        selectedItem.group.rotation.y = -Math.PI / 2;
      }

      // Prevent bleeding outside room corners (clamp wall slider position)
      const margin = 0.2;
      if (minDist === distNorth || minDist === distSouth) {
        np.x = Math.max(-W / 2 + margin, Math.min(W / 2 - margin, np.x));
      } else {
        np.z = Math.max(-L / 2 + margin, Math.min(L / 2 - margin, np.z));
      }
    } else {
      // Standard furniture boundary clamping
      const mX = roomWidth / 2 - (selectedItem.w / 2) - 0.06;
      const mZ = roomLength / 2 - (selectedItem.d / 2) - 0.06;
      np.x = Math.max(-mX, Math.min(mX, np.x));
      np.z = Math.max(-mZ, Math.min(mZ, np.z));
    }

    selectedItem.group.position.x = np.x;
    selectedItem.group.position.z = np.z;

    // Apply custom elevation on movement
    const preset = FURNITURE_PRESETS[selectedItem.type];
    selectedItem.group.position.y = (preset && preset.elevation !== undefined) ? preset.elevation : 0;
  }
}

function onPointerUp() {
  isDragging = false;
  if (viewMode === '3d') orbitControls.enabled = true;
}

// ── Selection ─────────────────────────────────────────────────
function selectItem(item) {
  if (selectedItem) setRing(selectedItem.group, false);
  selectedItem = item;
  setRing(item.group, true);

  const indicator = document.getElementById('selection-indicator');
  const selName = document.getElementById('sel-name');
  if (indicator) indicator.style.display = 'flex';
  if (selName) selName.textContent = item.name;

  sendMessageToFlutter('onSelected', { name: item.name });
}

function deselectItem() {
  if (selectedItem) setRing(selectedItem.group, false);
  selectedItem = null;

  const indicator = document.getElementById('selection-indicator');
  if (indicator) indicator.style.display = 'none';

  sendMessageToFlutter('onSelected', null);
}

function setRing(group, show) {
  let ring = group.getObjectByName('sel_ring');
  if (show && !ring) {
    const box = new THREE.Box3().setFromObject(group);
    const sz = box.getSize(new THREE.Vector3());
    const r = Math.max(sz.x, sz.z) * 0.6 + 0.06;
    ring = new THREE.Mesh(
      new THREE.RingGeometry(r - 0.04, r + 0.04, 36),
      new THREE.MeshBasicMaterial({ color: 0x38bdf8, side: THREE.DoubleSide, depthWrite: false })
    );
    ring.name = 'sel_ring';
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.012;
    group.add(ring);
  }
  if (ring) ring.visible = show;
}

// ── Flutter-callable APIs ─────────────────────────────────────
window.updateRoom = function (w, l, h) {
  roomWidth = parseFloat(w) || roomWidth;
  roomLength = parseFloat(l) || roomLength;
  roomHeight = parseFloat(h) || roomHeight;
  rebuildRoom();
  clampAllFurniture();
};

window.addFurniture = function (id, type, name, w, d, modelUrl) {
  const fw = parseFloat(w) || 0.8;
  const fd = parseFloat(d) || 0.8;

  // Robust preset mapping (resolves name casing mismatches from Flutter catalog list)
  let cleanType = type.toLowerCase();
  if (cleanType.includes('sofa')) cleanType = 'sofa';
  else if (cleanType.includes('armchair')) cleanType = 'armchair';
  else if (cleanType.includes('bed')) cleanType = 'bedDouble';
  else if (cleanType.includes('table')) cleanType = cleanType.includes('coffee') ? 'coffeeTable' : 'diningTable';
  else if (cleanType.includes('chair')) cleanType = 'diningChair';
  else if (cleanType.includes('wardrobe')) cleanType = 'wardrobe';
  else if (cleanType.includes('plant')) cleanType = 'plant';
  else if (cleanType.includes('tv') || cleanType.includes('tv_unit') || cleanType.includes('tvunit')) cleanType = 'tvUnit';
  else if (cleanType.includes('book')) cleanType = 'bookshelf';
  else if (cleanType.includes('rug')) cleanType = 'rug';
  else if (cleanType.includes('door')) cleanType = 'door';
  else if (cleanType.includes('window')) cleanType = 'window';

  const preset = FURNITURE_PRESETS[cleanType];

  const itemGroup = new THREE.Group();
  itemGroup.position.set(0, 0, 0);
  scene.add(itemGroup);

  const data = { id, type: cleanType, name, w: fw, d: fd, group: itemGroup };
  furnitureItems.push(data);

  if (preset) {
    const built = preset.build(fw, preset.h, fd);
    built.traverse(c => { if (c.isMesh) { c.castShadow = true; c.receiveShadow = true; } });
    itemGroup.add(built);
    // Apply custom preset default elevation
    itemGroup.position.y = preset.elevation !== undefined ? preset.elevation : 0;
    selectItem(data);
  } else if (gltfLoader && modelUrl && modelUrl.trim()) {
    gltfLoader.load(modelUrl, (gltf) => {
      const model = gltf.scene;
      
      // Calculate bounding box based on visible meshes only
      const box = new THREE.Box3();
      let hasMesh = false;
      model.traverse(c => {
        if (c.isMesh) {
          const name = (c.name || "").toLowerCase();
          if (name.includes("helper") || name.includes("grid") || name.includes("dome") || 
              name.includes("skybox") || name.includes("background") || name.includes("camera") || 
              name.includes("light")) {
            return;
          }
          if (c.geometry) {
            if (!c.geometry.boundingSphere) c.geometry.computeBoundingSphere();
            if (c.geometry.boundingSphere && c.geometry.boundingSphere.radius > 50) {
              return; // skip environment domes
            }
          }
          box.expandByObject(c);
          hasMesh = true;
        }
      });
      
      if (!hasMesh || box.isEmpty()) {
        box.setFromObject(model);
      }
      
      const sz = box.getSize(new THREE.Vector3());
      if (sz.x === 0) sz.x = 1;
      if (sz.y === 0) sz.y = 1;
      if (sz.z === 0) sz.z = 1;
      
      // Scale uniformly to fit within fw and fd
      const scaleX = fw / sz.x;
      const scaleZ = fd / sz.z;
      let scaleToUse = Math.min(scaleX, scaleZ);
      
      // Safe fallback if bounding box is calculated incorrectly
      if (scaleToUse < 0.01 || scaleToUse > 100) {
        scaleToUse = 1.0;
      }
      
      const center = box.getCenter(new THREE.Vector3());
      const min = box.min;
      
      // Apply uniform scale and offset model to place its pivot bottom-center
      model.scale.set(scaleToUse, scaleToUse, scaleToUse);
      model.position.set(-center.x * scaleToUse, -min.y * scaleToUse, -center.z * scaleToUse);
      
      // Traverse meshes to configure shadow casting/receiving and improve texture quality
      model.traverse(c => {
        if (c.isMesh) {
          c.castShadow = true;
          c.receiveShadow = true;
          if (c.material) {
            const materials = Array.isArray(c.material) ? c.material : [c.material];
            materials.forEach(mat => {
              if (mat.map) {
                // Improve texture filtering and anisotropic sharpness
                const maxAnisotropy = renderer.capabilities.getMaxAnisotropy() || 1;
                mat.map.anisotropy = maxAnisotropy;
                mat.map.minFilter = THREE.LinearMipmapLinearFilter;
                mat.map.magFilter = THREE.LinearFilter;
                mat.map.needsUpdate = true;
              }
            });
          }
        }
      });
      
      itemGroup.add(model);
      selectItem(data);
    }, undefined, () => {
      fallbackBox(itemGroup, fw, fd);
      selectItem(data);
    });
  } else {
    fallbackBox(itemGroup, fw, fd);
    selectItem(data);
  }
};

function fallbackBox(group, w, d) {
  const h = 0.55;
  const m = new THREE.Mesh(
    new THREE.BoxGeometry(w, h, d),
    new THREE.MeshStandardMaterial({ color: 0x38bdf8, roughness: 0.5, transparent: true, opacity: 0.8 })
  );
  m.position.y = h / 2;
  m.castShadow = true;
  group.add(m);
}

window.addPresetFurniture = function (type) {
  const preset = FURNITURE_PRESETS[type];
  if (!preset) return;
  const id = `preset_${type}_${Date.now()}`;
  window.addFurniture(id, type, preset.label, preset.w, preset.d, '');
};

window.setView = function (mode) {
  viewMode = mode;
  is3DMode = mode === '3d' || mode === 'fps';

  if (gridHelper) gridHelper.visible = mode === '2d';

  const leftControls = document.getElementById('left-controls');
  const walkBtn = document.getElementById('walk-btn');
  const colorToggleBtn = document.getElementById('color-toggle-btn');
  const colorPalette = document.getElementById('color-picker-palette');
  const reticle = document.getElementById('reticle');

  if (mode === '2d') {
    currentCamera = camera2D;
    const asp = window.innerWidth / window.innerHeight;
    const d = Math.max(roomWidth, roomLength) * 0.65;
    camera2D.left = -d * asp; camera2D.right = d * asp;
    camera2D.top = d; camera2D.bottom = -d;
    camera2D.updateProjectionMatrix();
    orbitControls.enabled = false;

    if (leftControls) leftControls.style.display = 'none';
    if (walkBtn) walkBtn.style.display = 'none';
    if (colorToggleBtn) colorToggleBtn.style.display = 'none';
    if (colorPalette) colorPalette.style.display = 'none';
    if (reticle) reticle.style.display = 'none';
  } else if (mode === '3d') {
    currentCamera = camera3D;
    orbitControls.enabled = true;

    if (leftControls) leftControls.style.display = 'flex';
    if (walkBtn) walkBtn.style.display = 'flex';
    if (colorToggleBtn) colorToggleBtn.style.display = 'flex';
    if (reticle) reticle.style.display = 'none';
  } else if (mode === 'fps') {
    currentCamera = cameraFPS;
    orbitControls.enabled = false;
    // Place camera at room center, standing height
    fpsState.yaw = 0;
    fpsState.pitch = 0;
    cameraFPS.position.set(0, fpsState.height, 0.5);
    showJoystick(true);

    if (leftControls) leftControls.style.display = 'none';
    if (reticle) reticle.style.display = 'block';
  }

  if (mode !== 'fps') showJoystick(false);

  // Update wall rendering faces dynamically so camera can look inside
  wallGroup.children.forEach(w => {
    if (w.name === 'wall') {
      w.material.side = (mode === 'fps') ? THREE.BackSide : THREE.FrontSide;
      w.material.needsUpdate = true; // Tell Three.js to recompile/redraw the material
    }
  });
};

window.rotateSelected = function () {
  if (!selectedItem) return;
  // Snapped items like doors and windows rotate in 90deg increments if rotated
  if (selectedItem.type === 'door' || selectedItem.type === 'window') {
    selectedItem.group.rotation.y += Math.PI / 2;
  } else {
    selectedItem.group.rotation.y += Math.PI / 4;
  }
};

window.deleteSelected = function () {
  if (!selectedItem) return;
  scene.remove(selectedItem.group);
  furnitureItems = furnitureItems.filter(i => i !== selectedItem);
  deselectItem();
};

window.exportLayout = function () {
  const placements = furnitureItems.map(item => ({
    type: item.type, name: item.name,
    x: item.group.position.x, z: item.group.position.z,
    rotationY: (item.group.rotation.y * 180 / Math.PI) % 360,
  }));
  sendMessageToFlutter('onLayoutExported', { placements });
};

window.setWallColor = function (hex) {
  // Parse hex string safely for all Three.js versions (some don't support '#RRGGBB' strings)
  if (typeof hex === 'string') {
    const cleaned = hex.replace('#', '');
    wallColor = new THREE.Color(parseInt(cleaned, 16));
  } else {
    wallColor = new THREE.Color(hex);
  }
  wallGroup.children.forEach(w => {
    if (w.name === 'wall') {
      w.material.color.copy(wallColor);
      w.material.needsUpdate = true;
    }
  });
};

// ── Save / Load Layout ────────────────────────────────────────

// Returns the complete layout state as a JSON-serializable object
window.getLayoutData = function () {
  const placements = furnitureItems.map(item => ({
    id: item.id,
    type: item.type,
    name: item.name,
    w: item.w,
    d: item.d,
    x: item.group.position.x,
    y: item.group.position.y,
    z: item.group.position.z,
    rotationY: item.group.rotation.y,
  }));
  return JSON.stringify({
    roomWidth: roomWidth,
    roomLength: roomLength,
    roomHeight: roomHeight,
    wallColor: '#' + wallColor.getHexString(),
    placements: placements,
  });
};

// Restores a previously saved layout — clears current items, rebuilds room, re-adds furniture
window.loadLayout = function (jsonStr) {
  try {
    const data = typeof jsonStr === 'string' ? JSON.parse(jsonStr) : jsonStr;

    // Restore room dimensions
    if (data.roomWidth) roomWidth = parseFloat(data.roomWidth);
    if (data.roomLength) roomLength = parseFloat(data.roomLength);
    if (data.roomHeight) roomHeight = parseFloat(data.roomHeight);

    // Restore wall color
    if (data.wallColor) {
      window.setWallColor(data.wallColor);
    }

    // Rebuild room geometry with restored dimensions and color
    rebuildRoom();

    // Clear existing furniture
    furnitureItems.forEach(item => scene.remove(item.group));
    furnitureItems = [];
    deselectItem();

    // Re-add each saved placement
    if (data.placements && Array.isArray(data.placements)) {
      data.placements.forEach(p => {
        window.addFurniture(p.id, p.type, p.name, p.w, p.d, '');
        // After addFurniture, the last item in furnitureItems is the one we just added
        const item = furnitureItems[furnitureItems.length - 1];
        if (item) {
          item.group.position.x = parseFloat(p.x) || 0;
          item.group.position.y = parseFloat(p.y) || 0;
          item.group.position.z = parseFloat(p.z) || 0;
          item.group.rotation.y = parseFloat(p.rotationY) || 0;
        }
      });
      deselectItem(); // deselect after restoring all
    }

    // Update active color swatch in UI
    if (data.wallColor) {
      document.querySelectorAll('.color-swatch').forEach(el => {
        const swatchHex = el.getAttribute('data-color');
        if (swatchHex && swatchHex.toLowerCase() === data.wallColor.toLowerCase()) {
          document.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('active'));
          el.classList.add('active');
        }
      });
    }

    sendMessageToFlutter('onLayoutLoaded', { itemCount: (data.placements || []).length });
  } catch (e) {
    console.error('[loadLayout] Error:', e);
  }
};

// ── FPS Joystick ──────────────────────────────────────────────
function setupJoystick() {
  const joystick = document.getElementById('joystick-zone');
  const lookZone = document.getElementById('look-zone');
  const stick = document.getElementById('joystick-stick');

  if (!joystick) return;

  const onJoyStart = (e) => {
    e.preventDefault();
    const t = e.touches ? e.touches[0] : e;
    fpsState.joystickActive = true;
    fpsState.joyStartX = t.clientX;
    fpsState.joyStartY = t.clientY;
    fpsState.joyDeltaX = 0;
    fpsState.joyDeltaY = 0;
  };
  const onJoyMove = (e) => {
    e.preventDefault();
    if (!fpsState.joystickActive) return;
    const t = e.touches ? e.touches[0] : e;
    const dx = t.clientX - fpsState.joyStartX;
    const dy = t.clientY - fpsState.joyStartY;
    const max = 40;
    fpsState.joyDeltaX = Math.max(-max, Math.min(max, dx));
    fpsState.joyDeltaY = Math.max(-max, Math.min(max, dy));
    if (stick) {
      stick.style.transform = `translate(calc(-50% + ${fpsState.joyDeltaX}px), calc(-50% + ${fpsState.joyDeltaY}px))`;
    }
  };
  const onJoyEnd = (e) => {
    fpsState.joystickActive = false;
    fpsState.joyDeltaX = 0; fpsState.joyDeltaY = 0;
    if (stick) stick.style.transform = 'translate(-50%, -50%)';
  };

  joystick.addEventListener('touchstart', onJoyStart, { passive: false });
  joystick.addEventListener('touchmove', onJoyMove, { passive: false });
  joystick.addEventListener('touchend', onJoyEnd);
  joystick.addEventListener('mousedown', onJoyStart);
  window.addEventListener('mousemove', (e) => { if (fpsState.joystickActive) onJoyMove(e); });
  window.addEventListener('mouseup', onJoyEnd);

  const onLookStart = (e) => {
    if (viewMode !== 'fps') return;
    e.preventDefault();
    const t = e.touches ? e.touches[0] : e;
    fpsState.lookActive = true;
    fpsState.lookStartX = t.clientX;
    fpsState.lookStartY = t.clientY;
  };
  const onLookMove = (e) => {
    if (!fpsState.lookActive || viewMode !== 'fps') return;
    const t = e.touches ? e.touches[0] : e;
    fpsState.lookDeltaX = (t.clientX - fpsState.lookStartX) * 0.004;
    fpsState.lookDeltaY = (t.clientY - fpsState.lookStartY) * 0.003;
    fpsState.lookStartX = t.clientX;
    fpsState.lookStartY = t.clientY;
  };
  const onLookEnd = () => { fpsState.lookActive = false; fpsState.lookDeltaX = 0; fpsState.lookDeltaY = 0; };

  if (lookZone) {
    lookZone.addEventListener('touchstart', onLookStart, { passive: false });
    lookZone.addEventListener('touchmove', onLookMove, { passive: false });
    lookZone.addEventListener('touchend', onLookEnd);
    lookZone.addEventListener('mousedown', onLookStart);
    lookZone.addEventListener('mousemove', onLookMove);
    lookZone.addEventListener('mouseup', onLookEnd);
  }
}

function showJoystick(visible) {
  const jz = document.getElementById('joystick-zone');
  const lz = document.getElementById('look-zone');
  const hud = document.getElementById('fps-hud');
  if (jz) jz.style.display = visible ? 'block' : 'none';
  if (lz) lz.style.display = visible ? 'block' : 'none';
  if (hud) hud.style.display = visible ? 'flex' : 'none';
}

function updateFPS(dt) {
  if (viewMode !== 'fps') return;

  // Apply look from drag delta
  fpsState.yaw -= fpsState.lookDeltaX;
  fpsState.pitch += fpsState.lookDeltaY;
  fpsState.pitch = Math.max(-Math.PI / 3, Math.min(Math.PI / 3, fpsState.pitch));
  fpsState.lookDeltaX = 0;
  fpsState.lookDeltaY = 0;

  // Move from joystick
  const jMax = 40;
  const jx = fpsState.joyDeltaX / jMax; // -1 to 1
  const jy = fpsState.joyDeltaY / jMax;

  if (Math.abs(jx) > 0.05 || Math.abs(jy) > 0.05) {
    const spd = fpsState.speed * dt;
    const fwd = new THREE.Vector3(
      Math.sin(fpsState.yaw), 0, Math.cos(fpsState.yaw)
    );
    const right = new THREE.Vector3(
      Math.cos(fpsState.yaw), 0, -Math.sin(fpsState.yaw)
    );
    cameraFPS.position.addScaledVector(fwd, jy * spd);
    cameraFPS.position.addScaledVector(right, jx * spd);

    // Clamp inside room
    const margin = 0.25;
    cameraFPS.position.x = Math.max(-(roomWidth / 2 - margin), Math.min(roomWidth / 2 - margin, cameraFPS.position.x));
    cameraFPS.position.z = Math.max(-(roomLength / 2 - margin), Math.min(roomLength / 2 - margin, cameraFPS.position.z));
  }

  cameraFPS.position.y = fpsState.height;

  // Apply rotation
  const euler = new THREE.Euler(fpsState.pitch, fpsState.yaw, 0, 'YXZ');
  cameraFPS.quaternion.setFromEuler(euler);
}

// ── Helpers ────────────────────────────────────────────────────
function clampAllFurniture() {
  furnitureItems.forEach(item => {
    const mX = roomWidth / 2 - item.w / 2 - 0.06;
    const mZ = roomLength / 2 - item.d / 2 - 0.06;
    item.group.position.x = Math.max(-mX, Math.min(mX, item.group.position.x));
    item.group.position.z = Math.max(-mZ, Math.min(mZ, item.group.position.z));
  });
}

function onWindowResize() {
  const w = window.innerWidth, h = window.innerHeight;
  const asp = w / h;
  camera3D.aspect = asp; camera3D.updateProjectionMatrix();
  cameraFPS.aspect = asp; cameraFPS.updateProjectionMatrix();
  const d = 5;
  camera2D.left = -d * asp; camera2D.right = d * asp;
  camera2D.top = d; camera2D.bottom = -d;
  camera2D.updateProjectionMatrix();
  renderer.setSize(w, h);
}

function sendMessageToFlutter(handler, data) {
  if (window.flutter_inappwebview?.callHandler) {
    window.flutter_inappwebview.callHandler(handler, data);
  } else {
    console.log(`[Flutter→] ${handler}:`, data);
  }
}

function animate() {
  requestAnimationFrame(animate);
  const now = performance.now();
  const dt = Math.min((now - lastFPSTime) / 1000, 0.05);
  lastFPSTime = now;

  if (viewMode === '3d') orbitControls.update();
  if (viewMode === 'fps') updateFPS(dt);

  if (selectedItem) {
    const ring = selectedItem.group.getObjectByName('sel_ring');
    if (ring) ring.rotation.z += 0.008;
  }

  renderer.render(scene, currentCamera);
}

window.takeScreenshot = function () {
  const ring = selectedItem ? selectedItem.group.getObjectByName('sel_ring') : null;
  const ringVisible = ring ? ring.visible : false;
  if (ring) ring.visible = false;
  renderer.render(scene, currentCamera);
  const dataUrl = renderer.domElement.toDataURL('image/png');
  if (ring) ring.visible = ringVisible;
  return dataUrl;
};

window.onload = init;
