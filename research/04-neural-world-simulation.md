# 04 — Neural rendering and generative world models for driving

Scope: per-scene reconstruction, feed-forward surround-view Gaussians, generative video/occupancy world models, and Mac viewers.
Research date: **2026-11-24**. Light web research only; nothing downloaded or run.
Trust tags: **[P]** = primary (read at source: paper HTML, README, LICENSE, GitHub/HF/arXiv API); **[S]** = secondary (search snippet, press, wiki); **[U]** = uncertain / could not confirm.
Star counts and push dates come from the GitHub API on 2026-11-24 and will go stale.
Every arXiv ID below was checked against its arXiv title. Every repo was checked with `gh api`.

## TL;DR

- **Start with per-scene reconstruction on the 4090.** OmniRe (drivestudio, MIT) and Street Gaussians both report **one RTX 4090** in their papers: about 1 h per scene for OmniRe and about 30 min for Street Gaussians, which renders at 135 FPS at 1066×1600 [P]. Of everything here, this is the only "Tesla-style 3D from fleet video" result you can reproduce on your hardware.
- **Feed-forward 4D Gaussians are the open match for Tesla's reported "generative Gaussian splatting, ~220 ms, no initialization"** [S]. DGGT (0.4 s, Apache, Waymo weights) and ReconDrive (Apache, weights released) can be used for inference. **Training one yourself does not fit 24 GB**: they were trained on 8×H200 and on H800s (8 GPU-days) [P]. The only feed-forward model trained on an RTX 4090 is EVolSplat, and it is front-camera KITTI-360, not surround view [P].
- **Generative video world models are mostly out of reach on 24 GB.** Epona is the best fit: MIT licence, weights released, and "all inference scripts run on a single 4090" at about 2 s per 512×1024 frame (100 steps) or about 0.3 s (10 steps) [P]. OccWorld (occupancy world model) is the only one whose README trains it on an RTX 4090 24 GB [P].
- **The real-time NVIDIA stack is out of reach.** Cosmos-Predict2.5 multiview needs at least 8×80 GB [P]. Cosmos 3 Nano-Sim-Auto needs 80 GB or more [P]. OmniDreams renders 68 FPS on one GB300 and needs about 48 GB minimum, with a 32 GB RTX 5090 configuration [P]. GAIA-1/2/3/4 are closed [P/S].
- **Mac viewing works through browser or Metal splat viewers:** SuperSplat, Spark, Brush, MetalSplatter, viser and Visionary are all open and active as of 2026-11 [P]. **Gotcha:** drivestudio's `export_gaussians_to_ply` returns only `positions` and `colors`, which is a point cloud and not a 3DGS PLY [P]. You must write a small exporter for scales, rotations, opacity and SH.

## A. Per-scene reconstruction (optimise one scene from its logs)

