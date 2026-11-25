import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { LineSegments2 } from 'three/addons/lines/LineSegments2.js';
import { LineSegmentsGeometry } from 'three/addons/lines/LineSegmentsGeometry.js';
import { LineMaterial } from 'three/addons/lines/LineMaterial.js';

THREE.Object3D.DEFAULT_UP.set(0, 0, 1);

const PERCEPTION_HZ = 12;
// Draw one perception frame behind real time so there is always a later frame to interpolate towards (D-005).
const RENDER_DELAY = 1 / PERCEPTION_HZ;
const REAR_AXLE_TO_CENTER = 1.3;
const FADE_S = 0.3;
const CELL = 0.4;
const PATH_HALF_WIDTH = 0.9;
const IN_PATH_DISTANCE = 1.6;
const STATIC_OCC = new Set([0, 15, 16]); // Occ3D: others (general objects), manmade, vegetation
const VEHICLES = new Set(['car', 'truck', 'bus', 'bike']);
const OCC_PALETTE = [0xff6b6b, 0xc8c8c8, 0xf4a261, 0xf6d55c, 0x6fa8ff, 0xa66cff, 0xff8fab, 0xffd166, 0xff9f1c,
  0x9b8579, 0x4ecdc4, 0x3a3f47, 0x6c5b7b, 0x8d99ae, 0x6b8f71, 0xadb5bd, 0x52b788, 0x000000];
const BOX_COLORS = { car: 0x9aa1aa, truck: 0x8c939c, bus: 0x8c939c, bike: 0xb7bec7, ped: 0xd6dbe1,
  cone: 0xf39c12, barrier: 0xc8ccd2, other: 0x7f8790 };
const IN_PATH_COLOR = new THREE.Color(0x3d8bff);

const $ = (id) => document.getElementById(id);
const ui = { scene: $('scene'), desc: $('desc'), play: $('play'), speed: $('speed'), cam: $('cam'), occ: $('occ'),
  camOnly: $('camOnly'), boxes: $('boxes'), map: $('map'), path: $('path'), stats: $('stats'), scrub: $('scrub'),
  time: $('time'), message: $('message') };
const params = new URLSearchParams(location.search);
for (const [param, el] of [['view', ui.cam], ['occ', ui.occ]]) {
  if (params.has(param)) el.value = params.get(param);
}

const canvas = $('view');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x0f1114);
scene.fog = new THREE.Fog(0x0f1114, 70, 190);
const camera = new THREE.PerspectiveCamera(55, 1, 0.5, 800);
const controls = new OrbitControls(camera, canvas);
controls.enabled = false;
scene.add(new THREE.HemisphereLight(0xdfe7ff, 0x1a1c20, 1.6));
const sun = new THREE.DirectionalLight(0xffffff, 1.4);
sun.position.set(-30, -20, 60);
scene.add(sun);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(4000, 4000), new THREE.MeshBasicMaterial({ color: 0x15181c }));
ground.position.z = -0.05;
scene.add(ground);

const ego = makeEgo();
scene.add(ego);

const BOX_GEOMS = {
  box: new THREE.BoxGeometry(1, 1, 1),
  ped: new THREE.CylinderGeometry(0.5, 0.5, 1, 12).rotateX(Math.PI / 2),
  cone: new THREE.ConeGeometry(0.5, 1, 12).rotateX(Math.PI / 2),
};
const BOX_MATS = Object.fromEntries(Object.entries(BOX_COLORS).map(([k, c]) =>
  [k, new THREE.MeshStandardMaterial({ color: c, roughness: 0.55, metalness: 0.05 })]));
const OCC_GEOM = new THREE.BoxGeometry(CELL, CELL, CELL);
const OCC_MAT = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.9 });
const SMOOTH_MAT = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.85, metalness: 0.02 });
const SHARED = new Set([...Object.values(BOX_GEOMS), ...Object.values(BOX_MATS), OCC_GEOM, OCC_MAT, SMOOTH_MAT]);
const OCC_GREYS = [...Array(16).keys()].map((k) => new THREE.Color(0x4f555d).lerp(new THREE.Color(0xb4bcc6), k / 15));
const OCC_COLORS = OCC_PALETTE.map((c) => new THREE.Color(c));

