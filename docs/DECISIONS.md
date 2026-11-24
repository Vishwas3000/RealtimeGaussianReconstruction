# Decision log

Every project decision, with its reason and what was rejected. Entries are never deleted, only marked Superseded.
**Proposed** = suggested by Claude or a research agent, not yet confirmed by the user. Evidence lives in
[`research/`](../research/README.md).

| ID | Date | Decision | Status |
|---|---|---|---|
| D-001 | 2026-11-24 | Rebuild Tesla's 2021–22 explicit pipeline first | Proposed |
| D-002 | 2026-11-24 | Data: nuScenes-mini + Occ3D-nuScenes mini | Proposed |
| D-003 | 2026-11-24 | Renderer: Three.js (WebGL) in the browser; Rerun for debugging | Proposed |
| D-004 | 2026-11-24 | Build the renderer first on ground-truth replay | Proposed |
| D-005 | 2026-11-24 | One interface: per-frame `frame.json`, renderer interpolates at 60 fps | Proposed |
| D-006 | 2026-11-24 | Perception: SparseDrive-S + FlashOcc M0, offline on the 4090 | Proposed |
| D-007 | 2026-11-24 | Mac runtime: ONNX Runtime + CoreML, FlashOcc + SparseDrive-S first | Proposed |
| D-008 | 2026-11-24 | World-sim track: OmniRe → OccWorld → Epona | Proposed |
| D-009 | 2026-11-25 | Phase 0 built: nuScenes-mini + Occ3D mini labels → replay files → Three.js renderer | Implemented |
| D-010 | 2026-11-25 | OmniRe on the RTX 5070 Ti: WSL2 Ubuntu 22.04 + CUDA 12.8 + torch 2.7.1, no SMPL first | Implemented |

## D-001: rebuild Tesla's 2021–22 explicit pipeline first
- **Decision:** cameras → top-down vector space + occupancy + lanes → render, the stack Tesla described at AI Day 2021/22 and CVPR 2022.
- **Why:** it is the only Tesla architecture that is public, and Karpathy said the display renders the vector space.
- **Rejected:** cloning v12+ end-to-end (architecture undisclosed, needs fleet-scale data); starting with the world simulator (undisclosed, and open equivalents need more than 24 GB).
- **Evidence:** research/01. **Decided by:** Claude (research agent). **Status:** Proposed.

## D-002: data is nuScenes-mini + Occ3D-nuScenes mini
- **Decision:** start on nuScenes `v1.0-mini` (4.2 GB, measured by HTTP HEAD) plus Occ3D-nuScenes mini labels (~440 MB, 404 frames).
- **Why:** every model with usable weights is trained on nuScenes; both downloads fit a laptop.
- **Rejected:** Waymo (no small subset; terms ban using trained models in vehicles); Argoverse 2 (~1 TB); comma2k19 (no lane or agent labels).
- **Note:** nuScenes is CC BY-NC-SA 4.0, non-commercial. Fine for learning.
- **Evidence:** research/02, research/03. **Decided by:** Claude (research agents). **Status:** Proposed.

## D-003: renderer is Three.js (WebGL) in the browser; Rerun for debugging
- **Decision:** a Three.js page with `WebGLRenderer`, fed by Python (replay file or WebSocket). Rerun runs alongside as the ground-truth/debug viewer.
- **Why:** runs on Mac and Windows unchanged; official examples exist for instancing, marching cubes, 3D textures, fat lines and splines; Apollo's open AV viewer uses the same stack; the browser can interpolate at 60 fps, which Rerun and Foxglove cannot.
- **Rejected:** Godot (strong v1 option, and Tesla reportedly uses it, but it adds a second language and an editor); Viser (runner-up; every update must come from Python); Unity (licence, weight); Bevy (Rust, API churn); raylib (DIY 3D); Foxglove (closed source since 2024); Three.js `WebGPURenderer` (its manual calls it experimental).
- **Evidence:** research/05. **Decided by:** Claude (research agent). **Status:** Proposed.

