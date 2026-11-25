# TeslaRender

A learning project: rebuild the **Tesla FSD "world render"** with open papers, open code and open data.
Surround cameras go in, a neural network builds a 3D picture of the world (occupancy, cars, lanes, planned path),
and a realtime renderer draws it the way the FSD in-car display does. Research and learning only, not for vehicles.

- Research notes (every claim tagged with how far it can be trusted): [`research/`](research/README.md)
- Decision log (each choice, why, what was rejected, status): [`docs/DECISIONS.md`](docs/DECISIONS.md)
- Learning roadmap (what to understand, in what order, with hands-on builds): [`docs/LEARNING_ROADMAP.md`](docs/LEARNING_ROADMAP.md)
- Capture app for our own road video (iPhone: main camera + ARKit poses + GPS) and its checker: [`capture/`](capture/README.md)

## What Tesla actually does (short version)

Tesla has published architecture-level detail only for its 2021–2022 stack ([research/01](research/01-tesla-public-disclosures.md)):
8 cameras → RegNet + BiFPN → transformer into a top-down **"vector space"** → time/space feature queue →
heads for objects, lanes ("language of lanes") and a 3D **Occupancy Network**. Karpathy: the vector space is what the
in-car display renders. The display itself is reportedly a **Godot** app (a hacker's firmware teardown, not a Tesla
statement). FSD v12+ (end-to-end), the 2025 **neural world simulator** and "generative Gaussian splatting" are on the
record but have **no published architecture**.

So this project rebuilds the disclosed pipeline, then adds the world-simulation side from open research.

## The pipeline

```
 6 cameras (nuScenes, 12 Hz)
        │
        ▼
 perception ── runs on the RTX 4090 box first, later on the Mac via ONNX Runtime
   FlashOcc M0     → 200×200×16 occupancy grid              (Tesla's "Occupancy Network")
   SparseDrive-S   → tracked 3D boxes, vector lanes + road edges,
                     other agents' futures, ego plan        (Tesla's "vector space")
        │
        ▼
 frame.json  {t, ego_pose, occ, boxes[track_id], lanes, path}   ← the one interface between the halves
        │
        ▼
 renderer ── Three.js (WebGL) in the browser, Mac + Windows, 60 fps
   draws one perception frame behind and interpolates (perception is 12 Hz, the screen is 60)
   instanced voxels → smoothed grey "blobs", car meshes keyed by track ID,
   Catmull-Rom lane splines, path ribbon, damped chase camera
   Rerun runs alongside as the debug / ground-truth view
```

## Run phase 0 (ground-truth replay)

Data lives in `Dataset/` (git-ignored, non-commercial licences): nuScenes `v1.0-mini` and the map expansion (v1.3)
extracted into `Dataset/nuscenes/`, and the Occ3D-nuScenes labels for the 10 mini scenes in `Dataset/occ3d/gts/`
(source and checks: [D-009](docs/DECISIONS.md)).

```
python -m venv .venv
.venv/Scripts/python -m pip install -r pipeline/requirements.txt     # macOS: .venv/bin/python
.venv/Scripts/python pipeline/nuscenes_to_frames.py                  # writes renderer/public/data/*.json
.venv/Scripts/python -m http.server 8765 --bind 127.0.0.1 --directory renderer
```

Then open http://127.0.0.1:8765. The replay format is documented in [`pipeline/frame_schema.md`](pipeline/frame_schema.md).

## Roadmap (proposed, waiting on your go-ahead)

| Phase | Goal | Runs on | Done when | Needs from you |
|---|---|---|---|---|
| **0. Ground-truth replay renderer** | Build the FSD-style renderer before any model exists. nuScenes-mini + Occ3D-mini labels → `frame.json` → Three.js | Mac only, no model | a nuScenes scene plays at 60 fps with the FSD look | a free nuScenes account (non-commercial terms) to download mini (4.2 GB) + Occ3D mini (~440 MB) |
| **1. Real perception, offline** | SparseDrive-S + FlashOcc M0 on nuScenes-mini → same `frame.json` → same renderer, side by side with ground truth | RTX 4090 box | predicted and true worlds play together | the GPU box; expect to rebuild old torch/mmcv pins for the 4090 |
| **2. Live on the Mac** | Export FlashOcc to ONNX (swap the CUDA `bev_pool_v2` for a gather) and run ONNX Runtime + CoreML. Measure FPS: **no one has published a Mac number for any of these models** | Mac, one model at a time | a measured Mac FPS, live render | — |
| **3. Build your own Tesla-style net** | From scratch: lift-splat → BEV → temporal feature queue → occupancy head + lane head; then lanes-as-language (TopoNet / LaneSegNet → TopoGPT) | train on the 4090 | your net drives the same renderer | the GPU box |
| **4. Neural world rendering** | Tesla's world-simulator track: OmniRe reconstruction (~1 h/scene on a 4090) → Gaussian splats viewed on the Mac; DGGT / ReconDrive feed-forward splats; OccWorld (occupancy forecasting) feeding the same voxel renderer; Epona video "dreaming" | 4090 for training, Mac for viewing | a reconstructed scene you can fly through, and a forecast world playing in the renderer | the GPU box |

Phase 4 can start in parallel with 0–3 if the world-simulator side is what you care about most.

## Hard limits found during research

- Tesla's v12+ end-to-end net, its world simulator and its generative Gaussian splatting have no paper, code or patent.
- Every open realtime multi-camera generative simulator needs more than 24 GB of GPU memory (Cosmos 2.5/3, OmniDreams, Vista).
- All the big driving datasets (nuScenes, Waymo, Argoverse 2) are **non-commercial**; Waymo also bans using trained models in vehicles.
- The nuScenes perception models need CUDA-only custom ops; the Mac path depends on replacing them (phase 2).
