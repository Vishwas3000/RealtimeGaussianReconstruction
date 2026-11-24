# 08 — Measured cost of rendering Gaussian splats

Scope: how long it takes to draw a scene made of Gaussians: FPS against Gaussian count and resolution, Gaussian counts in
driving scenes, efficient/mobile/web/Apple-silicon renderers, per-stage cost and memory per Gaussian.
As of 2026-11-24. Light web research only: nothing downloaded, installed or run.
Tags: **[primary]** = read in the paper/repo/doc (table or section given); **[secondary]** = search snippet or summary,
not opened; **[UNCERTAIN]** = could not confirm; **[derived]** = my arithmetic on primary numbers.
arXiv IDs below were checked by title on the arXiv HTML/abs page (Street Gaussians in file 06).

## TL;DR

- **Anchor number:** stock 3DGS draws about **3 M Gaussians at the datasets' native ~1–1.6 MP in about 7.5 ms**
  (≈134 FPS) on an A5000/A6000-class GPU. About 60 % of that is the per-pixel blend, 30 % sorting and 10 % preprocessing
  (Speedy-Splat Table 1; FlashGS §6.3). Pruning to ~0.3 M brings it down to about 1.1 ms (≈900 FPS) at similar quality.
- **Cost tracks pixels × overlap more than raw count.** In gsplat, 49 M → 107 M Gaussians (tiled copies of one scene, many outside the view) at 1080p only drops 62 → 47 FPS
  (TITAN RTX, packed). Going 1080p → 4K slows stock 3DGS about 3× (FlashGS Table 1). Rendering N cameras costs about
  N× one camera: gsplat at batch 4 gives 46.1 FPS per image vs 171.8 FPS at batch 1, so batching gives no free speed-up.
- **Driving papers do not report Gaussian counts.** Street Gaussians, OmniRe, PVG, DrivingGaussian and S3Gaussian
  give none. Only FPS: Street Gaussians **135 FPS at 1066×1600 on one RTX 4090**, PVG 50 FPS (A6000). Feed-forward
  per-pixel models imply ~0.46 M (STORM) to ~1.35 M (DrivingForward, 6 cams) Gaussians per input [derived]. The
  closest street-level count: a 6-camera bike-helmet capture renders **2.3–21.6 M Gaussians per frame at 150–32 FPS** on an
  A6000 (Hierarchical 3DGS Table 5).
- **Apple silicon, measured:** **M4 Max, browser WebGPU, 1298×962: 1 M splats → 139 FPS, 10 M → 124 FPS, 35 M → 76 FPS**.
  WebGL2 on the same machine falls to 48 FPS at 10 M (PlayCanvas, 2026-06). **iPhone 13 Pro Max (WebGPU, 642×1126): 1 M → 78 FPS,
  4 M → 42 FPS.** No native-Metal render benchmark with a splat count was found.
- **Embedded is the wall:** stock 3DGS on Mip-NeRF360 (~3 M Gaussians) runs at **20.8 FPS on Jetson AGX Orin** and 3.1 FPS on
  Orin NX (Seele Table 1/3). It runs at 8 FPS cold and 3 FPS once thermally throttled on a Snapdragon 8 Gen 3 phone (Mobile-GS Table 2/12).
  Mobile-GS (~0.47 M Gaussians) reaches 116–127 FPS on that phone, or 74 FPS once throttled.

## Render measurements

FPS = frames per second for one view unless noted. "n.r." = not reported in the source.