## D-004: build the renderer first, on ground-truth replay
- **Decision:** phase 0 plays nuScenes ground truth (devkit box interpolation at 12 Hz, Occ3D occupancy at 2 Hz keyframes) through the renderer before any model runs.
- **Why:** it works on the Mac today, needs no GPU, and keeps rendering bugs separate from model errors.
- **Rejected:** starting with a live model.
- **Evidence:** research/05. **Decided by:** Claude (research agent). **Status:** Proposed.

## D-005: one interface between perception and rendering
- **Decision:** perception writes per-frame `frame.json` = `{t, ego_pose, occ, boxes[track_id], lanes, path}`; the renderer draws one frame behind and interpolates to 60 fps.
- **Why:** lets ground truth, offline 4090 results and live Mac inference all drive the same renderer; perception is 12 Hz, the display is 60.
- **Rejected:** coupling the renderer to one model's raw outputs.
- **Evidence:** research/05. **Decided by:** Claude. **Status:** Proposed.

## D-006: perception is SparseDrive-S + FlashOcc M0, offline on the 4090
- **Decision:** SparseDrive-S gives tracked boxes, vector lanes and road edges, agent forecasts and the ego plan (9.0 FPS on a 4090, per its paper); FlashOcc M0 gives the occupancy grid (197.6 FPS TensorRT FP16 on a 3090, per its README).
- **Why:** together they cover everything the FSD display draws, both have durable weights, and both licences are permissive (MIT, Apache-2.0).
- **Rejected:** UniAD (1.8 FPS on an A100, raster map); BEVFormer / TPVFormer / SurroundOcc (2.4–15.9 FPS, deformable attention); VAD-Tiny (faster but no track IDs, kept as a speed fallback).
- **Risk:** the pinned training stacks predate CUDA 11.8, so they may need rebuilding for the 4090.
- **Evidence:** research/02, research/03. **Decided by:** Claude (research agents, conflict resolved in research/README). **Status:** Proposed.

