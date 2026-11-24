# 11 — Compute budget for a real-time Tesla-style world render

Derived 2026-11-24 from the measurements in research/07 (feed-forward reconstruction), 08 (splat drawing),
09 (world simulators) and 10 (hardware). All arithmetic is in `research/compute_budget.py`; run it to reproduce every
number below. Tags: `[measured]` = a number a paper reports, carried over from 07–10 with its source there;
`[derived]` = computed here from those numbers under the assumption stated next to it. Nothing was benchmarked on our
own hardware.

## The answer in one table

Targets: 8 cameras, a 60 fps viewer, simulation at 24–30 fps per camera.

| What runs in real time | Compute needed `[derived]` | RTX 4090 | Apple M5 (this Mac, 16 GB, 10-core GPU) |
|---|---|---|---|
| **A. FSD-style screen**: perception at 12 Hz, game-engine draw at 60 fps | one perception net; drawing is trivial | SparseDrive-S 9 fps in PyTorch `[measured]`, close to 12 Hz; FlashOcc 5 ms with TensorRT on a 3090 `[measured]` | drawing yes; perception speed unmeasured (research/05) |
| **B1. Replay a pre-built splat scene**, one viewer at 60 fps | any recent GPU | 135 fps at 1.7 MP `[measured]` | **38–136 fps** for ~2 M splats in a browser, depending on whether fixed per-frame cost scales with GPU size |
| **B2. Replay for 8 simulated cameras** at 30 fps | ≤ 4.2 ms per view | 7.4 ms per 1.7 MP view → 17 fps for all 8; reaches 30 fps at ~1 MP (4.3 ms) or after pruning (0.6 ms) | unknown; probably not at full resolution |
| **B3. Live feed-forward reconstruction** (Tesla's ~220 ms Generative Gaussian Splatting), 8 cameras at ~0.23 MP each | **about one H100**: 0.12–0.22 s per update | 0.35–0.83 s → **1–3 updates/s** | **6–17 s per update**; not real time |
| B3 at 1 MP per camera | 2.6–5.4 s per update on an A100 → several H100/B200 | no | no |
| **C. Neural world simulator**, 8 cameras × 24 fps at ~0.9 MP | **~4–11 GB300** (9–28 PFLOPS dense FP16 peak) | ~5 fps for **one** camera | no |

## A. The FSD-style screen

- Drawing a few hundred car meshes, lane lines and a voxel grid at 60 fps is ordinary game rendering on any modern GPU.
- The cost is the perception network:
  - SparseDrive-S: 9 fps on a 4090 in PyTorch `[measured]`.
  - FlashOcc M0: 197.6 fps with TensorRT FP16 on a 3090 `[measured]`.
- Tesla's HW3 (144 INT8 TOPS, 72 W; 0.23× an A100's dense INT8) ran 2,300 frames/s of its networks in 2019 `[measured]`.
  So this tier fits in-car hardware.

## B. Splat world: draw, then rebuild

**Drawing (research/08).**
- Measured on a 4090: Street Gaussians draws one 1.71 MP view in 7.41 ms.
- `[derived]` Eight cameras need 59 ms per frame (16.9 fps). 30 fps for all 8 needs ≤ 4.17 ms per view.
- `[derived]` Cost roughly follows pixels: at 1.0 MP the same scene takes 4.34 ms. Speedy-Splat pruning (6.7× faster on
  average) brings it to about 0.6 ms.
- Cost is ~60% per-pixel blending and ~30% sorting `[measured]`. It is FP32 and memory-bandwidth work, so tensor TFLOPS
  do not help (research/10).

**This Mac (M5).**
- No native Metal benchmark exists. The anchor is a browser (WebGPU) on an M4 Max at 1298×962: 20 M splats → 98 fps,
  35 M → 76 fps `[measured]`.
- `[derived]` Fitting t = t₀ + n/k gives t₀ ≈ 6.3 ms and k ≈ 5.1 G splats/s. The fit predicts 121 fps at 10 M; measured was 124.
- `[derived]` The M5 has 0.25–0.37× the M4 Max's GPU cores and bandwidth. For a ~2 M splat scene that gives:
  - 128–136 fps if the fixed 6.3 ms does not grow on a smaller GPU;
  - 38–56 fps if it does.
- Measure it before trusting either.