const PATH_MAX = 64;
const pathGeom = new THREE.BufferGeometry();
pathGeom.setAttribute('position', new THREE.BufferAttribute(new Float32Array(PATH_MAX * 6), 3));
pathGeom.setIndex([...Array(PATH_MAX - 1).keys()].flatMap((i) => [2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 1, 2 * i + 3, 2 * i + 2]));
const pathMesh = new THREE.Mesh(pathGeom, new THREE.MeshBasicMaterial({
  color: 0x3d8bff, transparent: true, opacity: 0.8, depthWrite: false, side: THREE.DoubleSide }));
pathMesh.frustumCulled = false;
scene.add(pathMesh);
const pathPts = [];

let world = null;          // per-scene content
let mapGroup = null;
let occGroup = null;       // placed at the current occupancy keyframe's ego pose
let staticCells = null;    // static occupancy re-voxelised into one world-fixed grid, in first-seen order
let staticVoxels = null;   // InstancedMesh drawing staticCells as cubes
let staticSmooth = null;   // {mesh, prefix}: staticCells as one smoothed surface
let keyframeMesh = null;   // one keyframe's full grid, all classes, in its own ego frame
let keyframeKey = '';
let lineMaterials = [];
const trackMeshes = new Map();
let trackSpan = new Map(); // track id -> [first t, last t]

let data = null;
let frames = [];
let lastOcc = [];          // frame index -> index of the latest frame at or before it that carries occupancy
let occKeyframes = [];     // frame indices that carry occupancy
let playTime = 0;
let playing = true;
let scrubbing = false;
let camReady = false;

const egoPos = new THREE.Vector3();
const egoQuat = new THREE.Quaternion();
const lastEgoPos = new THREE.Vector3();
const camPos = new THREE.Vector3();
const camLook = new THREE.Vector3();
const qa = new THREE.Quaternion();
const qb = new THREE.Quaternion();
const tmpMatrix = new THREE.Matrix4();
const tmpVec = new THREE.Vector3();

const stats = { fps: 0, frameMsWorst: 0, frame: 0, frames: 0, t: 0, boxes: 0, inPath: 0, voxels: 0, occAge: null, errors: [] };
window.__teslarender = stats;
window.addEventListener('error', (e) => stats.errors.push(String(e.message)));

function makeEgo() {
  const g = new THREE.Group();
  const mat = new THREE.MeshStandardMaterial({ color: 0xf2f4f7, roughness: 0.35, metalness: 0.1 });
  const body = new THREE.Mesh(new THREE.BoxGeometry(4.1, 1.8, 0.8), mat);
  body.position.set(REAR_AXLE_TO_CENTER, 0, 0.6);
  const cabin = new THREE.Mesh(new THREE.BoxGeometry(2.2, 1.6, 0.55), mat);
  cabin.position.set(REAR_AXLE_TO_CENTER - 0.3, 0, 1.27);
  g.add(body, cabin);
  return g;
}

const lerp = (a, b, u) => a + (b - a) * u;
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
function lerpAngle(a, b, u) {
  const d = Math.atan2(Math.sin(b - a), Math.cos(b - a));
  return a + d * u;
}

function bracket(t) {
  let lo = 0, hi = frames.length - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (frames[mid].t <= t) lo = mid; else hi = mid - 1;
  }
  return lo;
}

function lineSet(polylines, color, width, z) {
  const pos = [];
  for (const pl of polylines) {
    for (let i = 0; i + 1 < pl.length; i++) pos.push(pl[i][0], pl[i][1], z, pl[i + 1][0], pl[i + 1][1], z);
  }
  if (!pos.length) return new THREE.Group();
  const mat = new LineMaterial({ color, linewidth: width, worldUnits: false });
  lineMaterials.push(mat);
  return new LineSegments2(new LineSegmentsGeometry().setPositions(pos), mat);
}