| Method | arXiv | Yr | Code | Licence | ★ / last push | Weights | Training cost | Render speed (GPU) | Fits one 4090? |
|---|---|---|---|---|---|---|---|---|---|
| EmerNeRF | 2311.02077 | 2023 | github.com/NVlabs/EmerNeRF | NVIDIA non-commercial [P] | 641 / 2024-02 (stale) | "release soon", still unticked [P] | 1×A100: 33–40 min static, 2–2.25 h dynamic [P] | 0.21 FPS (as measured in Street Gaussians' Table 2) [P] | VRAM not reported [U] |
| Street Gaussians | 2401.01339 | 2024 | github.com/zju3dv/street_gaussians | ZJU research/education/personal use [P] | 1424 / 2026-09 | — | ~30 min, **1×RTX 4090** [P] | **135 FPS @1066×1600, RTX 4090** [P] | **Yes** [P] |
| DrivingGaussian | 2312.07920 | 2023 | github.com/VDIGPKU/DrivingGaussian | none listed | 421 / 2024-07 | "released" 2024-03 [P] | 8× RTX8000 (384 GB total) [P] | not reported | **Code only after signing an application form** [P] |
| PVG | 2311.18561 | 2023 | github.com/LogosIntelligenceLab/PVG | MIT | 368 / 2026-10 | — | ~1 h, 1×A6000 (48 GB) [P] | 50 FPS (41 FPS with 5 cams), A6000 [P] | Likely; peak VRAM not reported [U] |
| S3Gaussian | 2405.20323 | 2024 | github.com/nnanhuang/S3Gaussian | research-only text [P] | 551 / 2026-01 | — | not found in paper | not found | [U] |
| NeuRAD | 2311.15260 | 2023 | github.com/georghess/neurad-studio | Apache-2.0 | 510 / 2026-11 | — | ~1 h, 1×A100 [P] | not extracted | README has "lower-memory settings" [P]; 24 GB not confirmed [U] |
| **OmniRe** (drivestudio) | 2408.16760 | 2024 | github.com/ziyc/drivestudio | **MIT** | 1294 / 2025-08 | — | **~1 h/scene, 1×RTX 4090** [P] | not extracted | **Yes** [P]. The SplatAD paper says drivestudio memory "did not scale" to Argoverse2 at high resolution [P] |
| SplatAD (camera+lidar) | 2411.16816 | 2024 | github.com/carlinds/splatad (kernels); model in neurad-studio | Apache-2.0 | 438 / 2025-10 | — | ~1 h, 1×A100 [P] | "real-time" (title); FPS not extracted | [U] |
| DeSiRe-GS | 2411.11921 | 2024 | github.com/chengweialan/DeSiRe-GS | none listed | 247 / 2024-12 | — | not checked | not checked | [U] |
| BézierGS | 2506.22099 | 2025 | github.com/LogosIntelligenceLab/BezierGS | MIT | 140 / 2026-10 | — | 30k iters, 1×RTX A6000 [P] | not extracted | [U] |
| StreetCrafter (diffusion prior to 3DGS) | 2412.13188 | 2024 | github.com/zju3dv/street_crafter | ZJU (custom) | 338 / 2026-09 | not checked | diffusion: 2 days on 8×A800; per-scene distil: 1.5 h on 1×A800 [P] | diffusion path 0.2 FPS @576×1024 [P] | Distil step maybe; diffusion training no |
| 3DGUT / 3dgrut (general, not driving-specific) | 2412.12507 | 2024 | github.com/nv-tlabs/3dgrut | Apache-2.0 | 2511 / 2026-11 | — | — | — | Linux + Windows; exports PLY ⇄ USD ⇄ NuRec USDZ [P] |
| UniSim (Waabi) | 2308.01898 | 2023 | **no official code found** | — | — | — | — | — | **Dead end** |

Other 2025 successors that were found but not dug into: DriveDreamer4D (github.com/GigaAI-research/DriveDreamer4D, 332★) and ReconDreamer (github.com/GigaAI-research/ReconDreamer, 228★), which use generative priors to repair novel views, and Difix3D+ (2503.01774, github.com/nv-tlabs/Difix3D, 1317★) [P: repos exist; costs not checked]. A targeted search did not find a 2026 per-scene method with code that clearly beats OmniRe on Waymo [S].

## B. Feed-forward surround-view Gaussians (no per-scene optimisation)

| Method | arXiv | Yr | Code | Licence | ★ / last push | Weights | Training cost | Inference speed (GPU) | Fits one 4090? |
|---|---|---|---|---|---|---|---|---|---|
| DrivingForward | 2409.12753 | 2024 | github.com/fangzhou2000/DrivingForward | MIT | 249 / 2026-09 | Yes (Google Drive) [P] | ~3 days, 1×A6000; **40.0 GB** training memory [P] | 0.63 s/scene, 7.58 GB [P] | Inference yes. Training as published needs 40 GB, so no without cuts [P] |
| STORM | 2501.00602 | 2025 | github.com/NVlabs/GaussianSTORM | **NVIDIA non-commercial** [P] | 374 / 2025-05 | **No official checkpoint** ("unofficial in issues") [P] | 100k iters, global batch 64 on A100s (GPU count not extracted) [P] | 0.18 s per scene; a whole 20 s clip in <0.5 s, 1×A100 bf16 [P] | Training no |
| Omni-Scene | 2412.06273 | 2024 | github.com/WU-CVGL/Omni-Scene | MIT | 254 / 2025-03 | Yes (Google Drive) [P] | 2×A100, 100k iters [P] | README: ≥1 A100 even for the demo [P] | No, per README |
| DrivingRecon | 2412.09043 | 2024 | github.com/EnVision-Research/DriveRecon | none listed | 196 / 2025-11 | not checked | 24×A100-80G [P] | — | No |
| SCube | 2410.20030 | 2024 | github.com/nv-tlabs/SCube | NVIDIA custom | 528 / 2025-10 | not checked | 64×A100 for 2 days + 8×A100 for 2 days [P] | 138 FPS render (20 FPS with extra module) [P] | No |
| **EVolSplat** | 2503.20168 | 2025 | github.com/Miaosheng1/EVolSplat (nerfstudio) | ZJU research/education/personal [P] | 93 / 2025-06 | Yes, KITTI-360 (HF) [P] | **trained on RTX 4090** [P] | 10.41 GB inference @376×1408 [P] | **Yes**, but front camera only, not surround |
| EVolSplat4D | 2601.15951 | 2026 | github.com/Miaosheng1/EVolSplat4D | "other" | 21 / 2026-10 | Yes, Waymo (HF, 2026-10-02) [P] | not extracted | measured on RTX 5880 [P] | [U] |
| **DGGT** (unposed, 4D) | 2512.03004 | 2025 | github.com/xiaomi-research/dggt | Apache-2.0 [P] | 606 / 2026-01 | Waymo weights; others "coming soon" [P] | 8×H200 [P] | ~0.4 s per scene (evaluated on A100) [P] | Inference likely; VRAM not reported [U]. Training no |
| **ReconDrive** (4D, nuScenes) | 2603.07552 | 2026 | github.com/TuojingAI/ReconDrive | Apache-2.0 (README) [P] | 173 / 2026-03 | Yes (HF) [P] | 8 GPU-days on H800 [P] | not extracted | Inference likely [U]. Training is days-to-weeks even if memory fits [U] |
| UniSplat | 2511.04595 | 2025 | code not checked | — | — | — | 16×H20 [P] | — | No |
| VGD | 2510.19578 | 2025 | github.com/JHLin42in/VGD | MIT | 15 / 2025-11 | — | 1×A100 [P] | — | **Repo holds only README and LICENSE: no code** [P] |

## C. Generative video and occupancy world models

| Method | arXiv | Yr | Code | Licence | ★ / last push | Weights | Training cost | Generation speed (GPU) | Fits one 4090? |
|---|---|---|---|---|---|---|---|---|---|
| GAIA-1 (Wayve) | 2309.17080 | 2023 | **none** | — | — | **none** | world model: 4 days on 32×A100-80G [P] | — | **Closed** |
| GAIA-2 | 2503.20523 | 2025 | **none** | — | — | **none** | tokenizer on 128×H100; world model on 256×H100 [P] | — | **Closed** |
| GAIA-3 (Dec 2025, 15B) / GAIA-4 (Aug 2026, closed-loop + radar) | — | — | none | — | — | none | — | — | Closed [S, wiki/trade press only] |
| DriveDreamer | 2309.09777 | 2023 | github.com/JeffWang987/DriveDreamer | Apache-2.0 | 601 / 2024-11 | not mentioned in README [U] | A800s (count not given) [P] | — | [U] |
| DriveDreamer-2 | 2403.06845 | 2024 | github.com/f1yfisher/DriveDreamer2 | Apache-2.0 | 273 / 2025-03 | Yes, via Baidu Pan [P] | A800-80G [P] | — | [U] |
| Vista (front camera) | 2405.17398 | 2024 | github.com/OpenDriveLab/Vista | Apache-2.0 | 913 / 2025-07 | Yes, HF Apache [P] | 128×A100 ~8 days, then 8×A100 ~10 days [P] | **≥32 GB VRAM suggested for sampling**; `--low_vram` flag [P] | Probably no [U] |
| MagicDrive | 2310.02601 | 2023 | github.com/cure-lab/MagicDrive | Apache-2.0 | 1167 / 2025-04 | Yes (SharePoint, 16-frame) [P] | V100s [P] | — | [U] |
| MagicDrive-V2 | 2411.13807 | 2024 | github.com/flymin/MagicDrive-V2 | **AGPL-3.0**; HF weights GPL-3.0, gated (auto) [P] | 726 / 2025-06 | Stage 3 only [P] | 32×A800 [P] | 6 views ×848×1600×241 frames: 28.9 min on 8×H20. 224×400×6 views ×17 frames: ~18 GB peak with CPU offload, plus 3.9 GB to decode (measured on H20) [P] | Low-resolution inference only [P, extrapolated] |
| **OccWorld** (occupancy) | 2311.16038 | 2023 | github.com/wzzheng/OccWorld | Apache-2.0 | 598 / 2024-04 | Yes (Tsinghua cloud) [P] | 8×RTX 4090 at batch size 1 per GPU; README trains on "RTX 4090 with 24G" [P] | OccWorld-O 18.0 FPS (GPU not stated in table) [P] | **Yes**, about 8× slower on one card |
| OccSora | 2405.20337 | 2024 | github.com/wzzheng/OccSora | Apache-2.0 | 207 / 2024-05 | not checked | 8×A100; README requires A100-80G [P] | — | No |
| DOME (occupancy) | 2410.10429 | 2024 | github.com/gusongen/DOME | Apache-2.0 | 73 / 2026-04 | Yes [P] | VAE on 8×4090; DiT on 32×4090 for 2000 epochs [P] | — | VAE yes; DiT too slow [U] |
| DriveArena | 2408.00415 | 2024 | github.com/PJLab-ADG/DriveArena | Apache-2.0 | 473 / 2025-09 | Yes (WorldDreamer v1.1) [P] | 8×A100-80G, 200k iters [P] | ~120 s simulation per trajectory [P] | [U] |
| UniScene | 2412.05435 | 2024 | github.com/Arlo0o/UniScene-Unified-Occupancy-centric-Driving-Scene-Generation | Apache-2.0 | 624 / 2026-05 | Yes (HF) [P] | A100s (count not stated) [P] | — | [U] |
| DrivingWorld | 2412.19505 | 2024 | github.com/YvanYin/DrivingWorld | MIT | 246 / 2025-01 | Yes (HF) [P] | tokenizer on 32×4090; world model on 64×A100 for 12 days [P] | — | Inference [U] |
| **Epona** (front camera, autoregressive) | 2506.24113 | 2025 | github.com/Kevin-thu/Epona | **MIT** | 393 / 2025-07 | **Yes (HF, MIT)** [P] | 48×A100 for ~2 weeks [P] | **512×1024 frame: ~2 s (100 steps) or ~0.3 s (10 steps) on 1×RTX 4090** [P] | **Inference yes** [P]; training no |
| InfiniCube | 2412.03934 | 2024 | github.com/nv-tlabs/InfiniCube | NVIDIA custom + Waymo non-commercial [P] | 145 / 2026-01 | Yes (HF) [P] | 48 + 192 + 32 A100 GPU-days [P] | — | No |
| Cosmos-Predict1 / Transfer1 / Cosmos-Drive-Dreams | 2501.03575, 2503.14492, 2506.09042 | 2025 | github.com/nvidia-cosmos/cosmos-transfer1, github.com/nv-tlabs/Cosmos-Drive-Dreams | Apache code; NVIDIA Open Model License weights [P] | 829 / 2026-10; 559 / 2026-03 | 7B AV models on HF [P] | — | Transfer1 6 views ×121 frames @704×1280: ~19.9 min on A100 (third-party estimate in MagicDrive-V2's Table III) [P] | No |
| Cosmos-Predict2.5 / Transfer2.5 auto-multiview (2B) | not verified | 2025 | github.com/nvidia-cosmos/cosmos-predict2.5 | Apache code; NVIDIA Open Model License; HF gated (auto) [P] | 1406 / 2026-06 | Yes [P] | — | **multiview inference needs ≥8 GPUs × ≥80 GB** [P] | No |
| Cosmos 3 Nano-Sim-Auto (Jun 2026) | — | 2026 | github.com/NVIDIA/cosmos | OpenMDW-1.1 [P] | 12440 / 2026-11 | Yes (HF, not gated) [P] | — | Nano (16B): RTX Pro 6000 / H100 / B200; Sim-Auto docs require **80 GB+**, Linux [P] | No |
| **OmniDreams** (real-time, action-conditioned) | 2606.03159 | 2026 | github.com/NVIDIA/flashdreams | Apache code; weights `nvidia/omni-dreams-models` licence "other", gated (auto) [P] | 548 / 2026-11 | Yes [P] | Cosmos-Predict2.5 base + 21k h of driving [P] | **68 FPS single-view 704×1280 on 1×GB300**; minimum ~48 GB, plus a 32 GB RTX 5090 config at 1168×640 [P] | **No** (24 GB is below the documented minimum) |
| OpenDWM (SenseTime) | — | 2025 | github.com/SenseTime-FVG/OpenDWM | MIT | 430 / 2025-06 | Yes (HF) [P] | — | 32 GB for short multi-view video; 80 GB for long [P] | No |
| MAD-LTX | 2601.09452 | 2026 | **code not found** (project page only) | — | — | [U] | fine-tune: 128 GPU-h (2B) or 700 GPU-h (13B) on GH200 [P] | — | [U] |

**Tesla context [S only]:** Ashok Elluswamy described a learned "neural world simulator" at ICCV 2025 and on X around 2025-10-25. It generates multi-camera video for closed-loop evaluation. Coverage also cites a "generative Gaussian splatting" that reconstructs dynamic 3D in **~220 ms** with no initialization. No paper, code or hardware details exist. The open analogues are feed-forward 4D Gaussians (DGGT, ReconDrive, STORM) for the 3D side and action-conditioned video models (Epona, OmniDreams) for the simulator side.

## Mac viewing options (16 GB Apple silicon)

None of these were run here, because the rules said not to run anything. Platform claims come from READMEs and release assets [P].

| Viewer | Repo (★ / push) | Licence | Tech | Dynamic content? | Use it for |
|---|---|---|---|---|---|
| **SuperSplat** | github.com/playcanvas/supersplat (10716 / 2026-11-19) | MIT | Browser editor on the PlayCanvas engine 2.24.1 | Camera keyframes and timeline; no per-splat animation found [U] | Inspecting and cleaning static backgrounds, cropping floaters, sharing |
| **Spark** | github.com/sparkjsdev/spark (3950 / 2026-11-19) | MIT | three.js, WebGL2 ("98%+ devices") | **"Fully dynamic: each splat can be transformed … for animation"**, plus a GPU shader graph [P] | **An FSD-style display**: static background splats plus per-actor rigid transforms driven by OmniRe's per-frame box poses, composited with three.js meshes and lanes |
| **Brush** | github.com/ArthurBrussee/brush (5359 / 2026-11-23) | Apache-2.0 | Rust + WebGPU; macOS / Windows / Linux; v0.3.0 has `aarch64-apple-darwin` and Windows builds [P] | **Plays a `.zip` of per-frame PLYs as an animation**, plus delta-frame PLY [P] | Quickest way to play a dynamic scene exported frame by frame. Also *trains* static 3DGS on the Mac (one job at a time) |
| MetalSplatter | github.com/scier/MetalSplatter (726 / 2026-09) | MIT | Swift / Metal; macOS, iOS, visionOS | No | Native Mac/iOS app path. **Not Windows** |
| viser | github.com/viser-project/viser (2874 / 2026-11) | Apache-2.0 | Python server with a browser client; WebGL splat renderer, `add_gaussian_splats` [P] | Yes, scripted from Python | Debug view: run on the 4090, port-forward, open in a Mac browser; splats composited with boxes and lanes |
| Visionary | github.com/Visionary-Laboratory/visionary (537 / 2026-10); arXiv 2512.08478 | Apache-2.0 | WebGPU + ONNX Runtime | **4DGS and avatars via ONNX**; static PLY/SPLAT/KSplat/SPZ/SOG [P] | Trying true 4DGS in a browser. Needs WebGPU (Chrome on macOS; Safari support [U]) |
| web-splat | github.com/KeKsBoTer/web-splat (314 / 2026-10) | Apache-2.0 | Rust wgpu / WebGPU | No | A small codebase to learn from |
| antimatter15/splat | github.com/antimatter15/splat (3094 / 2025-11) | MIT | WebGL, about one file | No | Reading a minimal splat renderer |

Training on the Mac is possible but not recommended: OpenSplat (github.com/WebODM/OpenSplat, AGPL-3.0) runs on Apple Metal [P], and so does Brush. Both are static 3DGS only, not driving-specific.

## Recommended learning path

1. **First: OmniRe through drivestudio, trained on the 4090, viewed on the Mac.**
   - **Why:** it is the only driving method with a paper-reported RTX 4090 setup (about 1 h per scene) [P]. It is MIT-licensed and has loaders for Waymo, nuScenes, nuPlan, Argoverse, PandaSet and KITTI [P]. Its scene graph (background + rigid vehicles + SMPL humans) is exactly the structure of a Tesla-style reconstruction. Run Street Gaussians mode (also in drivestudio) first as the simpler baseline.
   - **Work you will need to do:** write a standard 3DGS PLY exporter for each node, with means, scales, quats, opacity and SH, because the built-in export is points and colours only [P]. Then view the static background in SuperSplat or Brush.
   - **Rejected:** EmerNeRF (NeRF at 0.21 FPS, stale, non-commercial); NeuRAD and SplatAD (A100-measured and nerfstudio-heavy; good later for lidar); DrivingGaussian (code behind a form).
2. **Second: dynamic playback, then a feed-forward model.**
   - **Playback:** (a) export per-frame PLYs and play the zip in Brush [P]; or (b) export background plus per-actor canonical splats plus per-frame poses, and animate them in Spark. Option (b) is the real "FSD display" architecture: perception output drives a renderer.
   - **Feed-forward:** run **DGGT** or **ReconDrive** inference with the released weights on the 4090 to feel the "seconds, not hours" step that Tesla's 220 ms claim points at.
   - **If you want to train a feed-forward model on 24 GB:** use **EVolSplat** (trained on a 4090 [P]), accepting that it is front-camera only.
   - **Rejected:** STORM (no official checkpoint, non-commercial); Omni-Scene, DrivingRecon and SCube (need A100s); DrivingForward training (40 GB).
3. **Third: generative world models.**
   - **OccWorld** first: train it on one 4090 [P]. Occupancy-in, occupancy-out ties directly into the perception side's occupancy grid, and its output renders as voxels in the same Spark/three.js scene.
   - Then **Epona** inference on the 4090 for camera-video "dreaming" (MIT; about 2 s per frame at 100 steps, or about 0.3 s at 10 steps [P]).
   - **Rejected:** Vista (≥32 GB to sample); MagicDrive-V2 (AGPL/GPL, and only low resolution fits); Cosmos 2.5/3 and OmniDreams (48–640 GB of GPU); OpenDWM (32 GB minimum); GAIA (closed).
   - **Alternative if you have budget:** rent a 48 GB-plus GPU for one day to try OmniDreams' interactive drive demo.

## Dead ends (as of 2026-11-24)

- **UniSim:** paper only; no official code found.
- **GAIA-1/2/3/4 (Wayve):** no code and no weights. GAIA-3 and GAIA-4 details come from secondary sources only.
- **Tesla world simulator / generative GS:** no paper, code or hardware details; secondary coverage only.
- **DrivingGaussian:** code is gated behind a signed application form, and training used 8× RTX8000.
- **STORM:** "We cannot share an official checkpoint"; NVIDIA non-commercial licence.
- **VGD:** the repo has no code.
- **MAD-LTX:** no code repo found.
- **EmerNeRF:** pretrained models were promised and never released; last push 2024-02.
- **Too big for one 4090:** Cosmos-Predict2.5 multiview (≥8×80 GB), Cosmos 3 Nano-Sim-Auto (80 GB+), OmniDreams (~48 GB minimum; its real-time numbers are on GB300), OccSora (A100-80G), Omni-Scene (A100 even for the demo), OpenDWM (32 GB).
- **Archived or unmaintained:** `nvidia-cosmos/cosmos-predict2` is archived; mkkellogg/GaussianSplats3D README says it is "no longer in active development".
- **drivestudio export gotcha:** `export_gaussians_to_ply` exports positions and colours only, not a viewable splat file.

## Open questions (not verifiable without hands-on time)

- What is OmniRe's peak VRAM with 5–6 cameras at full resolution? The paper says RTX 4090 but the camera count and resolution behind that figure were not extracted. SplatAD reports drivestudio memory problems on Argoverse2.
- What is the inference VRAM of DGGT, ReconDrive and EVolSplat4D on 24 GB? Not reported.
- Does Vista's `--low_vram` mode fit in 24 GB?
- Can NVIDIA's **PhysicalAI-Autonomous-Vehicles-NuRec** dataset (HF, gated with click-through, licence "other", updated 2026-10-29 [P]) be transcoded to PLY with 3dgrut (the PLY ⇄ NuRec path exists [P]) and viewed on the Mac? That would give real driving reconstructions with no training at all. Whether dynamic actors survive the transcode is [U].
- Does Safari's WebGPU run Visionary and Brush-web on this Mac, or is Chrome required?
- Which licences block a learning project? None, for personal research. But Street Gaussians, EVolSplat, STORM, EmerNeRF and the Waymo data are non-commercial, so revisit before anything is shipped.
