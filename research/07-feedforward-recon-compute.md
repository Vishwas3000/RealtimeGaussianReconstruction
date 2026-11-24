# 07 — What feed-forward 3D/4D Gaussian reconstruction costs: numbers measured in papers

Researched 2026-11-24. The question: how much compute does a single forward pass that turns camera images into a
Gaussian scene take? It is the open analogue of Tesla's "Generative Gaussian Splatting, ~220 ms, no initialization"
(research/01, research/04). Light web research only: papers were read as arXiv HTML, or as the PDF where the HTML was
broken. No models were run and no weights or datasets were downloaded.

**Trust tags.** `[P]` = read in the paper or README; the location is given. `[S]` = one paper reporting another
paper's number, or a search snippet. `[U]` = could not confirm. `[derived]` = my arithmetic on reported numbers,
never a filled-in gap. **n.r.** = not reported (searched for and not found). All arXiv IDs below were checked by
title against the arXiv HTML/abs page, and each README by `gh api`.

## TL;DR

- **Published driving feed-forward splatting takes 0.09–0.63 s per reconstruction on one GPU, for 6–12 low-resolution
  images.** The reported figures:
  - Omni-Scene: 0.088 s for 6×224×400 (GPU not stated).
  - STORM: 0.18 s on an A100 for 3 cameras × 4 timesteps at 160×240.
  - DrivingScene: 0.21 s for 6(×2 frames)×352×640.
  - VGD: 0.26 s single-frame / 0.39 s two-frame, A100 bf16, 6 cameras at 352×640.
  - DGGT: 0.39 s on an A100 for 3 cameras × 4 frames at 518×518.
  - DrivingForward: 0.63 s on an A6000.

  Tesla's ~220 ms for 8 cameras falls inside this band. **No paper reconstructs 8 cameras at native resolution in that
  time**, and Tesla has not said what hardware, resolution or Gaussian count its figure assumes.
- **Scaling depends on the architecture.** Full-attention, pixel-aligned transformers grow faster than the input:
  - BTimer: 3× the views costs 7.5× the time, and 4× the pixels costs 10.3× the time.
  - VGGT backbone: 10→100 frames costs 22× the time.

  Volume (voxel) methods barely grow. EVolSplat4D goes from 1.29 s to 1.88 s for 9× the pixels, and from 1.24 s to
  1.58 s for 4× the frames. Mamba-hybrid and decoupled-token models (Long-LRM, iLRM) handle 32 views at 540×960 in
  0.5–0.84 s on an H100. `[P]`, ratios `[derived]`.