function buildMap(map) {
  const g = new THREE.Group();
  const shapes = map.drivable.map((p) => {
    const s = new THREE.Shape(p.outer.map(([x, y]) => new THREE.Vector2(x, y)));
    s.holes = p.holes.map((h) => new THREE.Path(h.map(([x, y]) => new THREE.Vector2(x, y))));
    return s;
  });
  if (shapes.length) g.add(new THREE.Mesh(new THREE.ShapeGeometry(shapes), new THREE.MeshBasicMaterial({ color: 0x272b31 })));
  g.add(lineSet(map.road_edges, 0xd9534f, 3, 0.03));
  g.add(lineSet(map.lane_dividers, 0xe8ebef, 1.6, 0.04));
  g.add(lineSet(map.road_dividers, 0xf0c35a, 2.2, 0.04));
  return g;
}

function disposeWorld() {
  if (!world) return;
  world.traverse((o) => {
    if (o.isInstancedMesh) o.dispose();
    if (o.geometry && !SHARED.has(o.geometry)) o.geometry.dispose();
    if (o.material && !SHARED.has(o.material)) o.material.dispose();
  });
  scene.remove(world);
  trackMeshes.clear();
  lineMaterials = [];
  staticCells = null;
  staticVoxels = null;
  staticSmooth = null;
  keyframeMesh = null;
}

function decodeOcc(f) {
  if (!f.occ.values) {
    const bin = atob(f.occ.packed);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    f.occ.values = new Uint32Array(bytes.buffer);
  }
  return f.occ.values;
}

// visit(class, cameraVisible, x, y, z) for every occupied voxel of a keyframe, in that keyframe's ego frame
function forEachVoxel(f, visit) {
  const [x0, y0, z0] = data.occ_grid.range;
  const vs = data.occ_grid.voxel;
  const [, ny, nz] = data.occ_grid.shape;
  for (const v of decodeOcc(f)) {
    const idx = v >>> 6;
    const k = idx % nz;
    const j = Math.floor(idx / nz) % ny;
    const i = Math.floor(idx / (nz * ny));
    visit(v & 31, (v >>> 5) & 1, x0 + (i + 0.5) * vs, y0 + (j + 0.5) * vs, z0 + (k + 0.5) * vs);
  }
}

function newInstanced(capacity, parent) {
  const m = new THREE.InstancedMesh(OCC_GEOM, OCC_MAT, Math.max(1, capacity));
  m.count = 0;
  m.frustumCulled = false;
  parent.add(m);
  return m;
}

const cellKey = (ix, iy, iz) => ((ix + 4096) * 8192 + (iy + 4096)) * 128 + (iz + 64);

// Each keyframe's grid sits in a different ego frame, so drawing keyframes one after another makes the static world
// jump by up to half a voxel every 0.5 s. Instead, snap every static voxel into one world-aligned grid, in the order the
// keyframes first saw it; playback then only changes how much of it is drawn.
function collectStaticCells(camOnly) {
  for (const old of [staticVoxels, staticSmooth?.mesh]) {
    if (!old) continue;
    old.removeFromParent();
    if (old.isInstancedMesh) old.dispose(); else old.geometry.dispose();
  }
  staticVoxels = null;
  staticSmooth = null;
  const index = new Map();
  const cells = [];
  const firstSeen = [];
  const prefix = [];
  const m = new THREE.Matrix4();
  const e = m.elements;
  const pos = new THREE.Vector3();
  const quat = new THREE.Quaternion();
  const one = new THREE.Vector3(1, 1, 1);
  occKeyframes.forEach((fi, kfPos) => {
    const p = frames[fi].occ.ego_pose;
    m.compose(pos.set(p.t[0], p.t[1], p.t[2]), quat.set(p.q[1], p.q[2], p.q[3], p.q[0]), one);
    forEachVoxel(frames[fi], (cls, cam, x, y, z) => {
      if (!STATIC_OCC.has(cls) || (camOnly && !cam)) return;
      const ix = Math.floor((e[0] * x + e[4] * y + e[8] * z + e[12]) / CELL);
      const iy = Math.floor((e[1] * x + e[5] * y + e[9] * z + e[13]) / CELL);
      const iz = Math.floor((e[2] * x + e[6] * y + e[10] * z + e[14]) / CELL);
      const key = cellKey(ix, iy, iz);
      if (index.has(key)) return;
      index.set(key, firstSeen.length);
      cells.push(ix, iy, iz);
      firstSeen.push(kfPos);
    });
    prefix.push(firstSeen.length);
  });
  staticCells = { camOnly, index, cells, firstSeen, prefix };
}