**Rebuilding live, Tesla's 220 ms (research/07).**
- Closest anchor: VGD, 6 cameras × 352×640, 0.26 s on an A100 in bf16 `[measured]`.
- `[derived]` Measured growth rates, time ∝ size^a:
  - full-attention models: a = 1.35–1.83 (BTimer, VGGT);
  - neighbour-limited models: a = 0.42–0.90;
  - voxel models: a = 0.17 (EVolSplat4D).
- `[derived]` 8 cameras at the same resolution: 0.35–0.44 s on an A100, producing about 1.8 M per-pixel Gaussians. Then
  scaling by dense FP16 peak:
  - RTX 4090: 0.65–0.83 s. The 4090 often does better than its peak ratio at batch 1, so expect 0.35–0.83 s.
  - H100: 0.12–0.22 s, assuming a realistic 2–3× over the A100.
- **So Tesla's 220 ms matches one H100-class GPU running a VGD-class model on ~0.23 MP per camera.**
- `[derived]` At 1 MP per camera the time grows to 2.6–5.4 s on an A100 (pixel a = 1.34–1.68). No paper is close to
  native resolution in real time.
- `[derived, very uncertain]` In the car, AI4 is estimated (unofficially) at 0.16–0.24× an A100's dense INT8. A VGD-class
  model would take ~1.5–2.8 s there. A 220 ms in-car figure would need a model ~7–13× leaner, or the figure is from
  datacenter hardware. Tesla has not said which. AI5 (~8× AI4, unofficial) would be 1.3–1.9× an A100.
- This Mac: Apple publishes no M5 FP16 figure. Assuming 8–17 usable TFLOPS gives 6–17 s per update. Practical on the Mac:
  draw scenes built on the 4090.

## C. Neural world simulator (research/09)

- Anchor: OmniDreams-MV (2B, 2 steps, 704×1280), 4 views. Camera-frames per second: 48 / 192 / 296 / 420 on
  1 / 4 / 8 / 16 GB300 `[measured]`.
- Tesla's claim is 8 cameras × 24 fps = 192 camera-frames/s, at a resolution Tesla has not given.
- `[derived]` Going from 4 to 8 views raises the cost per camera-frame by 2^(a−1) = 1.0–1.78 (a = 1.0–1.83). That needs
  **~4, ~6 or ~11 GB300** for a = 1.0, 1.34 and 1.83: about 9–28 PFLOPS of dense FP16 peak per simulated car.
- `[derived]` One GB300 is 14–15× a 4090 in dense FP16. Scaling the single-view 68 fps by peak gives a 4090 4.5–5 fps for
  one camera. That is consistent with Epona's measured 0.3 s/frame at 10 steps on a 4090 `[measured]`.
- For scale: MAGI-1 (24B, 16 steps) needs ~9 PFLOP of compute per second of one 480p video stream `[measured]`. That is
  why every real-time system uses a 1–2B model distilled to 1–4 steps.

## Low-quality settings (`compute_budget.py` section 6)

**Biggest lever: lower input resolution for reconstruction.** Time grows as pixels^1.34–1.68 `[derived]`.

| 8 cameras at | A100 | RTX 4090 | Apple M5 | Gaussians per update (1 per pixel) |
|---|---|---|---|---|
| 352×640 (VGD) | 0.35–0.44 s | 0.35–0.83 s | 6–17 s | 1.80 M |
| 224×400 (Omni-Scene) | 0.07–0.13 s | 0.07–0.24 s (**4–14 updates/s**) | 1.4–5 s | 0.72 M |
| 160×240 (STORM) | 0.02–0.04 s | 0.02–0.08 s (13–56 updates/s) | 0.3–1.6 s | 0.31 M |

- Cross-check: Omni-Scene measured 0.088 s for 6 cameras at 224×400 `[measured]` → 0.12–0.15 s for 8 `[derived]`.
- Fixed overheads set a floor of ~20–40 ms. VGGT's backbone takes 0.04 s for one frame on an H100 `[measured]`.

**Fewer Gaussians, for drawing.**
- Speedy-Splat at ~0.3 M: 1.11 ms per view on an RTX A5000, slower than a 4090 `[measured]`. So 8 views take ≤ 9 ms.
- On the M5 the per-frame fixed cost dominates below ~1 M splats: 40–59 fps or ~150 fps, depending on whether that
  cost scales with GPU size `[derived]`. Fewer splats barely help there, but fewer pixels (a smaller window) would.

