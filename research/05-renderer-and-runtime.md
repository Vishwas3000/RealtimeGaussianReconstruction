# 05 — Renderer and inference runtime

Scope: how to draw an FSD-style world view at 60 fps, which engine to use, what open driving visualizers do, which inference runtime can run a BEV/occupancy model on a 16 GB M-series Mac or on Windows, and how to replay nuScenes.
As of 2026-11-24. Light web research only: nothing installed, downloaded or run.
Trust tags: **[primary]** = read at the source or checked through the GitHub/arXiv API; **[secondary]** = from a search snippet or a third-party summary; **[UNCERTAIN]** = not confirmed; **[inference]** = my own reasoning, not a sourced fact.

## TL;DR

- **No open, maintained "Tesla FSD visualization" clone exists.** Every GitHub hit has 0–5 stars and is a student or toy project. The best real-world references are Apollo Dreamview Plus `carviz` (three.js) and openpilot's `model_renderer.py` (Python + raylib). [primary]
- **Use two viewers, not one.** **Rerun** is the debug/truth viewer: Python, Mac + Windows, and it ships a nuScenes example. A **custom Three.js page** fed from Python is the "FSD look" renderer. Rerun and Foxglove cannot give the stylised, interpolated 60 fps look, because the viewer only shows the latest logged state at each time and there are no custom shaders. [primary for latest-at lookups; inference for the conclusion]
- **Decouple the two clocks.** Perception runs at the camera rate (nuScenes cameras are 12 Hz). The renderer draws at 60 fps by rendering one perception frame behind and interpolating between the last two results, the same trick as snapshot interpolation in networked games. Every smooth FSD-style view needs this. [primary for 12 Hz; inference for the design]
- **Runtime:** for a learner on Mac + Windows, ONNX Runtime is the only single export path (CoreML EP on Mac; CUDA/TensorRT/DirectML on Windows). The hard parts are 5-D `grid_sample` (the CoreML EP and Core ML only accept 4-D), deformable attention (a CUDA op) and `bev_pool` (a CUDA op). **FlashOcc**-style models (2-D only, channel-to-height) avoid most of these. [primary]
- **Nobody has published a latency for any BEV/occupancy model on Apple silicon.** I searched for PyTorch MPS, Core ML, MLX and ORT-CoreML numbers and found none. Mac realtime is unproven and has to be measured. Every published latency below is NVIDIA hardware: Orin, RTX 3090.

## Engine comparison (for this job)

Stars, licence and latest release are from the GitHub API on 2026-11-24 [primary]. The "Effort" column is my judgement [inference].