function buildStaticVoxels() {
  const { cells } = staticCells;
  const n = cells.length / 3;
  const mesh = newInstanced(n, world);
  for (let c = 0; c < n; c++) {
    const iz = cells[3 * c + 2];
    tmpMatrix.makeTranslation((cells[3 * c] + 0.5) * CELL, (cells[3 * c + 1] + 0.5) * CELL, (iz + 0.5) * CELL);
    mesh.setMatrixAt(c, tmpMatrix);
    mesh.setColorAt(c, OCC_GREYS[clamp(iz + 3, 0, 15)]);
  }
  mesh.instanceMatrix.needsUpdate = true;
  if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  return mesh;
}

// Outward faces of a unit cell: neighbour offset, then the four corners counter-clockwise seen from outside.
const CELL_FACES = [
  [1, 0, 0, [[1, 0, 0], [1, 1, 0], [1, 1, 1], [1, 0, 1]]],
  [-1, 0, 0, [[0, 0, 0], [0, 0, 1], [0, 1, 1], [0, 1, 0]]],
  [0, 1, 0, [[0, 1, 0], [0, 1, 1], [1, 1, 1], [1, 1, 0]]],
  [0, -1, 0, [[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1]]],
  [0, 0, 1, [[0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]]],
  [0, 0, -1, [[0, 0, 0], [0, 1, 0], [1, 1, 0], [1, 0, 0]]],
];

// Taubin smoothing: alternate shrink (λ) and inflate (μ) Laplacian steps, which rounds corners without the volume loss
// plain Laplacian smoothing causes. Edges are listed once per quad side, so shared edges simply weigh double.
function taubinSmooth(P, edges, iterations) {
  const n = P.length / 3;
  const sum = new Float32Array(P.length);
  const count = new Uint16Array(n);
  const step = (factor) => {
    sum.fill(0);
    count.fill(0);
    for (let i = 0; i < edges.length; i += 2) {
      const a = 3 * edges[i], b = 3 * edges[i + 1];
      sum[a] += P[b]; sum[a + 1] += P[b + 1]; sum[a + 2] += P[b + 2];
      sum[b] += P[a]; sum[b + 1] += P[a + 1]; sum[b + 2] += P[a + 2];
      count[edges[i]]++;
      count[edges[i + 1]]++;
    }
    for (let v = 0; v < n; v++) {
      if (!count[v]) continue;
      for (let k = 0; k < 3; k++) P[3 * v + k] += factor * (sum[3 * v + k] / count[v] - P[3 * v + k]);
    }
  };
  for (let i = 0; i < iterations; i++) {
    step(0.5);
    step(-0.53);
  }
}

