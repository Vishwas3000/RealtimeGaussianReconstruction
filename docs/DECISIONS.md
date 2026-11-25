# Decision log

Every project decision, with its reason and what was rejected. Entries are never deleted, only marked Superseded.
**Proposed** = suggested by Claude or a research agent, not yet confirmed by the user. Evidence lives in
[`research/`](../research/README.md).

| ID | Date | Decision | Status |
|---|---|---|---|
| D-001 | 2026-11-24 | Rebuild Tesla's 2021–22 explicit pipeline first | Proposed · parked by D-009 |
| D-002 | 2026-11-24 | Data: nuScenes-mini + Occ3D-nuScenes mini | Proposed (CAM_FRONT only under D-009) |
| D-003 | 2026-11-24 | Renderer: Three.js (WebGL) in the browser; Rerun for debugging | Proposed · parked by D-009 |
| D-004 | 2026-11-24 | Build the renderer first on ground-truth replay | Proposed · parked by D-009 |
| D-005 | 2026-11-24 | One interface: per-frame `frame.json`, renderer interpolates at 60 fps | Proposed · parked by D-009 |
| D-006 | 2026-11-24 | Perception: SparseDrive-S + FlashOcc M0, offline on the 4090 | Proposed · parked by D-009 |
| D-007 | 2026-11-24 | Mac runtime: ONNX Runtime + CoreML, FlashOcc + SparseDrive-S first | Proposed · parked by D-009 |
| D-008 | 2026-11-24 | World-sim track: OmniRe → OccWorld → Epona | Proposed (OmniRe on one camera under D-009) |
| D-009 | 2026-11-25 | Focus on one front camera (monocular reconstruction) for now | **Accepted** |
| D-010 | 2026-11-25 | Monocular path M1 → M4, removing one crutch per step | Proposed |
| D-011 | 2026-11-25 | Own capture: custom iPhone app with ARKit inside (main lens + poses), LiDAR off | **Accepted** |
| D-012 | 2026-11-25 | Add a multi-lens capture mode (no ARKit); poses in post-processing from IMU + GPS; keep ARKit mode as the reference | **Accepted** |

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

## D-009: focus on one front camera (monocular reconstruction) for now
- **Decision:** reconstruct the scene from a single forward-facing camera. Surround-camera work waits.
- **Why:** the owner's call (2026-11-25): "for now can we focus on single camera. so we just reconstruct the scene using
  monocular camera." It also brings other benefits:
  - about 6× less data and compute than nuScenes' six cameras [inference];
  - it matches a single phone or dashcam on Indian roads (research/market);
  - it matches all four papers the owner sent (research/papers).