## D-007: Mac runtime is ONNX Runtime + CoreML, starting with FlashOcc and SparseDrive-S
- **Decision:** export to ONNX on the CUDA box, replacing `bev_pool_v2` with a gather and using the `use_deformable_func=False` → `grid_sample` fallback that SparseDrive and Sparse4D both have (checked in SparseDrive's `blocks.py`); try SparseDrive-S first, keep Sparse4D v3 in reserve; run ONNX Runtime with the CoreML EP on Mac and the CUDA EP on Windows. Smoke-test with the existing SparseBEV CoreML fork first.
- **Why:** one model file for both platforms; FlashOcc's post-lift network is only 2D convolutions.
- **Rejected:** MLX (no Windows, means re-implementing the model); TensorRT (NVIDIA only); DirectML (maintenance mode); raw Core ML (Mac only).
- **Risk:** no published Mac latency exists for any BEV model; `microsoft/onnxruntime` is currently 404 on GitHub (PyPI still has 1.32.0).
- **Evidence:** research/02, research/05. **Decided by:** Claude (research agents). **Status:** Proposed.

## D-008: world-simulation track is OmniRe → OccWorld → Epona
- **Decision:** OmniRe (drivestudio) per-scene reconstruction on the 4090, viewed on the Mac in Spark or Brush; then OccWorld (trains on one 24 GB 4090); then Epona inference for video generation. DGGT / ReconDrive inference to try feed-forward splats.
- **Why:** these are the parts of the world-simulator idea that fit one 24 GB GPU and have code, weights and permissive licences.
- **Rejected:** Cosmos 2.5/3, OmniDreams, Vista (need more than 24 GB); GAIA (closed); STORM (no checkpoint, non-commercial); EmerNeRF (slow, stale); DrivingGaussian (code behind a form).
- **Gotcha:** drivestudio's PLY export writes only points and colours, so a full 3DGS exporter is needed before any splat viewer can show the scene.
- **Evidence:** research/04. **Decided by:** Claude (research agent). **Status:** Proposed.

## D-009: phase 0 built on nuScenes-mini + Occ3D mini labels
- **Decision:** `pipeline/nuscenes_to_frames.py` turns nuScenes `v1.0-mini` ground truth, the map expansion (v1.3) and
  Occ3D-nuScenes labels into one replay file per scene (`pipeline/frame_schema.md`); `renderer/` plays them in
  Three.js r170 (jsDelivr import map, no build step) served by `python -m http.server`.
- **Occ3D source:** the official Google Drive folders (project page and the CVPR 2023 challenge "mini" folder) answered
  "Quota exceeded" to anonymous downloads on 2026-11-25. The labels came from the Hugging Face mirror
  `RoyYao233/occ3d-nuscenes-transfer` (`gts.tar.gz`, 2,737,816,708 bytes, trainval); only the 10 mini scenes were
  extracted. Cross-checks: 404 frames, matching the official mini count; Occ3D car voxels fall 100% inside nuScenes
  car boxes in all 10 scenes.
- **Measured:** the grid is in the ego frame of the LIDAR_TOP keyframe with index (i, j, k) → (x, y, z), confirmed by
  the car-box check (swapped axes give 0.3–9.1%). Occupied voxels are 1.3–7.1% of the 200×200×16 grid per scene
  (8k–46k), which answers research/05 open question 4: instanced cubes are enough.
- **Occupancy display:** static classes (others, manmade, vegetation) are re-voxelised into one world-aligned 0.4 m
  grid, because each 2 Hz keyframe's grid sits in a different ego frame and drawing them in turn makes the world jump
  by up to half a voxel every 0.5 s. Moving things come from the 12 Hz boxes, not from voxels. The default look is a
  smooth surface: outward cell faces with shared corners, then Taubin smoothing (no scalar field needed, and
  triangles stay ordered by when the car first saw them). Raw cubes remain a menu option.
- **Rejected:** the Argoverse 2 interim plan (proposed while there was no nuScenes account; it has no occupancy labels).
- **Decided by:** user (asked to build phase 0); details by Claude. **Status:** Implemented.

## D-010: OmniRe runs on the RTX 5070 Ti through WSL2, without SMPL at first
- **Decision:** reconstruct scenes with drivestudio's OmniRe (the user's choice of route) on this PC. Setup
  (`recon/README.md`, `recon/setup_wsl.sh`):
  - WSL2 Ubuntu 22.04 with CUDA toolkit 12.8 and torch 2.7.1 + cu128;
  - gsplat 1.3.0, pytorch3d 0.7.8 and nvdiffrast rebuilt for sm_120 (`TORCH_CUDA_ARCH_LIST=12.0`);
  - drivestudio at commit e59bda4f with no source changes.
- **Why:**
  - drivestudio pins torch 2.0 + CUDA 11.7, which has no Blackwell (sm_120) kernels.
  - Its three compiled dependencies build reliably only on Linux.
  - Windows' CUDA 13.1 would mismatch a cu128 torch.
- **Departures from upstream:**
  - **Sky masks** come from `recon/extract_sky_masks.py` (Hugging Face SegFormer-B5 Cityscapes), because the
    upstream tool needs mmcv + torch 1.8.
  - **No SMPL pedestrians yet:** `recon/configs/omnire_nuscenes_nosmpl.yaml` drops `SMPLNodes`, so pedestrians
    become deformable Gaussians. SMPL needs the user's registration at smpl.is.tue.mpg.de.
  - **Requirements:** xformers dropped (never imported); chumpy installed without build isolation; opencv < 4.12;
    nuscenes-devkit 1.1.11 (1.2.0 needs matplotlib ≥ 3.6); setuptools < 70 (torchmetrics 0.10.3 imports
    `pkg_resources`).
- **Measured** (scene-0061, 6 cameras at 1/3 resolution, 2,000 steps):
  - 0.081 s/step;
  - peak PyTorch memory 3.11 GB allocated, 9.61 GB reserved;
  - whole-GPU peak 13.1 GB, including ≈3 GB used by other programs;
  - train PSNR ≈20 dB;
  - renders already resemble all 6 cameras.
  The 16 GB verdict is pending a full 30k-step run, because splats densify until step 20,000.
- **Rejected:**
  - native Windows builds (pytorch3d, CUDA version mismatch);
  - a rented 24 GB RTX 4090 for now;
  - drivestudio's mmcv sky-mask tool.
- **Decided by:** user (OmniRe route, hardware first); setup by Claude. **Status:** Implemented.