| Method / renderer | Device | Resolution | # Gaussians | FPS (ms) | Source |
|---|---|---|---|---|---|
| 3DGS (official CUDA), Mip-NeRF360 avg | A6000 | "native input resolution" (§7.2; not given numerically) | 3.36 M avg (count from Mini-Splatting T1) | 134 (≈7.5) ; 734 MB | 2308.04079 Table 1, §7.2 [primary] |
| 3DGS, Tanks&Temples / Deep Blending | A6000 | native | 1.78 M / 2.98 M (Mini-Splatting T1) | 154 / 137 | 2308.04079 T1 [primary] |
| 3DGS, synthetic (NeRF-synthetic) | — | — | 200–500 K per scene | n.r. | 2308.04079 §7.2 [primary] |
| 3DGS baseline, 13-scene avg | RTX A5000 | n.r. | 2.93 M avg | 134 (7.48 ms) | Speedy-Splat 2412.00578 Table 1–2 [primary] |
| 3DGS baseline, bicycle (largest) | RTX A5000 | n.r. | n.r. per scene | 71 (14.0 ms) | 2412.00578 Table 8/12 [primary] |
| Speedy-Splat (pruned), 13-scene avg | RTX A5000 | n.r. | 0.28 M | 898 (1.11 ms) | 2412.00578 Table 1–2 [primary] |
| 3DGS, Mip-NeRF360 outdoor / indoor | RTX 3090 [UNCERTAIN: caption names the training GPU] | n.r. | 4.86 M / 1.46 M | 98 / 151 | Mini-Splatting 2403.14166 Table 2 [primary] |
| Mini-Splatting, Mip-NeRF360 out/in | same | n.r. | ~0.49 M avg | 410 / 362 | 2403.14166 Table 1–2 [primary] |
| 3DGS* retrained → LightGaussian, Mip-NeRF360 | A6000 | n.r. | n.r. (782 MB → 45 MB) | 144 → 237 | LightGaussian 2311.17245 Table 1 [primary] |
| 3DGS → FlashGS, Truck | RTX 3090 | 1080p / 4K | n.r. | 8.21 → 2.22 ms / 24.19 → 3.46 ms | FlashGS 2408.07967 Table 1 [primary] |
| 3DGS → FlashGS, MatrixCity (city-scale synthetic) | RTX 3090 | 1080p / 4K | n.r. (56 M tile-key pairs at one 4K frame) | 20.9 → 3.22 ms / 66.6 (max 140.5) → 4.90 ms | 2408.07967 Table 1–2 [primary] |
| gsplat v1.0.0, tiled test scene (scene_grid 5), fwd only | TITAN RTX 24 GB | 1080p (script at commit 8ea2ea3) | n.r. | 171.8 ; batch 4 → **46.1 per image** | gsplat `docs/source/tests/profile.rst` [primary] |
| gsplat v1.0.0, tiled large scenes, fwd | TITAN RTX | 1080p | **49 M / 107 M** | 62.1 / 47.3 (packed) ; official 3DGS rasterizer OOMs at 107 M | same [primary] |
| gsplat v1.5.3 (ROCm), same tiled scenes | AMD MI300X | n.r. | 49 M / 107 M | 179 / 135 | rocm.docs.amd.com gsplat profiling page [primary] |
| Hierarchical 3DGS, street capture (SmallCity) | A6000 | n.r. (captured 1444×1080) | 9.44 / 5.64 / 2.26 M rendered per frame | 46 / 78 / 150 | 2406.12080 Table 5 [primary] |
| Hierarchical 3DGS, Campus / BigCity (τ=3 px) | A6000 | n.r. | 21.6 M / 17.6 M | 32 / 31 | 2406.12080 Table 5 [primary] |
| 3DGS → LODGE, SmallCity | A100 40 GB | n.r. | 1375 K → 877 K loaded | 85 → 257 | LODGE 2505.23158 Table 1 [primary] |
| **Street Gaussians**, Waymo, 1 front cam | **RTX 4090** | **1066×1600** | n.r. | **135** | 2401.01339 abstract [primary] |
| StreetGS / PVG / DeSiRe-GS / PAGS, Waymo 3 front cams | RTX 4090 | n.r. | n.r. (853 / 959 / 984 / 530 MB) | 136 / 52 / 36 / 353 | PAGS 2510.12282 Table 1–2 [primary] |
| PVG, Waymo 3 cams / 5 cams | A6000 | n.r. (Table 4 uses 960×640 → 70.4 FPS) | n.r. | 50 / 41 | 2311.18561 Table 1, 4 [primary] |
| DrivingGaussian, nuScenes 6 cams | n.r. | 1600×900 | n.r. | **0.965 s per frame** | 2312.07920 Supp. Table 5 [primary] |
| Game-engine 3DGS (animated / static) | RTX 4090 | 1920×1080 | 3.45 M / 0.58 M | 44.8 / 58.8 (static); 38.9 / 49.6 animated | "Splats under Pressure" 2604.07177 Table 2 [primary]; lower GPU tiers were *emulated* on the 4090 |
| 3DGS / Seele, Mip-NeRF360 avg | **Jetson AGX Orin** | n.r. | n.r. (~3 M typical; 710 MB) | **20.8 → 59.7** | Seele 2503.05168 Table 1 [primary; device attribution from §4.1] |
| 3DGS / Seele, T&T, Deep Blending | Jetson AGX Orin | n.r. | n.r. | 42.0 → 127.8 ; 23.9 → 86.6 | same [primary] |
| 3DGS / Seele, Mip-NeRF360 | Jetson Orin NX | n.r. | n.r. | 3.06 → 9.42 | 2503.05168 Table 3 [primary] |
| 3DGS* (quantised) / Mobile-GS | Snapdragon 8 Gen 3 phone (model not named), Vulkan | Bicycle 1600×1063 (Fig. 1) | Mobile-GS ~0.47 M (dataset n.r.) | 3DGS 8 cold / 3 throttled ; Mobile-GS 116–127 cold / 74 throttled | Mobile-GS 2603.11531 Fig. 1, Table 2, 12 [primary] |
| **PlayCanvas engine, WebGPU / WebGL2** | **Apple M4 Max** | 1298×962 | 1 / 4 / 10 / 20 / 35 M | WebGPU 139 / 146 / 124 / 98 / 76 ; WebGL2 137 / 114 / 48 / 22 / 13 | blog.playcanvas.com, 2026-06-03 [primary] |
| PlayCanvas engine, WebGPU / WebGL2 | **iPhone 13 Pro Max** | 642×1126 | 1 / 2 / 3 / 4 M | WebGPU 78 / 73 / 53 / 42 ; WebGL2 38 / 36 / 26 / 20 | same [primary] |
| GaussianSplats3D (three.js), 3DGS scene | MacBook Air M3 / iPhone 15 Pro / iPhone 13 mini / Chromebook | n.r. | n.r. | 38 / 38 / 43 / 22 (raster only; sort 8–15 ms async) | LODGE 2505.23158 Table 4 [primary; table layout partly garbled] |
| Qualcomm avatar 3DGS renderer | Snapdragon XR2 Gen 2 / 8 Elite | 512×512 UV map | n.r. | 8.85 ms / 7.04 ms | Qualcomm developer blog 2024-12 [secondary] |

