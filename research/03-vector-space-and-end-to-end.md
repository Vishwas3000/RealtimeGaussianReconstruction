# 03 — Vector space & end-to-end driving models (what an FSD-style display draws)

Research date **2026-11-24**. Light web research only: no dataset, weights or model was downloaded or run.
Trust tags: **[P]** primary (read at source: README/code/arXiv API/GitHub API/HF API), **[S]** secondary
(search snippet or third-party write-up), **[U]** UNCERTAIN (could not confirm). Stars, pushes and licences
are as of 2026-11-24 (they rot). Every arXiv ID below was checked against the arXiv API or abs page (title matched).

## TL;DR

- **The richest open "FSD display" model with weights is SparseDrive** (2405.19620, MIT, stage-2 ckpt on GitHub
  Releases): from 6 cameras it outputs 3D boxes + track IDs + vector map polylines + multi-modal agent forecasts +
  ego plan, at 9.0 FPS on one RTX 4090 [P paper]. MomAD and DiffusionDrive-`nusc` are drop-in planner upgrades on
  the same codebase, both with weights [P].
- **None of the nuScenes vector-space models run on the Mac.** All need mmcv/mmdet3d + custom CUDA ops (e.g.
  SparseDrive's `deformable_aggregation`) [P]. Plan: infer on the 4090 box, dump per-frame JSON, render on the Mac.
- **openpilot is the only shipping stack whose model runs natively on macOS**: `modeld` loads its tinygrad-compiled
  model on `METAL` when `sys.platform == 'darwin'` [P code]. It outputs a 33-point/10 s plan, 4 lane lines, 2 road
  edges and lead cars, and its UI (raylib since 0.10.1) draws them as a **2D overlay on the camera image**, not a 3D
  scene [P code]. It is a good live single-camera baseline, but it is not surround-view.
- **"Lanes as language" is real research, but the weights are thin.** RoadNetTransformer/LaneGraph2Seq never published
  trained checkpoints (issue open since 2024-04) [P]. TopoGPT (2606.31814, Apache-2.0, ckpts on HF) and SeqGrowGraph
  (ckpt on ModelScope, **no licence**) are the 2025–26 autoregressive lane-graph options [P]. TopoNet/LaneSegNet
  (Apache-2.0, HF ckpts) are the stable non-autoregressive ones.
- **VLAs give you a path plus text, not lanes or agents.** Alpamayo-R1/1.5 (10B, OpenMDW-1.1) needs ≥24 GB VRAM [P].
  ORION, SimLingo, AutoVLA and OpenDriveVLA are CARLA- or nuScenes-bound. Useful as a "planned path + reasoning
  caption" layer at most.

## Main table

Outputs: **L** lanes/map polylines (raster = dense BEV seg), **T** lane topology graph, **A** agents (boxes/tracks),
**M** agent motion forecasts, **P** ego plan. FPS is as reported by the authors, with the GPU they named.

| Method | arXiv | Venue | Code (licence) | ★ / last push | Weights? | Outputs | Reported FPS (GPU) | Why it matters |
|---|---|---|---|---|---|---|---|---|
| HDMapNet | 2107.06307 | ICRA'22 [S] | Tsinghua-MARS-Lab/HDMapNet (GPL-3.0) | 769 / 2022-12 | none linked in README [P] | L (raster→vector post-proc) | not reported | Origin of online map + its eval protocol |
| VectorMapNet | 2206.08920 | ICML'23 [S] | Mrmoore98/VectorMapNet_code (GPL-3.0) | 449 / 2023-10 | GDrive [P] | L (autoregressive polyline decoder) | not reported | First vector map net; autoregressive vertices |
| MapTR / MapTRv2 | 2208.14437 / 2308.05736 | ICLR'23 / IJCV [S] | hustvl/MapTR (MIT), v2 on `maptrv2` branch | 1567 / 2025-03 | GDrive, many configs [P] | L (+centerline variant in v2) | nano 25.1 [P abstract] / 35.0 [P README table], tiny 15.1, v2-R50 14.1 (all RTX 3090) | The baseline every map paper builds on |
| StreamMapNet | 2308.12570 | WACV'24 [S] | yuantianyuan01/StreamMapNet (GPL-3.0) | 274 / 2024-03 | GDrive [P] | L, temporal streaming | 14.2 [P abstract], GPU not checked | Streaming memory gives stable maps over time |
| MapTracker | 2403.15951 | ECCV'24 [S] | woodfrog/maptracker (**non-commercial + GPLv3**) | 264 / 2025-10 | Dropbox/HF [P] | L tracked with IDs over time | not reported | Best for display stability; consistency-aware metric |
| MapQR | 2402.17430 | ECCV'24 [S] | HXMap/MapQR (MIT) | 230 / 2025-05 | SharePoint [P] | L | not reported | Strong single-frame MapTRv2 successor |
| Uni-PrevPredMap | 2504.06647 (v4) | arXiv, rev. 2026-01 | pnnnnnnn/Uni-PrevPredMap (MIT) | 19 / 2026-09 | GDrive [P] | L; can use HD-map priors | not reported | 74.0 mAP nuScenes per released ckpt [P README] |
| TopoNet | 2304.05277 | arXiv'23 [U venue] | OpenDriveLab/TopoNet (Apache-2.0) | 341 / 2025-07 | HF (OLv2 subset A, B) [P] | L(centerlines)+T, traffic elements | not reported | Reference lane-graph model on OpenLane-V2 |
| TopoMLP | 2310.06753 | ICLR'24 [S] | wudongming97/TopoMLP (Apache-2.0) | 219 / 2026-07 | some backbones linked [P] | L+T | not reported | Simple strong topology baseline |
| LaneSegNet | 2312.16108 | ICLR'24 [S] | OpenDriveLab/LaneSegNet (Apache-2.0) | 385 / 2026-02 | HF [P] | lane *segments* (both edges + centerline) + T | not reported | Closest to FSD's drawable lane ribbons |
| RoadNetTransformer (RNTR) | 2402.08207 | ICCV'23 oral [P README] | LogosIntelligenceLab/RoadNet (MIT; old fudan-zvg URLs redirect) | 94 / 2026-10 | **no trained ckpt** [P] | T as a token sequence (AR + non-AR) | not reported | Literal "road network as language" |
| LaneGraph2Seq | 2401.17609 | AAAI'24 [P README] | same repo | — | **no trained ckpt** [P] | T as vertex-edge token sequence | not reported | LM-style lane topology |
| SeqGrowGraph | 2507.04822 | 2025 | MIV-XJTU/SeqGrowGraph (**no licence**) | 133 / 2025-11 | ModelScope [P] | T grown autoregressively (nuScenes centerlines) | not reported | Newest AR lane graph with a ckpt |
| TopoGPT | 2606.31814 | arXiv 2026 | buaa-colalab/TopoGPT (Apache-2.0) | 72 / 2026-08 | HF `MatrixF/VectorMapPrior` ckpts [P] | T autoregressive, uses a vector-map prior | not reported | 2026 AR topology on OpenLane-V2 |
| UniAD | 2212.10156 | CVPR'23 [S] | OpenDriveLab/UniAD (Apache-2.0) | 4831 / 2025-10 | GitHub Releases [P] | A+tracks, L (**raster**, "IoU-lane"), M, occupancy, P | 1.8 (A100) [P VAD & SparseDrive papers] | The canonical full-stack model; too slow to be live |
| VAD | 2303.12077 | ICCV'23 [P] | hustvl/VAD (Apache-2.0) | 1396 / 2026-01 | GDrive [P] | L (vector), A, M, P | Tiny 16.8, Base 4.5 (RTX 3090) [P paper] | Fastest fully vectorized stack with weights |
| VADv2 | 2402.13243 | ICLR'26 [P README] | config + head only in hustvl/VAD/VADv2 | — | **none** [P] | P (probabilistic over a 4096-trajectory vocabulary) | not reported | Idea only; cannot run |
| **SparseDrive** | 2405.19620 | 2024 [U venue] | swc-17/SparseDrive (MIT) | 1031 / 2026-09 | **GitHub Releases** stage1+2 [P] | **A+track IDs, L (vector), M (multi-modal), P** | S 9.0, B 7.3 (RTX 4090) [P paper] | Best outputs-per-FPS with durable weights |
| MomAD | 2503.03125 | CVPR'25 [S] | adept-thu/MomAD (MIT) | 452 / 2026-06 | HF (nuScenes 3 s / 6 s) [P] | same as SparseDrive + temporally consistent P | 7.8 (RTX 4090) [P README] | Less plan jitter, which matters on a display |
| DiffusionDrive | 2411.15139 | CVPR'25 [P] | hustvl/DiffusionDrive (MIT; HF Apache-2.0) | 1539 / 2025-12 | HF [P] | `nusc` branch = SparseDrive + diffusion P; NAVSIM branch = cam+**LiDAR** → BEV raster, A, P | 45 (RTX 4090, NAVSIM) [P abstract] | Multi-modal plans in real time |
| DiffusionDriveV2 / SparseDriveV2 | 2512.07745 / 2603.29163 | arXiv 2025 / 2026 | hustvl/DiffusionDriveV2 (MIT), swc-17/SparseDriveV2 (Apache-2.0) | 389 / 277 | HF [P] | NAVSIM planners (P-centric) | not reported | NAVSIM v1 PDMS 92.22 (SDv2) [P README]; not display-rich |
| GenAD | 2402.11502 | ECCV'24 [S] | wzzheng/GenAD (Apache-2.0) | 499 / 2025-05 | GDrive [P] | A, L, M, P (generative) | not checked | Alternative to VAD |
| DriveTransformer | 2503.07656 | ICLR'25 [P B2D README] | Thinklab-SJTU/DriveTransformer (**no licence**) | 249 / 2026-03 | GDrive [P] | A, L, M, P in CARLA | 211.7 ms latency, GPU unstated [P] | Bench2Drive SOTA-class, licence trap |
| OpenDriveVLA | 2503.23463 | AAAI'26 [S] | DriveVLA/OpenDriveVLA (Apache-2.0) | 836 / 2026-02 | HF 0.5B (gated: auto) [P] | P as text; exposes lanes/agents? [U] | not reported | Smallest VLA with nuScenes weights |
| ORION | 2503.19755 | 2025 [U] | xiaomi-mlab/Orion (Apache-2.0) | 674 / 2026-06 | released (CARLA) [P] | P + reasoning | needs ≥17 GB fp16 [P] | Bench2Drive-only |
| SimLingo | 2503.09594 | CVPR'25 [S] | RenzKa/simlingo (Apache-2.0) | 480 / 2025-08 | HF [P] | P + language (CARLA) | not reported | Closed-loop VLA, CARLA only |
| AutoVLA | 2506.13757 | NeurIPS'25 [S] | ucla-mobility/AutoVLA (**"Academic Software License"**) | 681 / 2026-05 | HF since 2026-05 [P] | P + CoT | not reported | Qwen2.5-VL based |
| Alpamayo-R1 → 1.5 | 2511.00088 | arXiv 2025 | NVlabs/alpamayo (Apache-2.0 code) | 2073 / 2026-09 | HF, weights OpenMDW-1.1, ~22 GB [P] | P + reasoning text only | 99 ms on-vehicle, HW unstated [P abstract]; ≥24 GB VRAM [P] | Biggest open driving VLA; no lanes/agents |

Tesla "lanes as language" (AI Day 2022): lane graph decoded like image captioning. The tokens are 3D lane positions
plus connectivity modifiers, and the decoder is transformer-LM inspired [S: analyticsindiamag.com, kevinchen.co write-ups].
No primary Tesla source was read. RNTR, LaneGraph2Seq, SeqGrowGraph and TopoGPT are the open analogues.

## openpilot (comma.ai), as of 2026-11-24

- Repo `commaai/openpilot`: MIT, 64,220★, pushed 2026-11-24. Latest release **v0.11.2 (2026-10-23)** [P]. The code
  now lives under `openpilot/selfdrive/...` (the old `selfdrive/` root paths 404) [P].
- **Model files:** `driving_supercombo.onnx` (GitHub reports ~69.7 MB; tracked by LFS via `*.onnx`) is compiled by
  tinygrad into `driving_tinygrad.pkl` [P SConscript]. A separate `big_driving_*` model is used when an external USB
  AMD GPU ("chestnut") is present. It is only built for releases [P helpers.py].
- **Inputs** [P modeld.py/model.py]: two camera streams, narrow road `img` and wide `big_img`, warped on-device into a
  calibrated 512×256 YUV "medmodel" frame. Also a desire pulse (8-way: lane change, etc.), traffic convention
  (LHD/RHD), `action_t`, and recurrent state tensors fed back each step. Runs at 20 Hz. The exact tensor shapes are in
  the compiled pkl; inspect the ONNX in netron to confirm [U].
- **Outputs** [P constants.py/parse_model_outputs.py]:
  - plan: 33 points on a quadratic time grid up to 10 s, covering position, velocity, acceleration, euler angles and
    rotation rate, with mixture-of-hypotheses (5)
  - 4 lane lines + probabilities, and 2 road edges + stds, on an x-grid up to 192 m
  - leads: 6 time steps with probabilities
  - pose, road transform, desire prediction, and meta (disengage/brake probabilities over 2–10 s)
  - `action`: desired curvature + acceleration
- **UI**: rewritten from Qt/Weston to Python + **raylib** in 0.10.1 (Oct 2025) [S blog.comma.ai/0101release; P code
  imports `raylib_nb`]. `selfdrive/ui/onroad/model_renderer.py` draws the path (gradient), 4 lane lines (alpha by
  probability), 2 road edges and lead chevrons. The lead chevrons come from `radarState` (radar + model fusion), not
  straight from the model. All of it is projected onto the camera image ("augmented road view"), so it is a 2D AR
  overlay, not a 3D world [P]. A second UI tree, `ui/mici/`, also exists, apparently for a different device [U].
- **Runs on your machines**: "Most of openpilot should work natively on macOS. On Windows, you can use WSL" [P
  tools/README]. Use `tools/replay/replay --demo` to replay a public demo route, and `tools/sim` to bridge to
  **MetaDrive** (Apache-2.0) [P]. This is the fastest way to see a real driving model drive a UI on the Mac.
- **Datasets** (all MIT on GitHub and HF [P]):
  - comma2k19: 33 h of highway, ~100 GB torrent, poses + CAN. Example code tested only on py2.7/3.6.
  - commaVQ: 100k min of VQ-VAE tokens (128 tokens/frame, 20 FPS) + poses, plus a GPT world model
    `commaai/commavq-gpt2m` trained on 3M min.
  - comma10k: 10k crowd-labelled segmentation PNGs.
  - depth10k.
- **Learning value**: commaVQ is for world-model and compression study, not perception labels. comma2k19 has poses
  (ego path) but no lane or agent labels [P README]. To learn openpilot's lane/path outputs, distil from the shipped
  model on comma2k19 video [U: not tried].

## Datasets / simulators

| Name | Size | Licence | Laptop-friendly subset | Notes |
|---|---|---|---|---|
| nuScenes | full ~400 GB, keyframes ~60 GB [S FIERY doc] | data **CC BY-NC-SA 4.0** [S paper/py123d]; devkit Apache-2.0 [P] | `v1.0-mini`, 10 scenes [P devkit]; size not verified [U] | Gated signup; the default for every model above |
| Argoverse 2 (sensor) | 1,000 scenarios; "several TB" class [S] | **CC BY-NC-SA 4.0** [S paper]; av2-api MIT [P] | none found [U] | 7 ring cams; MapTR/StreamMapNet/MapTracker AV2 ckpts |
| OpenLane-V2 | built on AV2 + nuScenes | **CC BY-NC-SA 4.0**, code Apache-2.0 [P] | subset-B (nuScenes-based [S]) | Topology benchmark; accept nuScenes + AV2 terms [P] |
| NAVSIM (v1/v2) | navtrain sensors 445 GB, navtest 223 GB, mini 151 GB [P docs/splits.md] | code Apache-2.0; data inherits nuPlan/OpenScene [P] | `warmup_two_stage` 1.2 GB [P] | Non-reactive "pseudo-sim" (2506.04218) |
| Bench2Drive | Mini 4 GB, Base 400 GB, Full 4 TB [P] | **CC-BY-NC-ND** (no derivatives) [P] | Mini 10 clips; Dev10 routes [P] | Closed loop on CARLA 0.9.15 |
| CARLA | — | MIT [P] | — | Ubuntu 22/24 or Windows 11 only, **no macOS** [P]; v1.0 released 2026-11-17 (UE5) [P] |
| MetaDrive | — | Apache-2.0 [P] | — | openpilot's sim bridge target |

## Recommended stack (richest FSD-like outputs with pretrained weights)

1. **Main surround-view model: SparseDrive-S (nuScenes)**
   - **Why:** one forward pass yields everything an FSD display draws: tracked 3D boxes, vector lane dividers,
     crossings and road boundaries, per-agent futures and the ego plan. It runs 9.0 FPS on a 4090 [P], and its
     weights sit on GitHub Releases (durable), not GDrive.
   - **Rejected:**
     - UniAD: 1.8 FPS on A100, and its map is raster.
     - VAD-Tiny: faster (16.8 FPS, 3090), but no track IDs and weaker metrics. Keep it as a speed fallback.
     - Alpamayo: path only, ≥24 GB.
2. **Planner upgrade: MomAD on the SparseDrive codebase**
   - **Why:** temporally consistent plans mean less jitter on screen, at 7.8 FPS on a 4090 [P]. HF weights, MIT.
   - **Rejected:** DiffusionDrive-`nusc`. It gives multi-modal plans with HF weights, but stability matters more for
     a display. Revisit if you want to show multiple candidate paths.
3. **Runtime split: infer offline on the 4090, render on Mac/Windows from JSON**
   - **Why:** mmcv/mmdet3d + custom CUDA ops make these models CUDA-only [P install docs]. The renderer then stays
     cross-platform.
   - **Rejected:** porting to MPS/ONNX first. Community ONNX/TensorRT ports of SparseDriveV2 exist but are unvetted
     (`Wanglaoban3/SparseDriveV2-Quantization-Onnx-Deploy`, 5★) [P names only].
4. **Live on-Mac baseline: openpilot `modeld` + `replay --demo`**
   - **Why:** it is the only verified model that runs on Apple GPUs (tinygrad METAL) [P]. It gives real lanes, road
     edges and a path at 20 Hz, so you can build the renderer before the CUDA pipeline exists.
   - **Rejected:** a nuScenes model live on the Mac (not feasible); CARLA (no macOS).
5. **Lane topology / "lanes as language"**
   - **Why:** start with TopoNet or LaneSegNet (Apache-2.0, HF ckpts, OpenLane-V2 subset-B reuses nuScenes) for
     drawable lane graphs. Then study TopoGPT (Apache-2.0, ckpts) for the autoregressive version.
   - **Rejected:** RNTR/LaneGraph2Seq (no ckpts, ~4-day training per README [P]); SeqGrowGraph (no licence).
6. **Stability layer for the map (optional): MapTracker or StreamMapNet**
   - **Why:** tracked map elements stop lanes flickering.
   - **Rejected:** treating MapTracker as anything beyond learning, because of its non-commercial licence.
     MapTRv2 (MIT) is the clean baseline.

## Dead ends (record, do not retry blindly)

- **VADv2**: no weights. Only `VADv2_config_voca4096.py` + `VADv2_head.py` in hustvl/VAD [P].
- **RNTR / LaneGraph2Seq**: the README announces "availability of trained checkpoints" (2024-04), but none are linked.
  Issue #7 ("Trained checkpoints") has been open since 2024-04-10, and users report bad self-trained results [P].
- **SparseMeXt** (2505.08808): `PeterJaq/SparseMeXT` contains only a LICENSE file [P]. No code found for
  **PredMapNet, HisTrackMap or Topo2Seq** (GitHub search) [P negative search; they may live elsewhere, U].
- **No-licence / restrictive repos**:
  - DriveTransformer, SeqGrowGraph, UniTopo: no licence file, so all rights reserved [P].
  - MapTracker: non-commercial on top of GPLv3 [P].
  - Bench2Drive: CC-BY-NC-ND [P].
  - AutoVLA: "Academic Software License" [P badge].
- **DiffusionDrive NAVSIM branch**: needs **LiDAR** input and outputs a BEV raster + 2D agent boxes, not vector lanes
  [P code]. Use the `nusc` branch instead.
- **Alpamayo**: ≥24 GB VRAM and outputs trajectory + reasoning only, so it cannot run on a 16 GB Mac [P].
- **HDMapNet**: no checkpoint link, raster output, GPL [P].
- **comma2k19 sample code**: tested only on Python 2.7/3.6 [P].

## Open questions

- Does SparseDrive's nuScenes converter accept `v1.0-mini`, so inference demos avoid the full ~400 GB? [U]
- What are the exact openpilot supercombo input/output tensor shapes, and how are frames stacked? (open the ONNX in netron) [U]
- Can SparseDrive/MomAD be exported to ONNX → CoreML to run on the Mac (custom deformable op)? [U]
- Does OpenDriveVLA-0.5B expose its intermediate 3D agent/map predictions, or only the trajectory text? [U]
- Exact sizes of nuScenes mini and the AV2 sensor dataset, and the full nuScenes Terms of Use (not read). [U]
- Licence of NVIDIA's `PhysicalAI-Autonomous-Vehicles` dataset (referenced by Alpamayo; not checked). [U]
- GPU behind StreamMapNet's 14.2 FPS. Venues marked [S]/[U] were not checked against proceedings.