// The FSD screen shows smooth grey shapes, not cubes: take the outward faces of the occupied cells, merge shared
// corners, then smooth. Triangles are ordered by when their cell was first seen, so a draw range reveals the world.
function buildStaticSmooth() {
  const t0 = performance.now();
  const { index, cells, firstSeen, prefix } = staticCells;
  const vertexOf = new Map();
  const lattice = [];
  const quadsByKeyframe = prefix.map(() => []);
  const vertex = (x, y, z) => {
    const key = cellKey(x, y, z);
    let v = vertexOf.get(key);
    if (v === undefined) {
      v = lattice.length / 3;
      vertexOf.set(key, v);
      lattice.push(x, y, z);
    }
    return v;
  };
  for (let c = 0; c < firstSeen.length; c++) {
    const ix = cells[3 * c], iy = cells[3 * c + 1], iz = cells[3 * c + 2];
    const quads = quadsByKeyframe[firstSeen[c]];
    for (const [dx, dy, dz, corners] of CELL_FACES) {
      if (index.has(cellKey(ix + dx, iy + dy, iz + dz))) continue;
      for (const [cx, cy, cz] of corners) quads.push(vertex(ix + cx, iy + cy, iz + cz));
    }
  }
  const quads = quadsByKeyframe.flat();
  const indices = new Uint32Array((quads.length / 4) * 6);
  const edges = new Uint32Array(quads.length * 2);
  for (let q = 0, o = 0, e = 0; q < quads.length; q += 4) {
    const a = quads[q], b = quads[q + 1], c = quads[q + 2], d = quads[q + 3];
    indices.set([a, b, c, a, c, d], o);
    o += 6;
    edges.set([a, b, b, c, c, d, d, a], e);
    e += 8;
  }
  const P = new Float32Array(lattice);
  taubinSmooth(P, edges, 4);
  const colors = new Float32Array(P.length);
  const low = new THREE.Color(0x4f555d), high = new THREE.Color(0xb4bcc6), c = new THREE.Color();
  for (let v = 0; v < P.length; v += 3) {
    for (let k = 0; k < 3; k++) P[v + k] *= CELL;
    c.copy(low).lerp(high, clamp((P[v + 2] + 1) / 6.4, 0, 1)).toArray(colors, v);
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(P, 3));
  geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geometry.setIndex(new THREE.BufferAttribute(indices, 1));
  geometry.computeVertexNormals();
  const mesh = new THREE.Mesh(geometry, SMOOTH_MAT);
  mesh.frustumCulled = false;
  world.add(mesh);
  let acc = 0;
  const indexPrefix = quadsByKeyframe.map((qs) => (acc += (qs.length / 4) * 6));
  stats.smoothBuildMs = performance.now() - t0;
  stats.smoothTriangles = indices.length / 3;
  return { mesh, prefix: indexPrefix };
}

function showKeyframe(fi, camOnly) {
  const key = `${fi}|${camOnly}`;
  if (key === keyframeKey) return keyframeMesh.count;
  keyframeKey = key;
  let n = 0;
  forEachVoxel(frames[fi], (cls, cam, x, y, z) => {
    if (camOnly && !cam) return;
    tmpMatrix.makeTranslation(x, y, z);
    keyframeMesh.setMatrixAt(n, tmpMatrix);
    keyframeMesh.setColorAt(n, OCC_COLORS[cls]);
    n++;
  });
  keyframeMesh.count = n;
  keyframeMesh.instanceMatrix.needsUpdate = true;
  if (keyframeMesh.instanceColor) keyframeMesh.instanceColor.needsUpdate = true;
  const p = frames[fi].occ.ego_pose;
  occGroup.position.set(p.t[0], p.t[1], p.t[2]);
  occGroup.quaternion.set(p.q[1], p.q[2], p.q[3], p.q[0]);
  return n;
}

function showOcc(fi) {
  const mode = ui.occ.value;
  const camOnly = ui.camOnly.checked;
  if (staticVoxels) staticVoxels.visible = mode === 'static';
  if (staticSmooth) staticSmooth.mesh.visible = mode === 'smooth';
  if (keyframeMesh) keyframeMesh.visible = mode === 'all';
  const kfPos = fi < 0 ? -1 : occKeyframes.indexOf(fi);
  if (kfPos < 0 || mode === 'off' || !keyframeMesh) return 0;
  if (mode === 'all') return showKeyframe(fi, camOnly);
  if (!staticCells || staticCells.camOnly !== camOnly) collectStaticCells(camOnly);
  if (mode === 'static') {
    staticVoxels ??= buildStaticVoxels();
    staticVoxels.visible = true;
    return (staticVoxels.count = staticCells.prefix[kfPos]);
  }
  staticSmooth ??= buildStaticSmooth();
  staticSmooth.mesh.visible = true;
  staticSmooth.mesh.geometry.setDrawRange(0, staticSmooth.prefix[kfPos]);
  return staticCells.prefix[kfPos];
}