## Gaussian counts in driving scenes

| Method | Final count | What *is* reported | Source |
|---|---|---|---|
| Street Gaussians (2401.01339) | **not reported** | LiDAR voxelised at 0.15 m + SfM seed; small cars topped up to 8 K random points; 92 B per background Gaussian, 284 B per car Gaussian [derived] | file 06 [primary] |
| OmniRe / drivestudio (2408.16760) | **not reported** (paper and drivestudio issues) | 1×RTX 4090, ~1 h/scene; Waymo 3 front cams at 640×960; "~60 Hz" simulation claim, no FPS | paper App. A, §5 [primary]; issues #20/#45 searched |
| PVG (2311.18561) | **not reported** | init 0.6 M LiDAR + 0.2 M near + 0.2 M far = 1.0 M | §4 impl. details [primary] |
| DrivingGaussian (2312.07920) | **not reported** | LiDAR init 600 K / 1 M / 2 M (Table 3); 3000 initial points per dynamic object | §4.2 [primary] |
| S3Gaussian (2405.20323) | **not reported** (no FPS, no GPU either) | 640×960, 3 front cams | App. A.1 [primary] |
| PAGS table (2510.12282) | not reported | model size StreetGS 853 MB, PVG 959 MB. That implies ~1–9 M Gaussians depending on bytes per Gaussian and whether the file holds optimizer state [derived, UNCERTAIN]. PAGS "52.4M" ablation entry is ambiguous | Table 2, 4 [primary] |
| STORM (2501.00602), feed-forward | per-pixel, total n.r. | 160×240 × 3 cams × 4 frames = **460,800** per-pixel Gaussians [derived]; latent variant ~7 K tokens | §3.1, §4, §5 [primary] |
| DrivingForward (2409.12753), feed-forward | per-pixel, total n.r. | 6 cams × 352×640 = **1.35 M** per sample [derived]; 0.29–0.63 s inference, A6000 | §3.1, §4.1, Table 2–3 [primary] |
| Hierarchical 3DGS street capture (bike helmet, 6 GoPros; not a car) | 2–8 M leaf Gaussians per chunk; 2.3–21.6 M drawn per frame | closest public "street-level, multi-camera" count | 2406.12080 §6 capture, Table 5 [primary] |

