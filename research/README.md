# Research index

Researched 2026-11-24 by five parallel research agents, then reviewed and spot-checked. Light web research only:
nothing was downloaded, installed or run. Stars, licences and versions rot; each file dates them.

| File | Covers | Top pick |
|---|---|---|
| [01-tesla-public-disclosures.md](01-tesla-public-disclosures.md) | What Tesla said on stage, wrote, or patented (AI Day 2021/22, CVPR 2022/23, FSD v12–v14, ICCV 2025, patents); open equivalent for each part; how the in-car display is built | Build on the 2021–22 explicit pipeline, the only one disclosed |
| [02-bev-and-occupancy.md](02-bev-and-occupancy.md) | Camera → BEV and 3D occupancy models; datasets; custom ops that block the Mac | FlashOcc M0 (occupancy) + Sparse4D v3 (boxes with track IDs) |
| [03-vector-space-and-end-to-end.md](03-vector-space-and-end-to-end.md) | Online vector maps, lane topology ("lanes as language"), end-to-end planners, openpilot | SparseDrive-S: boxes + tracks + lanes + forecasts + plan in one pass |
| [04-neural-world-simulation.md](04-neural-world-simulation.md) | Driving-scene reconstruction (3DGS/NeRF), feed-forward splats, generative world models, Mac splat viewers | OmniRe via drivestudio on one 4090, then OccWorld, then Epona |
| [05-renderer-and-runtime.md](05-renderer-and-runtime.md) | Rendering techniques, engine comparison, open AV visualizers, inference runtimes and export pitfalls, nuScenes replay | Three.js renderer + Rerun debug view; inference offline on the 4090, then ONNX Runtime |
| [06-street-gaussians-explained.md](06-street-gaussians-explained.md) | Deep read of Street Gaussians: how many cameras become one splat world, how moving cars work, compute, limits | Learn static splats on the Mac (Brush), fit dynamic scenes on the 4090 (drivestudio) |
| [07-feedforward-recon-compute.md](07-feedforward-recon-compute.md) | Measured latency of 27 feed-forward splat models; how time grows with cameras and resolution | VGD: 6 cams in 0.26 s on an A100 is the closest anchor to Tesla's 220 ms |
| [08-splat-render-cost.md](08-splat-render-cost.md) | Measured splat drawing speed on GPUs, Jetson, phones, Apple silicon; Gaussian counts | Street Gaussians 7.4 ms per view on a 4090; M4 Max browser 10 M splats at 124 fps |
| [09-world-sim-realtime-compute.md](09-world-sim-realtime-compute.md) | Measured speed and hardware of real-time world models | OmniDreams-MV: 4 views × 48 fps on 4 GB300 |
| [10-hardware-specs.md](10-hardware-specs.md) | Dense FP32/FP16/INT8 and bandwidth for NVIDIA, Tesla and Apple chips; precision traps | Scale splat drawing by FP32 + bandwidth, networks by dense tensor FLOPS |
| [12-test-datasets.md](12-test-datasets.md) | Camera datasets to test with: access, size, licence, which roadmap stage | Argoverse 2 (one drive, 1.14 GB, no account) today; nuScenes-mini for the pretrained models |
| [13-models-beyond-omnire.md](13-models-beyond-omnire.md) | Models that may beat OmniRe (SplatAD, BézierGS, Difix3D+, verified tables) and our SplatAD run on scene-0061's front camera | SplatAD: held-out 30.2 dB vs OmniRe 23.3 (different held-out frames; gap to training 3.5 vs 10.4 dB) |
| [papers/](papers/README.md) | Four 4D Gaussian papers the owner sent (T4GS, RiGS, Instant4D, Mono4DGS-HDR), checked against the goal | None to build on: all monocular, no driving data, two with broken code. One idea each for stages 6–7; read T4GS first |
| [capture/](capture/README.md) | Capturing our own data with an iPhone 15 Pro Max: lens/LiDAR combinations iOS allows, ARKit in a car, what helps reconstruction | Custom app with ARKit inside (main lens + poses); LiDAR and extra lenses add little on roads; drivestudio needs pseudo-LiDAR |
| [careers/](careers/README.md) | Indian companies and labs hiring research / perception / 3D-vision engineers; skills they ask for vs the roadmap | ~40 live roles; C++, PyTorch, real-time deployment and camera geometry get hired; splats and world models make a CV stand out |
| [market/](market/README.md) | Would anyone pay for multi-camera Indian road data? Demand, supply, prices, Indian law | A real gap with no proven buyer. Only price anchor: DrivingFootage ≈$765–900 per driving hour (asking). Ask buyers before building |
| [11-realtime-compute-budget.md](11-realtime-compute-budget.md) + [compute_budget.py](compute_budget.py) | The derived compute budget for each kind of real-time render | Live reconstruction ≈ one H100; world sim ≈ 4–11 GB300 |