function trackMesh(id, cls) {
  let m = trackMeshes.get(id);
  if (!m) {
    const geom = cls === 'ped' ? BOX_GEOMS.ped : cls === 'cone' ? BOX_GEOMS.cone : BOX_GEOMS.box;
    m = new THREE.Mesh(geom, (BOX_MATS[cls] ?? BOX_MATS.other).clone());
    m.userData.baseColor = m.material.color.clone();
    trackMeshes.set(id, m);
    world.add(m);
  }
  return m;
}

function distanceToPath(x, y) {
  let best = Infinity;
  for (let i = 0; i + 1 < pathPts.length; i++) {
    const [ax, ay] = pathPts[i], [bx, by] = pathPts[i + 1];
    const dx = bx - ax, dy = by - ay;
    const s = clamp(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy || 1), 0, 1);
    best = Math.min(best, Math.hypot(x - ax - s * dx, y - ay - s * dy));
  }
  return best;
}

function updateBoxes(A, B, u, rt) {
  for (const m of trackMeshes.values()) m.visible = false;
  stats.inPath = 0;
  if (!ui.boxes.checked) return 0;
  const tStart = frames[0].t, tEnd = frames[frames.length - 1].t;
  let shown = 0;
  for (const a of A.boxes) {
    const [first, last] = trackSpan.get(a.id);
    const fadeIn = first <= tStart ? 1 : (rt - first) / FADE_S;
    const fadeOut = last >= tEnd ? 1 : (last - rt) / FADE_S;
    const alpha = clamp(Math.min(fadeIn, fadeOut), 0, 1);
    if (alpha <= 0) continue;
    const b = B.boxById.get(a.id) ?? a;
    const m = trackMesh(a.id, a.cls);
    m.position.set(lerp(a.c[0], b.c[0], u), lerp(a.c[1], b.c[1], u), lerp(a.c[2], b.c[2], u));
    m.rotation.set(0, 0, lerpAngle(a.yaw, b.yaw, u));
    m.scale.set(lerp(a.s[1], b.s[1], u), lerp(a.s[0], b.s[0], u), lerp(a.s[2], b.s[2], u));
    m.material.opacity = alpha;
    m.material.transparent = alpha < 1;
    m.material.depthWrite = alpha >= 1;
    const inPath = VEHICLES.has(a.cls) && distanceToPath(m.position.x, m.position.y) < IN_PATH_DISTANCE;
    m.material.color.copy(inPath ? IN_PATH_COLOR : m.userData.baseColor);
    stats.inPath += inPath ? 1 : 0;
    m.visible = true;
    shown++;
  }
  return shown;
}

function updateEgo(A, B, u) {
  const ta = A.ego_pose.t, tb = B.ego_pose.t;
  egoPos.set(lerp(ta[0], tb[0], u), lerp(ta[1], tb[1], u), lerp(ta[2], tb[2], u));
  qa.set(A.ego_pose.q[1], A.ego_pose.q[2], A.ego_pose.q[3], A.ego_pose.q[0]);
  qb.set(B.ego_pose.q[1], B.ego_pose.q[2], B.ego_pose.q[3], B.ego_pose.q[0]);
  egoQuat.slerpQuaternions(qa, qb, u);
  ego.position.copy(egoPos);
  ego.quaternion.copy(egoQuat);
}

// The ribbon starts at the front bumper and keeps only path points ahead of the car.
function updatePath(A) {
  pathPts.length = 0;
  pathMesh.visible = false;
  if (!A.path || A.path.length < 2) return;
  const fwd = tmpVec.set(1, 0, 0).applyQuaternion(egoQuat);
  pathPts.push([egoPos.x + fwd.x * 2.5, egoPos.y + fwd.y * 2.5]);
  for (const [x, y] of A.path) {
    if (pathPts.length >= PATH_MAX) break;
    if ((x - egoPos.x) * fwd.x + (y - egoPos.y) * fwd.y > 3.5) pathPts.push([x, y]);
  }
  const n = pathPts.length;
  if (n < 2 || !ui.path.checked) return;
  const pos = pathGeom.attributes.position.array;
  for (let i = 0; i < n; i++) {
    const prev = pathPts[Math.max(0, i - 1)], next = pathPts[Math.min(n - 1, i + 1)], p = pathPts[i];
    let tx = next[0] - prev[0], ty = next[1] - prev[1];
    const len = Math.hypot(tx, ty) || 1;
    tx /= len; ty /= len;
    const hw = PATH_HALF_WIDTH * (1 - 0.4 * (i / (n - 1)));
    pos.set([p[0] - ty * hw, p[1] + tx * hw, 0.06, p[0] + ty * hw, p[1] - tx * hw, 0.06], i * 6);
  }
  pathGeom.attributes.position.needsUpdate = true;
  pathGeom.setDrawRange(0, (n - 1) * 6);
  pathMesh.visible = true;
}