Rule of thumb from the above [derived]: a per-scene driving reconstruction is in the **low millions** (1–10 M), the same
order as a Mip-NeRF360 scene. A feed-forward surround model makes **~0.5–1.5 M per input**, scaling with pixels × cameras.

## Per-frame cost breakdown and memory

- **Stage split (stock 3DGS, CUDA)**, Speedy-Splat Table 1, RTX A5000, 13-scene average: preprocess 0.665 ms (9 %),
  sort-related 2.248 ms (30 %: duplicate-with-keys 0.570 + radix sort 1.551 + misc), render/blend 4.483 ms (61 %), overall
  7.478 ms [primary; grouping is mine]. FlashGS Fig. 13 averages: preprocess 13.2 %, sort 25.4 %, render 59.6 % [primary].
  Seele: rasterisation ">67 %" on an Ampere GPU [primary]. GSCore talk: sort + raster >80 % on an edge GPU [secondary].
- **Mobile power by stage** (Snapdragon 8 Gen 3, Trepn profiler, watts not ms): 3DGS preprocess 1.64, sort 2.09, raster
  2.16, total 5.89 W. Mobile-GS uses 0.83 W in total (Mobile-GS Table 13) [primary].
- **Web renderers (WebGL quad-based):** PlayCanvas docs call **fill rate / overdraw the primary bottleneck** and say every
  splat is depth-sorted each frame. Spark docs say per-splat transform + sort overhead bites around 1 M splats on some
  systems, and high DPI and MSAA multiply cost [primary: developer.playcanvas.com performance page; sparkjs.dev/docs/performance].
- **Memory per Gaussian:** 3DGS = 3 pos + 3 scale + 4 quat + 1 opacity + 48 SH (degree 3) = 59 fp32 = **236 B** [derived].
  This checks out: 734 MB / 3.36 M ≈ 218 B [derived]. With SH degree 1 it is 92 B (Street Gaussians background). Hierarchical 3DGS: 284 B
  in theory, **400 B** as implemented (2406.12080) [primary]. Extra rasteriser scratch: **30–500 MB** depending on scene size
  and resolution (3DGS §7.4) [primary]. A city-scale 4K frame makes 56 M tile-key pairs and 13.45 GB "after rendering"
  for stock 3DGS, vs 6.83 GB for FlashGS (FlashGS Table 2, A100) [primary].
- **Storage vs runtime:** compressed files (LightGaussian 45 MB, Mobile-GS 4.6 MB, SPZ/SOG) shrink download size, but
  most viewers decompress to full per-splat buffers on the GPU. No source gives bytes per splat on the GPU for Spark or PlayCanvas [UNCERTAIN].

## Mobile / Mac / web notes