## Trust tags

The files use two spellings of the same scale: `[primary]`/`[P]` = read at source or checked through the arXiv/GitHub
API; `[secondary]`/`[S]` = search snippet or someone's summary; `[UNCERTAIN]`/`[U]` = could not confirm.
File 05 adds `[inference]` for the author's own reasoning. `[measured]` below = checked in this session.

## Spot-checks done after the agents finished `[measured]` (2026-11-24)

- arXiv titles matched for 2405.19620 (SparseDrive), 2311.12058 (FlashOcc), 2311.11722 (Sparse4D v3), 2512.08237
  (Fast-BEV++), 2601.15644 (SuperOcc), 2603.29163 (SparseDriveV2), 2606.31814 (TopoGPT's paper, titled "Generative Lane
  Topology Reasoning via Autoregressive Model with Geometry Prior"), 2608.29187 (OPUS-V2).
- Repos exist with the stated licences: swc-17/SparseDrive (MIT), Yzichen/FlashOCC (Apache-2.0),
  HorizonRobotics/Sparse4D (MIT), ziyc/drivestudio (MIT), rerun-io/rerun (Apache-2.0 per the API), commaai/openpilot
  (MIT), wzzheng/OccWorld (Apache-2.0, last push 2024-04).
- `microsoft/onnxruntime` returns **404** on github.com and the GitHub API, but `onnxruntime` 1.32.0 is on PyPI, so
  installing still works. Cause unknown.

## Where the agents disagreed, and how it was resolved

- **Detector.** 02 picked Sparse4D v3 + FlashOcc; 03 picked SparseDrive-S. They fit together: SparseDrive's
  detection is from the same Horizon Sparse4D line and adds lanes, forecasts and the plan. Use **SparseDrive-S +
  FlashOcc** offline on the 4090 (phase 1). For live Mac inference (phase 2), SparseDrive keeps the same
  `use_deformable_func=False` → `F.grid_sample` fallback as Sparse4D (`projects/mmdet3d_plugin/models/blocks.py`
  lines 58/235 `[measured]`), so try SparseDrive-S directly. Keep Sparse4D v3 (detection only) in reserve in case its
  map or planning heads resist export. Whether either one actually exports to ONNX is untested.

## Biggest dead ends (details in each file)

- "The FSD display runs on Unreal / always showed occupancy": both myths (01).
- Tesla's generative Gaussian splatting and world simulator: no paper, code or patent (01, 04).
- No occupancy network has ever been ported to CoreML / Apple Silicon, and no BEV model has a published Mac latency (02, 05).
- "Lanes as language" models RoadNetTransformer / LaneGraph2Seq never released weights (03).
- Every open realtime generative driving simulator needs more than 24 GB of GPU memory (04).
- No usable open "Tesla visualization clone" exists; GitHub has only 0–5★ toys (05).
- The FlashOcc C++ TensorRT port its README links is a 404; DA-Occ was withdrawn from arXiv; VADv2 has no weights (02, 03).