function updateCamera(dt) {
  const mode = ui.cam.value;
  controls.enabled = mode === 'orbit';
  if (mode === 'orbit') {
    const delta = tmpVec.copy(egoPos).sub(lastEgoPos);
    camera.position.add(delta);
    controls.target.add(delta);
    controls.update();
    return;
  }
  const want = mode === 'top' ? new THREE.Vector3(8, 0, 70) : new THREE.Vector3(-11, 0, 5.5);
  const look = mode === 'top' ? new THREE.Vector3(8, 0, 0) : new THREE.Vector3(10, 0, 0);
  want.applyQuaternion(egoQuat).add(egoPos);
  look.applyQuaternion(egoQuat).add(egoPos);
  if (!camReady) {
    camPos.copy(want);
    camLook.copy(look);
    camReady = true;
  }
  camPos.lerp(want, 1 - Math.exp(-3 * dt));
  camLook.lerp(look, 1 - Math.exp(-6 * dt));
  camera.position.copy(camPos);
  if (mode === 'top') camera.up.set(1, 0, 0).applyQuaternion(egoQuat); else camera.up.set(0, 0, 1);
  camera.lookAt(camLook);
  controls.target.copy(camLook);
}

function resize() {
  const w = window.innerWidth, h = window.innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  for (const m of lineMaterials) m.resolution.set(w, h);
}
window.addEventListener('resize', resize);

function showMessage(text) {
  ui.message.textContent = text;
  ui.message.hidden = !text;
}

async function loadScene(file) {
  showMessage(`Loading ${file}…`);
  const res = await fetch(`public/data/${file}`);
  if (!res.ok) throw new Error(`${file}: HTTP ${res.status}`);
  const doc = await res.json();
  disposeWorld();
  data = doc;
  frames = doc.frames;
  world = new THREE.Group();
  scene.add(world);

  trackSpan = new Map();
  occKeyframes = [];
  let last = -1;
  let maxVox = 0;
  lastOcc = frames.map((f, i) => {
    f.boxById = new Map(f.boxes.map((b) => [b.id, b]));
    for (const b of f.boxes) {
      const span = trackSpan.get(b.id);
      if (span) span[1] = f.t; else trackSpan.set(b.id, [f.t, f.t]);
    }
    if (f.occ) {
      last = i;
      occKeyframes.push(i);
      maxVox = Math.max(maxVox, f.occ.n);
    }
    return last;
  });

  mapGroup = buildMap(doc.map);
  mapGroup.visible = ui.map.checked;
  world.add(mapGroup);
  occGroup = new THREE.Group();
  world.add(occGroup);
  keyframeMesh = maxVox ? newInstanced(maxVox, occGroup) : null;
  keyframeKey = '';
  resize();

  ui.desc.textContent = `${doc.location} · ${doc.description}`;
  ui.scrub.max = doc.duration;
  playTime = clamp(Number(params.get('t') ?? 0), 0, doc.duration);
  camReady = false;
  showMessage('');
}

async function init() {
  resize();
  let list;
  try {
    const res = await fetch('public/data/index.json');
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    list = await res.json();
  } catch (e) {
    showMessage('No replay files found. From the repo root run:  .venv/Scripts/python pipeline/nuscenes_to_frames.py');
    return;
  }
  for (const s of list) ui.scene.add(new Option(`${s.scene} (${s.duration.toFixed(0)} s)`, s.file));
  const pick = list.find((s) => s.scene === params.get('scene')) ?? list[0];
  ui.scene.value = pick.file;
  await loadScene(pick.file);
}