**Smaller Gaussians, for memory.**
- 236 B each at SH degree 3; 92 B at degree 1; 56 B at degree 0 (colour only); half that in fp16 `[derived]`.
- 1 M Gaussians at degree 0 in fp16 is 28 MB.

**World sim at 352×640 on a 4090:** 18–51 fps for **one** camera. 8 cameras × 24 fps is still 3.7–10.7× short `[derived; two scaling steps, very rough]`.

**What low quality costs.**
- Lower input resolution blurs texture and thin structures. Pruning to ~10% of Gaussians kept quality close in Speedy-Splat (research/08).
- This file holds no PSNR-vs-resolution curve for the driving feed-forward models. Measure it on our own scenes.

## RTX 5070 Ti 16 GB (`compute_budget.py` section 7)

**Specs** `[measured]` from NVIDIA's RTX 5070 family page, 2026-11-24: 8,960 CUDA cores, 2.45 GHz, 1,406 AI TOPS
(sparse FP4), 16 GB GDDR7, 256-bit, 300 W.

**Derived from those:**
- 43.9 FP32 TFLOPS.
- 87.9 dense FP16 TFLOPS with FP32 accumulate, using the same halving chain as the 5090 whitepaper.
- ~896 GB/s, assuming 28 Gbps memory (the speed is not on NVIDIA's page).

**Compared with a 4090:** 0.53× FP32, 0.53× tensor, 0.89× bandwidth. So networks run 1.1–1.9× slower and splat drawing ~1.6× slower `[derived]`.

| Job on the 5070 Ti | Estimate `[derived]` |
|---|---|
| Replay one 1.7 MP splat view | 12 ms → 84 fps |
| 8 views at 1 MP / pruned | 56 ms → 18 fps / 8.3 ms → 120 fps |
| Live reconstruction, 8 cams at 352×640 / 224×400 / 160×240 | 0.6–3 / **2–12** / 7–50 updates/s |
| World sim, one camera at 704×1280 / 352×640 | 2.4–4.4 / 10–45 fps |

**Fits in 16 GB?** These are inference VRAM figures `[measured]` (research/07), except where marked:

| Model | VRAM | Fits? |
|---|---|---|
| DrivingForward | 7.58 GB | yes |
| DrivingScene | 6.48 GB | yes |
| EVolSplat | 10.41 GB | yes |
| EVolSplat4D | 4.93–12.75 GB | yes |
| VGGT backbone (used by DGGT, ReconDrive, VGD), 8–10 frames | 3.2–3.6 GB | yes, so 12-image DGGT/ReconDrive inputs probably fit `[derived]` |
| VGGT backbone, 100 frames | 21 GB | no |
| STORM at 320×480 (measured by EVolSplat4D) | 22.3 GB | no; needs lower resolution |
| OmniDreams | targets a 32 GB RTX 5090 | unknown `[UNCERTAIN]` |

**Software gate** `[measured]`: PyTorch's first CUDA 12.8 builds (needed for Blackwell, `sm_120`) are 2.7.0. The
perception repos pin torch 1.9–1.13 with mmcv-full 1.x (research/02). They must be ported to torch ≥ 2.7, and their
custom CUDA ops rebuilt with `TORCH_CUDA_ARCH_LIST=12.0`, before anything runs.

## Assumptions that could move these numbers

1. Scaling across devices by peak FLOPS/TOPS is optimistic for big GPUs at batch 1. Papers that time the same model on
   the same kind of GPU disagree by up to ~6×, so treat each row as ±3×.
2. View/pixel exponents come from other architectures (BTimer, VGGT). Tesla's design could be a voxel or latent model
   that scales almost flat with resolution (a ≈ 0.2).
3. The Mac numbers rest on one browser benchmark on a different chip, and on Apple figures with no stated precision.
4. Tesla's camera resolution, step count and hardware for all three systems are undisclosed (research/01).

## What would make these measured instead of derived (one job at a time)

- 4090: run DGGT inference on nuScenes at 6 cameras, then 8. That gives real a and real seconds.
- 4090: count the Gaussians in one OmniRe/Street Gaussians checkpoint and time 8-camera rendering with gsplat.
- This Mac: load a 1 / 3 / 10 M splat scene in Spark and in Brush and read the fps. That settles the 38–136 fps range.