- **What it changes:**
  - Reconstruction (D-008's first step) comes first, on one camera. That answers the open "FSD screen or world simulator
    first?" question for now.
  - D-001 and D-003–D-007, the FSD-display track built on surround cameras, are parked.
  - D-002's nuScenes-mini still applies, using CAM_FRONT only.
- **Costs to expect** [inference]:
  - one camera gives no metric scale on its own;
  - views a lane to the side of the driven path will show holes and smears;
  - a moving car's depth is ambiguous;
  - nothing behind or beside the car is ever seen.
- **Decided by:** the owner. **Status:** Accepted.

## D-010: monocular path M1 → M4, removing one crutch per step
- **Decision:**
  - **M1, baseline, no new code.** drivestudio's OmniRe and Street Gaussians with
    `configs/datasets/nuscenes/1cams.yaml`: CAM_FRONT only, with the dataset's poses, LiDAR and 3D boxes, on one
    nuScenes-mini scene, on the rented 4090. Run `3cams.yaml` on the same scene to measure what one camera loses.
  - **M2, camera only.**
    - Set `load_lidar: False` and seed the Gaussians from monocular depth instead (Instant4D: back-project, voxel-prune,
      short schedule, no densification).
    - Then set `load_objects: False` and find the movers from the video (RiGS's per-object decision, scored by 3D motion
      after removing ego-motion).
  - **M3, the owner's own video.** A phone or dashcam clip of an Indian road. Poses come from a monocular SLAM front-end
    (MegaSaM or ViPE, as used by the papers in research/papers); metric scale comes from a metric depth model or the
    phone's GPS speed.
  - **M4, realtime.** Not surveyed yet. Candidates:
    - monocular feed-forward models: BTimer (20–150 ms for 4–12 frames at 256² on an A100, research/07) and T4GS (public
      weights, no timing);
    - streaming Gaussian SLAM.
- **Why:**
  - Each step removes exactly one crutch (LiDAR, boxes, dataset poses, per-scene optimisation), so every quality drop has
    one cause.
  - M1 needs only a config file. Checked 2026-11-25 through the GitHub API: drivestudio ships `1cams.yaml` for nuScenes,
    Argoverse 2, Waymo, KITTI, PandaSet and nuPlan; camera 0 is the front camera in the nuScenes and Argoverse 2 configs;
    `load_lidar` and `load_objects` are switches in the same file.
- **Rejected:**
  - Starting on own video: three unknowns at once, and no ground truth to score against.
  - Starting feed-forward: our notes have no monocular driving model with both a measured latency and public weights.
- **Data:**
  - nuScenes-mini needs the owner's free nuScenes account. drivestudio's config already points at `processed_10Hz/mini`.
  - Fallback without an account: one Argoverse 2 log (1.14 GB, research/12). drivestudio's instructions download the whole
    sensor set, so one log needs its scene list adjusted, and it needs drivestudio's Rust-based av2 API.
- **Correction (2026-11-25, later the same day):** `load_lidar: False` is not a usable switch.
  - drivestudio `datasets/driving_dataset.py` line 79 asserts that a LiDAR source exists, and `load_lidar: False`
    leaves it `None` (lines 159–160), so the run should stop (code read, not run).
  - The maintainer (issue #96) says disabling LiDAR "will lead to overfitted Gaussians".
  - So M2 and M3 write metric depth, back-projected with the camera pose, into the LiDAR slot ("pseudo-LiDAR")
    instead of switching LiDAR off. Evidence: research/capture/README.md.
- **Decided by:** Claude. **Status:** Proposed.

## D-011: own capture is a custom iPhone app with ARKit inside
- **Decision:** for M3, record with a fork of Stray Scanner (MIT), which records ARKit video, LiDAR depth, poses,
  intrinsics and IMU. Additions:
  - main lens at 4K30 or 1440p60;
  - focus, exposure and white balance locked; HDR off;
  - GPS and per-frame exposure logging.

  Leave iPhone LiDAR off except for one test. Validate with a 5-minute closed loop in the owner's car before the real
  drives. ViPE runs on the same frames as a check and fallback.
- **Why:**
  - ARKit's poses are the most valuable stream. In Kim et al. 2022, ARKit had 2.68 m end-point error on a 3,051.61 m
    road loop, against ARCore 140.08 m (one run, iPhone 12 Pro Max).
  - ARKit cannot run any other lens (Apple staff, 2022, 2024 and 2026).
  - The extra lenses and LiDAR add little on roads. LiDAR: "up to 5 meters". Main + ultra-wide stereo: ~1.4 px disparity
    at 20 m. Telephoto: ~16° view.
- **Rejected:** a custom AVFoundation multi-camera app (LiDAR camera + ultra-wide + telephoto). It is possible according
  to Apple's WWDC22 talk, but it loses the poses, is limited to multi-camera formats, has no hardware sync between
  separate lenses, and runs into heat limits. Revisit after the one-camera M3 works, with a probe app first
  (research/capture/01 §9).
- **Evidence:** research/capture/. **Decided by:** Claude (research agents, spot-checked); approved by the owner on
  2026-11-25 ("yea you can start build this"). **Status:** Accepted.
- **Implementation:** `capture/`, RoadCapture, a fork of Stray Scanner at ec3e1dc, plus `capture/tools/check_capture.py`
  for the loop test. Builds and signs on the Mac; not yet run on a phone.

## D-012: add a multi-lens capture mode; keep ARKit mode as the reference
- **Decision:** add a second recording mode to RoadCapture, using AVFoundation's multi-camera session instead of ARKit:
  - the LiDAR camera (the main lens plus depth), the ultra-wide, and the telephoto if the phone allows all three;
  - motion sensors at full rate, GPS, and the factory lens calibration;
  - focus, exposure and white balance locked; stabilisation and distortion correction off.

  Poses are computed afterwards with visual-inertial odometry from the logged motion sensors, with GPS for scale. The
  ARKit mode stays, and the same route is driven once in each mode so the ARKit trajectory checks the offline poses.
  First step: a probe button that records which lens combinations, formats and heat costs the iPhone 15 Pro allows.
- **Why:**
  - The owner (2026-11-25): "i dont think arkit have a lot of weight for this goal… we can also do this in the post
    processing. but the multi lens will be of a lot of help."
  - Reconstruction is offline, so live poses aren't required.
  - The ultra-wide (120°) sees the roadside the main lens misses, and keeps features in view longer, which also helps
    offline poses.
- **Limits:**
  - Camera-only offline poses drift on forward driving video (9–25 m ATE on KITTI, research/capture/02). That is why the
    motion sensors and GPS must be logged.
  - Main + ultra-wide stereo is useless past about 10 m (lenses about 2 cm apart).
  - The telephoto and LiDAR add little on roads.
  - Separately added lenses are not hardware-synchronised (WWDC19).
  - Multi-camera formats are capped below full resolution.
  - Heat limits recordings to 10–15 minutes above a system-pressure cost of 1.
- **Rejected:** dropping the ARKit mode. It works today and gives the reference trajectory.
- **Evidence:** research/capture/01 §2 and §9, research/capture/02. **Decided by:** the owner's direction, with this
  shape proposed by Claude; the owner approved it on 2026-11-25 ("go head"). **Status:** Accepted.
- **Progress:** step 1, the camera probe (`capture/ios/StrayScanner/Helpers/CameraProbe.swift`), built and run on the
  iPhone 15 Pro on 2026-11-25.