ui.scene.addEventListener('change', () => loadScene(ui.scene.value).catch((e) => showMessage(String(e))));
ui.play.addEventListener('click', () => setPlaying(!playing));
ui.speed.addEventListener('change', () => ui.speed.blur());
ui.scrub.addEventListener('input', () => { scrubbing = true; playTime = Number(ui.scrub.value); });
ui.scrub.addEventListener('change', () => { scrubbing = false; });
ui.map.addEventListener('change', () => { if (mapGroup) mapGroup.visible = ui.map.checked; });
ui.cam.addEventListener('change', () => { camReady = false; ui.cam.blur(); });
window.addEventListener('keydown', (e) => {
  if (e.target.tagName === 'SELECT') return;
  if (e.code === 'Space') { e.preventDefault(); setPlaying(!playing); }
  if (e.code === 'ArrowRight' || e.code === 'ArrowLeft') {
    setPlaying(false);
    playTime = clamp(playTime + (e.code === 'ArrowRight' ? 1 : -1) / PERCEPTION_HZ, 0, data?.duration ?? 0);
  }
});

function setPlaying(p) {
  playing = p;
  ui.play.textContent = p ? 'Pause' : 'Play';
}
if (params.get('paused') === '1') setPlaying(false);

let lastNow = performance.now();
const fpsWindow = [];
function tick(now) {
  requestAnimationFrame(tick);
  const dt = Math.min(0.1, Math.max(0, (now - lastNow) / 1000));
  lastNow = now;
  fpsWindow.push(dt);
  if (fpsWindow.length > 120) fpsWindow.shift();

  if (data && frames.length) {
    if (playing && !scrubbing) {
      playTime += dt * Number(ui.speed.value);
      if (playTime > data.duration) playTime = 0;
    }
    const rt = clamp(playTime - RENDER_DELAY, 0, data.duration);
    const i = bracket(rt);
    const A = frames[i], B = frames[Math.min(i + 1, frames.length - 1)];
    const u = B === A ? 0 : clamp((rt - A.t) / (B.t - A.t), 0, 1);
    lastEgoPos.copy(egoPos);
    updateEgo(A, B, u);
    updatePath(A);
    stats.boxes = updateBoxes(A, B, u, rt);
    stats.voxels = showOcc(lastOcc[i]);
    stats.occAge = lastOcc[i] >= 0 ? rt - frames[lastOcc[i]].t : null;
    updateCamera(dt);
    stats.frame = i;
    stats.frames = frames.length;
    stats.t = rt;
    if (!scrubbing) ui.scrub.value = playTime;
    ui.time.textContent = `${rt.toFixed(2)} / ${data.duration.toFixed(2)} s`;
  }
  renderer.render(scene, camera);

  const mean = fpsWindow.reduce((s, v) => s + v, 0) / fpsWindow.length;
  stats.fps = mean > 0 ? 1 / mean : 0;
  stats.frameMsWorst = Math.max(...fpsWindow) * 1000;
  ui.stats.textContent =
    `render      ${stats.fps.toFixed(0)} fps (worst ${stats.frameMsWorst.toFixed(1)} ms)\n` +
    `perception  frame ${stats.frame + 1}/${stats.frames} @ ${PERCEPTION_HZ} Hz\n` +
    `objects     ${stats.boxes} (${stats.inPath} in path)\n` +
    `occupancy   ${stats.voxels} voxels` + (stats.occAge == null ? '' : `, keyframe ${(stats.occAge * 1000).toFixed(0)} ms old`) +
    (ui.occ.value === 'smooth' && staticSmooth
      ? `\nsurface     ${(stats.smoothTriangles / 1000).toFixed(0)}k triangles, built in ${stats.smoothBuildMs.toFixed(0)} ms` : '');
}

init().catch((e) => showMessage(String(e)));
requestAnimationFrame(tick);