- **Published budgets (vendor docs, not benchmarks)** [primary]: Spark: Quest 3 ≤1 M, Android 1–2 M, iPhone 1–3 M,
  computer 1–5 M (10–20 M+ on some desktops). LoD defaults 1.5 M desktop / 500 K mobile (docs page marked work-in-progress).
  PlayCanvas: ~1 M mobile, ≥3 M desktop; SuperSplat streaming default 1 M on mobile/XR, 2 M desktop.
- **WebGPU vs WebGL2 matters most at high counts.** On the M4 Max the two are equal at 1–2 M, but WebGPU is 2.6× faster at
  10 M and 5.7× at 35 M. On iPhone 13 Pro Max WebGPU is ~2× faster at every count (PlayCanvas blog) [primary].
- **LODGE** measured phones and laptops through mkkellogg GaussianSplats3D. The sort runs asynchronously in 5–15 ms, and
  raster runs at 22–43 FPS. The non-LoD Hierarchical-3DGS baseline fails on iPhones and gets 7 FPS on the M3 [primary].
- **Brush** (Rust + WebGPU, Apache-2.0) claims rendering is "generally faster than gsplat" and ships `cargo bench`
  kernels, but publishes no numbers [primary: README]. **MetalSplatter** (MIT, 726★, last push 2026-09-02) is
  native Metal on iOS/macOS/visionOS and also publishes no FPS [primary: README].
- **Implication for this project [derived]:** one viewer screen at 60 fps is easy on the 16 GB Mac for a 1–10 M splat
  driving scene in a WebGPU viewer (Spark/PlayCanvas/Brush). Eight car cameras at 30 fps means 240 renders/s, so each
  render must take ≤4.2 ms. That is reachable on an RTX 4090 at ~1 MP after pruning or lowering resolution: Street Gaussians is
  ~7.4 ms per 1.7 MP view, which gives ~17 Hz for 8 cams if cost is linear. On Jetson Orin-class hardware it is far out of reach for stock 3DGS
  (8 × 48 ms).

## Dead ends

- Original 3DGS gives no per-scene Gaussian table and no numeric render resolution for Table 1 (only "native input"
  and the 1080p claim in the abstract). It has no per-stage render timing either.
- The gsplat paper (2409.06765) reports only training time and memory: no FPS, no batched-camera benchmark. The rendering
  numbers come from the repo's `profile.rst`, which does not state the Gaussian count for its small test scene.
- No driving paper (Street Gaussians, OmniRe, PVG, DrivingGaussian, S3Gaussian, PAGS baselines) reports final Gaussian
  counts. drivestudio GitHub issues don't either (searched "gaussians").
- LS-Gaussian (2507.21572) gives Orin FPS only as bar charts (speed-up 5.41× in text). The fragment-pruning NeurIPS 2024
  paper (Orin NX, 1.71×) was only seen in a snippet. GSCore's Orin/Xavier stage split was found only in talk slides.
- No native-Metal (non-browser) splat render benchmark with a splat count on any M-series chip. `ghif/splat-apple`
  benchmarks *training* it/s on a 10 K-Gaussian scene, and a Smithery "8–12 M on M1–M3" claim has no source.
- Mobile-GS's tables disagree with each other (116 vs 127 FPS, 4.6 vs 4.8 MB) and never name the phone. Seele and
  LightGaussian also have text-vs-table mismatches (flagged in the source extractions).
- ZipSplat (2606.05102: 2.0 M Gaussians at 252×252 → 40 FPS on a 4090, snippet only) was not opened or verified.

## Open questions (measure on our own hardware, one job at a time)

1. Real Gaussian count and render ms of one OmniRe/Street Gaussians Waymo scene on the 4090. Counting checkpoint rows is cheap.
2. Per-camera cost for 6–8 surround cameras of one scene with gsplat batching. Does frustum culling make it sub-linear?
3. Spark vs PlayCanvas vs Brush on this 16 GB Mac (Safari/Chrome WebGPU) at 1, 3 and 10 M splats and at 1–2 MP.
4. How much of the 30 % sort cost can be shared or reused across nearby cameras and consecutive frames (LS-Gaussian
   and the asynchronous sorting in GaussianSplats3D suggest a lot).