- **Treat any single latency as ±3×.** The same model gets very different times depending on who measured it:
  - STORM: 0.08 s (A5000, measured by Flux4D), 0.18 s (A100, its own paper), 0.50 s (A100, DGGT's replication).
  - DrivingForward: 0.63 s (its own paper, A6000) vs 0.34 s (measured by DrivingScene).

  GPUs span A100, H100, H20, H800 and RTX A5000/A6000/4090/5090/5880. The precision used in the timed run is almost
  never stated. `[P]`
- **FLOPs/MACs: no paper reports them for a whole model** (0 of 27 read; iLRM gives per-operation GFLOPs only).
  Parameter counts run from 12 M (MVSplat) to 1.2 B (VGGT). Parameters do not drive latency at small inputs: DepthSplat
  has 9.3× more parameters from ViT-S to ViT-L but is only 1.6× slower on 2×256². `[P]`, ratio `[derived]`
- **Training is the expensive part.** It ranges from 1×A6000 for ~3 days (DrivingForward) to 64×A100 for 9 days (VGGT).
  For driving 4D:
  - DGGT: 8×H200, ~24 h.
  - ReconDrive: 8 H800 GPU-days.
  - DrivingRecon: 24×A100, ≈480 A100-hours.
  - STORM: ≈768 A100-hours.
  - Flux4D: 140 L40S-hours.

  The DrivingRecon and STORM hour totals come from the Flux4D paper, which says the authors confirmed them `[S]`.

## Main table A — driving-specific feed-forward models

| Method | arXiv | Latency (what it covers) | GPU / precision | Views × resolution | Timesteps | #Gaussians | Params | FLOPs | Inference VRAM | Training | Source |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **STORM** | 2501.00602 | **0.18 s** per clip (reconstruction; rendering listed separately as >200 FPS). Whole 20 s video (600 images) <0.5 s batched | 1×A100; bf16 stated for the 20 s batched run only | 3 front cams × 160×240 (~7k tokens; fine-tuned up to 32k) | 4 context (2 s clip) | n.r. (pixel-aligned) | n.r. (ViT-B, 12 layers, patch 8) | n.r. | n.r. (22.31 GB measured by EVolSplat4D at 320×480 `[S]`) | 100k it, global batch 64, A100s (count n.r.); ≈768 A100-h per Flux4D `[S]` | Tab. 1; §4.3; App. A; §6 |
| **DGGT** | 2512.03004 | **0.39 s** per scene. Optional diffusion refinement; whether it is included is `[U]` | A100 (all evals) / n.r. | 3 cams × 518×518 | input frames 0/5/10/15, renders 20; ablation 4/8/16 views (quality only) | n.r. (pixel-aligned + sky) | n.r. (DINO + alternating-attention ViT) | n.r. | n.r. | 8×H200, ~24 h, ~5k it | Tab. 1, Tab. 3, App. A "Computation", App. B.1 (PDF; HTML broken) |
| **DrivingForward** | 2409.12753 | **0.63 s** per scene (includes synthesising 6 novel views) | 1×A6000 48 GB / n.r. | 6 cams × 352×640, multi-frame mode | 2 | n.r. (1 per pixel) | n.r. (ResNet-18 + U-Net); 0.173 GB weights per DrivingScene `[S]` | n.r. | **7.58 GB** | 1×A6000, ≈3 days, 10 epochs, 40.0 GB | Tab. 3; §4.4 |
| VGD | 2510.19578 | **0.39 s** MF / **0.26 s** SF | 1×A100, **bf16** | 6 cams × 352×640 | 2 (MF) / 1 (SF) | n.r. | n.r. (distilled VGGT-style; refiner <0.2% of VGGT) | n.r. | n.r. | 1×A100, 10 epochs, batch 2 | Tab. I; §IV-D |
| DrivingScene | 2510.24734 | **0.21 s** | trained on RTX 5090 32 GB; timing GPU not restated | 6 × 352×640, two consecutive surround frames | 2 | n.r. | "0.117 GB" | n.r. | **6.48 GB** | RTX 5090, ≈5 days, 27.3 GB | Tab. 3–4 |
| **Omni-Scene** | 2412.06273 | **0.088 s** six-view reconstruction (mean of 2,048 runs) | n.r. for timing (trained on A100) | 6 × 224×400 | 1 | n.r. (3 per voxel + per-pixel) | **81.7 M** | n.r. | n.r. (README: ≥1 A100 for the demo) | 2×A100, 100k it, batch 4 | Supp. Tab. 4, §7.3; Tab. 3 |
| ReconDrive | 2603.07552 | **15 s** per ≈20 s nuScenes scene, with segment caching; per-segment n.r. | H800 ("all experiments") / n.r. | 6 cams × 518×280, 2 context frames per segment | 2 per segment | n.r. (pixel-aligned) | n.r. (VGGT backbone, DINOv2 p14, d=1024) | n.r. | n.r. | H800, **8 GPU-days** | Tab. 1; "Inference Efficiency"; impl. (PDF only) |
| EVolSplat | 2503.20168 | reconstruction n.r.; **render 83.81 FPS** | "same device"; trained on RTX 4090 | KITTI-360 376×1408 + monocular depth | n.r. | n.r. | n.r. | n.r. | **10.41 GB** at 376×1408 | RTX 4090, time n.r. | Tab. 1; §4 |
| **EVolSplat4D** | 2601.15951 | **~1.3 s** per scene; 1.24–1.88 s in the scaling figure | RTX 5880 / n.r. | 30–120 frames, 320×480 → 960×1440. Inputs: LiDAR (or mono) depth + tracked 3D boxes | 30–120 | n.r. (set by a 128×400×800 voxel grid at 0.1 m) | n.r. | n.r. | **4.93–12.75 GB** | RTX 5880, time n.r. | Tab. 5; Fig. S3 (read from the SVG) |
| DrivingRecon | 2412.09043 | **n.r.** | — | 256×512, Waymo NOTR | n.r. | n.r. (prune/dilate) | n.r. | n.r. | 9.48 GB per EVolSplat4D `[S]` | 24×A100-80G, 50k it, bf16; ≈480 A100-h per Flux4D `[S]` | §4 |
| SCube | 2410.20030 | **~20 s** (latent-diffusion geometry + feed-forward appearance; optional GAN adds ~20 min) | n.r. | 3 × 1920×1280 | 1 | "millions", 1024³ voxels | n.r. | n.r. | n.r. | 64×A100 2 d + 8×A100 2 d | abstract; App. |
| WorldSplat | 2509.23402 | Gaussian decoder **0.84 s**; whole pipeline 2.50 min (2 diffusion stages, 8 steps each) | 1×H20 | 6 × 424×800 | 17 frames | n.r. | n.r. | n.r. | 22 GB (whole pipeline) | not extracted | Tab. 5 |
| Flux4D | 2512.03210 | **0.13 s** base; **1.8 s** with 2 refinement iterations | 1×RTX A5000 24 GB | front cam ≥1920×1080 + 360° LiDAR initialisation | 6 input frames (1.5 s window) | n.r. (LiDAR-seeded) | n.r. | n.r. | n.r. | 4×L40S, 30k it, ~2 days (140 L40S-h) | Tab. 1; §4; App. E |
| SLARM (streaming) | 2603.22893 | 1.05–1.65 s window attention vs 1.12–4.25 s full attention, over x=24→36 (axis unlabelled, probably frames `[U]`) | n.r. | Waymo 160×240 | streaming | n.r. | n.r. | n.r. | 23 GB flat (window) vs 27→63 GB (full) | n.r. | Fig. 5(d) (read from the image) |

**Same GPU, same protocol, many models** (A100, Waymo, 3 front cams × 4 timesteps; resolution differs: STORM's table is at 160×240, DGGT runs at 518×518) `[P]`:
- STORM Tab. 1 (with reimplementations): GS-LRM 0.02 s, LGM 0.06 s, STORM 0.18 s.
- DGGT Tab. 1 adds: MVSplat 0.08 s, DepthSplat 0.11 s, VGGT++ 0.24 s, DGGT 0.39 s, STORM replicated at 0.50 s, and
  NoPoSplat 23.22 s (pose-free; probably includes pose optimisation `[U]`).

Under one protocol, latency spans 20× (0.02–0.39 s, leaving out NoPoSplat).

## Main table B — general generalizable splatting (scaling references)

| Method | arXiv | Latency | GPU / precision | Views × resolution | #Gaussians | Params | FLOPs | Inference VRAM | Training | Source |
|---|---|---|---|---|---|---|---|---|---|---|
| pixelSplat | 2312.12337 | encode 0.102 s + render 0.002 s | n.r. | 2 × 256² | 3 per pixel (per MVSplat) | 125.4 M (MVSplat Tab. 1) | n.r. | 3.002 GB | 300k steps, batch 7, ~80 GB on one GPU | Tab. 1; App. |
| MVSplat | 2403.14627 | **0.044 s** (encoder 0.043 + render 0.0015) | trained on A100; timing GPU not restated | 2 × 256² | H×W×K (1 per pixel) | **12.0 M** | n.r. | 0.65 GB (iLRM Tab. 15, RTX 4090 `[S]`) | 1×A100, 300k it | Tab. 1; §4.2 |
| DepthSplat | 2410.13862 | 0.050 s (ViT-S) → 0.079 s (ViT-L) | 1×A100 | 2 × 256² | 1 per pixel | 38 → 354 M | n.r. | 2.49 GB (iLRM `[S]`) | 4×GH200, 150k it, 1–2 days | Tab. 1; Tab. 7 |
| NoPoSplat | 2410.24207 | **0.015 s** (66 fps) | RTX 4090 | 2 × 256², unposed | n.r. | n.r. (ViT-L encoder p16 + ViT-B decoder) | n.r. | n.r. | 8×GH200, ~6 h | §4.4; App. A |
| **GS-LRM** | 2404.19702 | **~0.23 s** | 1×A100; FlashAttn-2 "for efficient training and inference"; BF16 stated for training only | 4×512² (objects) / 2×512×904 (scenes) | 1 per pixel | **300 M** (24 layers, d=1024, patch 8, ≤16k tokens) | n.r. | n.r. | 64×A100-40G, 2 d + 1 d | abstract; §4 |
| **Long-LRM** | 2410.12781 | **~1 s** | 1×A100-80G | 32 × 960×540 (~250k tokens before merging) | ~17 M before pruning (keeps top 40% + 10%) | 142 M | n.r. | n.r. (training: 53 GB at batch 1) | GPUs n.r.; 60k it @ batch 256 + 10k + 10k @ batch 64 | abstract; §3.3; Tab. 4 |
| **iLRM** | 2507.23277 | 0.025–0.028 s (2–8 views, 256², RTX 4090); 0.19–20.92 s (16–256 views, 540×960, H100 FA3) | as stated | see latency | 65,536–131,072 (decoupled from pixel count) | 171–185 M | per-op only (3.83 GFLOPs per cross-attention) | 1.22 GB (excludes rendering) | 8×H100 50k it / 8×4090 100k it | Tab. 1, 6, 13, 15 |
| AnySplat | 2505.23716 | 0.171 / 0.297 / 0.767 s (3/6/16 views); 1.4 / 2.7 / 4.1 s (32/48/64) | timing GPU n.r.; trained bf16 | ≤448 px long side (training; eval res n.r.) | voxelised, n.r. | **~886 M** | n.r. | n.r. | 16×A800, ~2 days | Tab. 1; impl. |
| **VGGT** (backbone of DGGT/ReconDrive/VGD/AnySplat) | 2503.11651 | backbone 0.04 s (1 frame) … 0.11 s (8) … 3.12 s (100) … 8.75 s (200); + 0.03 s & 0.2 GB per frame per DPT head | 1×H100, FlashAttn-3 | 336×518 | n/a (point maps) | **~1.2 B** | n.r. | 1.88 → 40.63 GB | 64×A100, 9 days, bf16 | Tab. 9; App. B |
| **BTimer** (dynamic, bullet-time) | 2412.03526 | **20 ms** (4×256²), **150 ms** (12×256²), **1.55 s** (12×512²) | 1×A100 | as stated | per-pixel (8×8×12 per patch token) | n.r. (24-block ViT) | n.r. | <10 GB | 32×A100 | §4 implementation |

## Scaling observations (latency vs views / resolution)

All `[P]` numbers. The ratios are `[derived]`.

1. **Full attention grows faster than the input.**
   - BTimer (A100): 4→12 views at 256² takes 20→150 ms (3× tokens, 7.5× time). 256²→512² at 12 views takes
     150 ms→1.55 s (4× tokens, 10.3× time).
   - VGGT backbone (H100, 336×518): 1→10 frames takes 0.04→0.14 s (overhead-bound). 10→100 frames takes 0.14→3.12 s
     (22×). 100→200 frames takes 3.12→8.75 s (2.8×). Memory is close to linear: 3.63 GB at 10 frames, 40.63 GB at 200.
   - Long-LRM's training ablation (per iteration, **not inference**): an all-transformer 307 M model takes 2.3 s
     (4 views × 256², batch 16), then 14.5 s (32 × 256², batch 4), then 50.5 s (32 × 512², batch 1). The 142 M hybrid
     takes 1.9 / 3.5 / 4.0 s, and 12.6 s at 32 × 960×540, where every other variant ran out of memory.
2. **Neighbour-limited and cost-volume models scale gently with views** (DL3DV 256×448): DepthSplat takes
   0.083 / 0.107 / 0.132 s for 2/4/6 views (top-2 neighbour attention). MVSplat takes 0.072 / 0.146 / 0.263 s.
3. **Linear-ish models at high view counts** (H100 FA3, 540×960, views 16/32/64/96/128/256):
   - Long-LRM: 0.5 / 0.84 / 2.08 / 3.90 / 6.39 s, then out of memory.
   - iLRM: 0.19 / 0.53 / 1.66 / 3.37 / 5.61 / 20.92 s.
4. **Volume-based driving model** (EVolSplat4D, RTX 5880):
   - 30/60/90/120 frames at 320×480: 1.24 / 1.29 / 1.40 / 1.58 s and 4.93 / 6.71 / 8.92 / 10.41 GB.
   - 320×480 / 480×720 / 640×960 / 960×1440: 1.29 / 1.49 / 1.62 / 1.88 s and 6.71 / 8.22 / 10.56 / 12.75 GB.

   The paper explains why: the Gaussian count is set by the voxel grid, not by the pixels. The catch is that it needs a
   depth prior and tracked boxes as input.
5. **Pose-free unposed models** (AnySplat): 0.171 s at 3 views, 0.767 s at 16, 4.1 s at 64. That is 4.5× the time for
   5.3× the views from 3→16, and 5.3× the time for 4× the views from 16→64.
6. **Model size matters less than token count at small inputs.** DepthSplat goes 38→354 M parameters and
   0.050→0.079 s. iLRM (185 M) beats MVSplat (12 M) at 0.027 s vs 0.047–0.048 s.
7. **Streaming window attention holds memory flat** (SLARM): 23 GB at every x, against 27→63 GB with full attention.
   Time is 1.05→1.65 s against 1.12→4.25 s.

## Dead ends `[measured]` — searched and not found

- **Whole-model FLOPs/MACs:** in none of the 27 papers read.
- **Inference VRAM:** none for STORM, DGGT or ReconDrive (only third-party figures for STORM and DrivingRecon).
- **No latency at all:**
  - DrivingRecon (2412.09043).
  - StreetForward (2603.19552), UniSplat (2511.04595) and PointForward (2605.11594): HTML text grepped for time,
    seconds, FPS and GPU.
  - EVolSplat: render FPS only, no reconstruction time.
- **Broken or incomplete arXiv HTML:**
  - DGGT's HTML breaks after §3.3, so the view ablation and the "Computation" appendix were read from the PDF.
  - ReconDrive's "All experiments run on H800 GPUs, requiring 8 GPU-days" appears only in the PDF.
- **DGGT's 4/8/16-view ablation** reports quality only, not latency.
- **GPU or axis missing in a timing table:**
  - Omni-Scene, AnySplat, pixelSplat and SLARM do not state which GPU the timing ran on.
  - SLARM's Fig. 5(d) x-axis is unlabelled.
- **VGD's baseline times** (MVSplat 1.39 s, pixelSplat 2.95 s, DrivingForward 0.63 s) are copied from DrivingForward's
  A6000 table, but VGD's own numbers are on an A100. That makes its "1.6× faster" a cross-GPU comparison.
- **Two sources disagree on pixelSplat's Gaussian count.** MVSplat says pixelSplat predicts 3 Gaussians per pixel;
  iLRM Tab. 1 lists 131,072 for 2×256² (1 per pixel). Unresolved.
- **Tesla's 220 ms** has no stated hardware, resolution, precision or Gaussian count (research/01). The table above
  cannot be mapped onto it exactly.

## Open questions

- What would DGGT, STORM and ReconDrive measure on our own 4090 at 8 cameras? Only a same-GPU benchmark removes the
  ±3× spread between measurers. Inference only, one job at a time.
- Whole-model FLOPs could be counted from the architectures (for example STORM's ViT-B at ~7k tokens, or GS-LRM's 24×1024
  at 16k tokens) with a FLOP counter or by hand. That is a separate derivation and was deliberately not done here.
- What precision were the timed runs in? Only STORM's batched run and VGD state bf16 at inference. fp16/int8 timings for any
  of these: none found.
- Is Tesla's figure for a training-cluster GPU or for in-car hardware? Not disclosed.

Sources: arxiv.org/html/{2501.00602, 2512.03004 (+PDF), 2409.12753, 2510.19578, 2510.24734, 2412.06273, 2603.07552
(+PDF), 2503.20168, 2601.15951, 2412.09043, 2410.20030, 2509.23402, 2512.03210, 2603.22893, 2603.19552, 2511.04595,
2605.11594, 2312.12337, 2403.14627, 2410.13862, 2410.24207, 2404.19702, 2410.12781, 2507.23277, 2505.23716,
2503.11651, 2412.03526}. READMEs: xiaomi-research/dggt, NVlabs/GaussianSTORM, fangzhou2000/DrivingForward,
TuojingAI/ReconDrive (+docs/TRAIN_EVAL.md), Miaosheng1/EVolSplat, Miaosheng1/EVolSplat4D, WU-CVGL/Omni-Scene,
EnVision-Research/DriveRecon, nv-tlabs/SCube.