| Engine | Mac + Win | Python interop | Voxel / instancing path | Licence | Effort to FSD look | Verdict |
|---|---|---|---|---|---|---|
| **Rerun** 0.43.2 (11.9k★) | yes, native viewer + web | first-class `rr.log` SDK | `Boxes3D` with `FillMode::Solid` [primary]; `InstancePoses3D`; `Mesh3D`, `Asset3D` (glTF) | MIT / Apache-2.0 | very low for debugging; the FSD look is **not reachable**: no custom shaders, and transform lookups are latest-at (no interpolation) [secondary: re_tf source snippet] | **v0 debug viewer** |
| Foxglove (app) | yes (desktop + web) | `foxglove-sdk` (Python/C++, MIT, live WebSocket + MCAP) [primary] | `SceneUpdate` cubes, lines, triangles, models [primary: schema docs exist] | app is closed source since v1.87 (Feb 2024); free tier: 3 users [secondary] | low; same limits as Rerun | skip; Rerun covers it |
| Lichtblick (1.2k★) | yes | via ROS / MCAP / foxglove-bridge | same panels (it is a Foxglove fork) | MPL-2.0 [primary] | low | only if you go ROS |
| **Viser** v1.1.1 (2.9k★) | yes (browser) | **Python-native**; three.js runs in the browser | `add_batched_meshes_simple` with per-instance colour and opacity, `add_spline_catmull_rom`, `add_batched_glb`, toon materials, camera frustums, Gaussian splats [primary: `_scene_api.py`] | Apache-2.0 | low–medium; every update is pushed from Python, so 60 fps smoothing has to stream from Python [inference] | **runner-up** |
| **Three.js** r187 (119k★) | yes (browser) | WebSocket from Python | `InstancedMesh`, `BatchedMesh`, `MarchingCubes`, `Data3DTexture` volume, `Line2` fat lines, `CatmullRomCurve3` (centripetal) [primary: docs/examples] | MIT | medium (you write the JavaScript) | **v0 FSD renderer** |
| Three.js `WebGPURenderer` | browser-dependent | same | same; falls back to WebGL 2 automatically | MIT | the manual calls it "still in an experimental state"; no `ShaderMaterial` or `EffectComposer` [primary: manual] | start on WebGLRenderer |
| Babylon.js 9.37 (26k★) | yes (browser) | WebSocket | thin instances [primary: docs page]; WebGPU engine | Apache-2.0 | medium | equivalent; fewer driving references |
| Godot 4.7.2 (121k★) | yes (native export) | sockets only (`WebSocketPeer`); godot-python's Godot 4 port is "under heavy refactoring" [primary README] | `MultiMesh` [primary: docs] | MIT | medium–high (GDScript/C# and an editor) | good v1; **Tesla's own in-car viz is reported to be Godot**, moving to Unreal [secondary: Not a Tesla App / Teslarati, Aug 2025, from greentheonly's firmware digging] |
| Unity | yes | sockets | GPU instancing | proprietary; Personal tier free under US$200k [secondary] | high | rejected (licence, weight) |
| Bevy v0.20.1 (50k★) | yes | sockets / pyo3 | ECS + instancing; `block-mesh-rs` / `fast-surface-nets-rs` crates exist [primary] | MIT/Apache | high (Rust, pre-1.0 API churn) | rejected for v0 |
| raylib 6.2 (36k★) | yes | `raylib-python-cffi` (EPL-2.0) [primary] | `DrawMeshInstanced` [primary: raylib.h] | Zlib | medium–high (no scene graph, DIY lighting) | openpilot's choice; rejected for 3D |
| wgpu v30 / **pygfx** v0.18 (881★) | yes | pygfx is a **Python** wgpu engine | `InstancedMesh` (`pygfx/objects/_instanced.py`) [primary] | Apache / BSD-2 | medium (small community) | in-process Python alternative |

## Rendering techniques (with sources)

**Occupancy voxels.** The Occ3D-nuScenes grid is 200×200×16 at 0.4 m, covering ±40 m by −1…5.4 m [primary: Occ3D README], so 640k cells at most. I found no published figure for the share of cells that are occupied. Measure it; it sets the instance budget.
1. *Instanced cubes* (simplest): one cube mesh, and each frame upload a matrix + colour buffer for the occupied cells only. Equivalents: three.js `InstancedMesh` (stress test: `webgl_instancing_performance`), Godot `MultiMesh`, raylib `DrawMeshInstanced`, Rerun `Boxes3D` solid, Viser `add_batched_meshes_simple`. [primary]
2. *Greedy meshing*: merges coplanar faces into big quads, so fewer triangles, but you re-mesh every frame and the look stays blocky. Classic write-up: Mikola Lysenko, "Meshing in a Minecraft Game", https://0fps.net/2012/06/30/meshing-in-a-minecraft-game/ [primary]. Rust: `bonsairobo/block-mesh-rs` (MIT) [primary].
3. *Smooth "blobs"*: turn the binary grid into a scalar field (the model's soft probability, or a 3×3×3 Gaussian blur of the grid), then extract the iso-surface at 0.5 with surface nets or marching cubes. Write-up: https://0fps.net/2012/07/12/smooth-voxel-terrain-part-2/ [primary]. Code: three.js `MarchingCubes` (`webgl_marchingcubes`), `mikolalysenko/isosurface` (JavaScript, MIT, 2014), `bonsairobo/fast-surface-nets-rs` (MIT) [primary]. That this matches Tesla's grey-blob look is **[inference]**: I found no technical write-up of Tesla's method.
4. *GPU volume raymarch*: upload the 200×200×16 grid as a 3-D texture (about 640 kB as uint8) and raymarch it with trilinear filtering and an iso threshold, for a smooth look with no meshing on the CPU. Examples: `webgl_texture3d`, `webgpu_volume_cloud` [primary that the examples exist; inference that this suits occupancy].
→ Start with (1); move to (3) or (4) for the look.

**Temporal stability (no flicker).**
- *Snapshot interpolation*: render about one perception frame late and lerp/slerp between the two bracketing results. https://gafferongames.com/post/snapshot_interpolation/ [primary page].
- *Frame-rate-independent damping* for the camera and poses, `lerp(a, b, 1 - exp(-λ·dt))`: https://www.rorydriscoll.com/2016/03/07/frame-rate-independent-damping-using-lerp/ [primary]. three.js has `MathUtils.damp`. [secondary]
- *1€ filter* for jittery box centres and yaw: https://gery.casiez.net/1euro/ [primary].
- *Tracking gives stable IDs*, so each object can keep its mesh and fade in/out when its track starts or ends. Baseline: `xinshuoweng/AB3DMOT` (1.9k★) [primary metadata].
- *Occupancy*: apply an exponential moving average to the probabilities in a **world-fixed (ego-motion-compensated) frame**, then threshold with hysteresis (on > 0.6, off < 0.4) [inference].

**Lanes / road edges.** Fit a centripetal Catmull-Rom spline (`CatmullRomCurve3`, `curveType: 'centripetal'`, which avoids cusps [primary: docs]; Viser has `add_spline_catmull_rom`). openpilot sets lane-line alpha = probability (clipped to 0.7) and road-edge alpha = 1 − std, with road edges in red [primary: `selfdrive/ui/onroad/model_renderer.py`].

**Path ribbon.** openpilot offsets the 3-D path by ±half-width along the lateral axis, projects it onto the camera image and fills the polygon with a vertical gradient [primary]. Apollo carviz draws planning paths with `three.meshline` `MeshLine` [primary: `render/planning.ts`]. three.js `Line2`/`LineMaterial` (`webgl_lines_fat`) gives screen-space-width lines [primary].

**Object trails.** Keep a ring buffer of past world positions per track ID and draw it as a `MeshLine` or `Line2` with alpha fading by age [inference].

**Ego car and styling.** A glTF car with a simple toon or matcap shader; three.js `webgl_materials_car` is the reference car-material example [primary]. Tesla's colour semantics (2021–22 snapshot, may be stale) [secondary: notateslaapp.com reference 636]:
- vehicles grey; blue = in or entering the planned path; red = immediate action; dark grey = lead car
- road edges red; blue lane fill during a lane change
- planned path blue: darker when accelerating, faded when stopping

**Camera follow.** Apollo carviz snaps the camera to a fixed offset behind the ego car every frame, with no damping [primary: `render/view.ts`]. Use a damped chase camera instead (above).

## Existing visualizers

| Project | Renderer / stack | What it draws | Status (as of 2026-11-24) | Learn |
|---|---|---|---|---|
| openpilot (64k★, MIT) | **Python + raylib** since 0.10.1 (blog 2025-10-28: "moving from Qt to raylib and deleting Weston") [primary] | **2-D augmented-reality overlay on the camera image**: path polygon with gradient, lane lines, road edges, lead-car chevron [primary: source] | active | confidence → alpha; ribbon from offset polyline |
| Apollo Dreamview Plus `carviz` (27k★, Apache-2.0) | **three.js 0.165**, TypeScript [primary: package.json] | `adc` ego, obstacles (object pool), planning (MeshLine), prediction, HD-map lanes/crosswalks, point cloud, follow/overhead cameras [primary: file tree] | repo last push 2026-04 | closest open "real AV 3-D viz" |
| Autoware | RViz2 plugins (`autoware_perception_rviz_plugin`, overlay plugins) + Foxglove/Lichtblick [secondary] | ROS topics | active | ROS-bound; heavy on Mac/Windows |
| nuScenes devkit | matplotlib + OpenCV, 2-D | `render_sample`, `render_scene` (6 cameras + lidar video), `render_pointcloud_in_image` [primary: source] | active | sync loop (see replay) |
| Rerun nuScenes example | Rerun | lidar, radar, 6 cameras with Pinhole, GT `Boxes3D`, ego pose [primary: source] | active | ready-made replay scaffold |
| Occupancy model repos | SurroundOcc → **Mayavi**; FlashOcc → **Open3D** [primary: imports] | offline voxel screenshots | — | not realtime |
| streetscape.gl + XVIZ (Uber → Aurora, ~1k★ each) | deck.gl / WebGL | full AV log viewer | last push 2024-07 [primary] | dated design reference |
| webviz (Cruise, 2.3k★) | WebGL, ROS bags | — | last push 2022-12 [primary] | dead |
| CARLA (14.7k★, MIT) | Unreal | simulator | Linux and Windows only; no official macOS [secondary] | rejected on Mac |
| "FSD clones" | `bobcoi03/fsd-visualization` (0★, monocular SLAM), `Prasham2181/EinsteinVision…` (1★), `smehta9711/Einstein-s-Vision` (0★), `starry1N/fsd-visualization-code` (1★, RViz) [primary] | — | **all toys** | EinsteinVision is the WPI RBE/CS549 course project: offline **Blender** render from Tesla video, with a useful list of elements to draw [primary: rbe549.github.io/spring2025/proj/p3] |

## Inference runtimes and export

| Runtime | Platforms | 2-D `grid_sample` | 5-D (3-D) `grid_sample` | Deformable attention | `bev_pool` / voxel pooling | Notes |
|---|---|---|---|---|---|---|
| PyTorch MPS | macOS only | yes | forward added in PR #160541 (landed 2025-08-15), backward in #179388 (2026-04) [primary: PR comments show bot merge]. Bug #171602: non-contiguous grid gave **silently wrong** results; closed with fix PR #171619 [primary]. First release containing it: **[UNCERTAIN]** | only the pure-PyTorch fallback (built on `grid_sample`) | LSS `QuickCumsum` / `cumsum_trick` is pure PyTorch [primary: nv-tlabs/lift-splat-shoot `src/tools.py`]; BEVPoolv2 is a `.cu` op [primary] | easiest way to start; speed not reported |
| ONNX Runtime + CoreML EP | macOS | yes, 4-D only, ML Program format; no linear + reflection + `align_corners=0` [primary: EP docs] | **no** | via `grid_sample` decomposition | as a gather (see below) | Conv is 1-D/2-D only (no Conv3D); static shapes advised [primary]. SparseBEV fork reports the EP is dropped at the first unsupported partition unless `MLComputeUnits` is set [primary claim, unverified] |
| ORT + DirectML EP | Windows | — | — | — | — | DirectML is "in sustained engineering"; new work goes to **Windows ML** [primary: MS Learn, page updated 2026-01] |
| ORT + CUDA / TensorRT EP | Windows/Linux, NVIDIA | yes | ONNX `GridSample` is N-D from opset 20 (opset 16 was 4-D) [primary: onnx.ai] | needs a plugin for speed | plugin | the 4090 box |
| Core ML (coremltools) | macOS/iOS | `grid_sampler` → MIL `resample`, **rank 4 only** [primary: source] | no | decompose | gather | gets Apple Neural Engine access |
| MLX v0.32.4 | Apple silicon; Linux CUDA/CPU; **no Windows** [primary README] | no built-in; the docs implement bilinear `grid_sample` as a custom Metal kernel (forward 55.7 → 6.7 ms on an M1 Max, for that kernel only) [primary] | DIY | DIY | DIY | would mean re-implementing the model |
| TensorRT | NVIDIA only | yes | 5-D supported in the 11.5.0 operator docs [primary]; not supported up to 8.6.1 [secondary: grid-sample3d-trt-plugin README] | plugins (DerryHub) | plugins (bevdet-trt, CUDA-BEVFusion) | fastest; 4090 only |

**Known deploy ports.** All latencies are as reported in each README [primary]:

| Port | Model | Hardware | Reported speed |
|---|---|---|---|
| NVIDIA `Lidar_AI_Solution/CUDA-BEVFusion` | BEVFusion R50, 256×704 | Orin, TRT 8.6 | 18 FPS FP16; 25 FPS FP16 + INT8 (camera + lidar; lidar point count dominates) |
| `LCH1238/bevdet-tensorrt-cpp` (294★, no licence) | BEVDet | Jetson AGX Orin | ≈ 29 ms FP16, 21 ms INT8. "LSS accelerate" precomputes the BEVPool mapping from fixed intrinsics/extrinsics |
| `DerryHub/BEVFormer_tensorrt` | BEVFormer-tiny | RTX 3090 | 15.9 FPS in PyTorch; 81.2 FPS FP16 with its custom plugins |
| `DerryHub/BEVFormer_tensorrt` | BEVFormer-base | RTX 3090 | 1.8 FPS FP16 with MMDeploy plugins |
| `Yzichen/FlashOCC` (584★, Apache-2.0; arXiv 2311.12058) | M0 R50, 256×704 | RTX 3090, TRT | 197.6 FPS FP16; 397 FPS INT8. C++ TensorRT port: `drilistbox/TRT_FlashOcc` [secondary: link in README] |
| `Sense-GVT/Fast-BEV` (arXiv 2301.12511) | Fast-BEV | — | points to `CUDA-FastBEV`; no figure checked |
| `huggingface.co/chinmaygarde/SparseBev` | SparseBEV | Mac Studio (ORT CoreML EP target) | **no timing reported** |

**Export pitfalls (BEV models):**
1. Deformable attention (BEVFormer and others) is a custom CUDA op; the pure-PyTorch fallback is built on `grid_sample` and exports, but is slower [primary: SparseBEV notes its native-PyTorch sampling is "only about 15% slower" on CUDA].
2. Some models use **5-D `grid_sample`**; it has to be rewritten as 4-D `grid_sample` plus a `gather` for CoreML. The SparseBEV fork does exactly this [primary].
3. NumPy preprocessing inside `forward` (`img_metas`), 6-D advanced indexing and masked in-place assignment do not trace. Precompute `lidar2img` outside the model, use `torch.gather`, use `torch.where` [primary: SparseBEV fork].
4. `bev_pool` is a CUDA kernel (BEVPoolv2, arXiv 2211.17111 [primary]). For a **fixed camera rig** the voxel mapping is a constant, so the view transform becomes a precomputed gather or scatter that exports anywhere [inference from the bevdet-trt "LSS accelerate" note].
5. Old `mmcv-full` pins (Fast-BEV 1.4.0, SparseBEV 1.6.0) assume CUDA builds [primary]. Expect install pain on Mac/Windows [inference].

**Mac realtime, realistically:** **unknown, with no published data**. FlashOcc is the best bet: a 2-D BEV encoder, channel-to-height instead of 3-D convs, and its pooling can become a gather, so every op is CoreML-EP-friendly [inference]. The perception target is the 12 Hz camera rate, not 60 fps. Fallback: run inference offline on the 4090 and replay the results on the Mac (this also respects the "one model job at a time" rule).

## Data replay (nuScenes)

- Rates: camera **12 Hz**, radar 13 Hz, lidar **20 Hz**, annotated keyframes **2 Hz**. Each camera fires when the top lidar sweeps across the centre of that camera's view; the image timestamp is that trigger time [primary: arXiv 1903.11027].
- So the six images of one "frame" carry **staggered timestamps**. Build each camera's `lidar2img` from that camera's own `ego_pose` [inference].
- devkit `render_scene`: steps a global clock by `1/freq` and walks each channel's `sample_data.next` chain until `timestamp ≥ clock` [primary].
- devkit `get_boxes(sample_data_token)` **linearly interpolates ground-truth boxes** for non-keyframe sweeps [primary]. That gives 12 Hz ground-truth playback to build the renderer against **before any model exists**.
- Rerun's nuScenes example walks each sensor's `next` chain and calls `rr.set_time("timestamp", …)` per message [primary]. The viewer then aligns streams by latest-at.
- `foxglove/nuscenes2mcap` (MIT, 48★) converts nuScenes to MCAP [primary metadata].
- Suggested loop: key frames on `CAM_FRONT` sweeps (12 Hz); for each other camera take the nearest `sample_data`, rejecting if more than about 50 ms away; run the model (or load cached results); emit `{t, ego_pose, occ, boxes, lanes, path}`; the renderer interpolates [inference].

## Recommended v0 renderer + runtime pairing

| Decision | Why | Alternatives rejected |
|---|---|---|
| **Debug viewer = Rerun** | Python, Mac + Windows, MIT/Apache, nuScenes example already logs cameras, poses and boxes; solid `Boxes3D` shows voxels | Foxglove (closed app); Lichtblick (ROS-centric) |
| **FSD renderer = Three.js (`WebGLRenderer` first) in a browser, fed by Python over WebSocket or a replay file** | Mac + Windows for free; instancing, MarchingCubes, 3-D texture, fat lines, MeshLine and centripetal splines all have official examples; Apollo carviz proves the pattern; client-side 60 fps interpolation | Viser (runner-up: Python-only but Python-driven updates); Godot (strong v1, and Tesla reportedly used it, but a second language and editor); Unity (licence); Bevy (Rust + churn); raylib (DIY 3-D); pygfx (small community); `WebGPURenderer` ("experimental", per its manual) |
| **v0 data = ground-truth replay** (devkit `get_boxes` interpolation + Occ3D labels) | renderer work starts with zero inference; isolates rendering bugs | starting with a live model |
| **Runtime = PyTorch (CUDA) on the 4090 offline → cached results → Mac replay; then ORT (CoreML EP on Mac, CUDA EP on Windows) with a FlashOcc-style model** | one ONNX file, two platforms; FlashOcc avoids 5-D `grid_sample`, Conv3D and deformable attention | MLX (no Windows, re-implementation); TensorRT (NVIDIA only, so 4090 only); DirectML (sustained engineering only); raw Core ML (Mac only, no ONNX reuse) |

## Dead ends

- **No usable open "Tesla FSD visualization" clone.** GitHub searches ("tesla fsd visualization", "fsd visualizer", "tesla visualization three.js", "autopilot visualization threejs") returned only 0–5★ toys or nothing.
- **`microsoft/onnxruntime` returns 404** from both the GitHub REST and GraphQL APIs on 2026-11-24, although onnxruntime.ai links to it and PyPI has 1.32.0 (2026-11-13). I could not read its source or issues. **[UNCERTAIN]** whether it moved or this is transient.
- **No latency for any BEV/occupancy model on Apple silicon**, through PyTorch MPS, Core ML, MLX or the ORT CoreML EP. The SparseBEV CoreML fork reports none.
- No technical description of how Tesla renders its grey occupancy "blobs". The notateslaapp reference (last updated 2022) predates them.
- Dead or moved URLs: three.js `/manual/en/webgpurenderer.html` → 404 (used `/manual/pages/`); TensorRT 11.4.1 GridSample doc → 404 (used `latest` = 11.5.0); nuscenes.org came back empty (used the paper); viser docs were not indexed by search (read the source instead).
- Rerun interpolation between timestamps: no doc or issue found; the transform code uses latest-at lookups [secondary].

## Open questions

1. Real FPS of FlashOcc-R50 (256×704) on this Mac via the ORT CoreML EP vs PyTorch MPS. Measure, one job at a time.
2. Does the ORT CoreML EP fall back per node, or drop the whole EP (the SparseBEV fork's claim)?
3. Which PyTorch release first ships MPS `grid_sampler_3d`?
4. What share of Occ3D cells is occupied in a typical frame? It decides whether instanced cubes are enough.
5. Throughput of `WebGPURenderer` vs `WebGLRenderer` for 50k+ instanced cubes in Safari/Chrome on macOS and Edge on Windows.
6. Can a model trained on nuScenes be fed the Mac's own camera rig later? That needs new intrinsics/extrinsics, which breaks the precomputed-gather trick.
