# 13 — Models that may beat OmniRe, and the first one run (SplatAD)

Date: 2026-11-26/27. Trust tags as in the index: `[P]` read at the primary source, `[U]` unconfirmed, `[measured]` run by
us. Paper numbers below were read verbatim from arXiv HTML by reading agents, which flagged where a page summary
disagreed with the verbatim text. Only verbatim numbers are used.

## TL;DR

- **The owner's asks (2026-11-26), in order:**
  - "try other models";
  - "that will likely perform better then this mniRe";
  - "look inot all the papers before making the decissions";
  - "do one at a time. just load one model and run for the scene generation".
- **SplatAD was picked and run (D-016).** It is the only candidate with a like-for-like nuScenes comparison against
  OmniRe (+2.04 dB, 6 cameras), and its code reads nuScenes directly.
- **The result on our scene** (scene-0061, front camera, 800×450): held-out PSNR **30.2 dB**, against OmniRe's
  23.3 dB. Training-frame PSNR is the same for both (33.7).
  - The two runs held out different frames, so the 6.9 dB difference is not like-for-like.
  - The train-to-held-out gap (**3.5 vs 10.4 dB**) does not depend on which frames were held out. It is the fairer
    signal.
- **The wider survey was stopped** when the owner asked for one thing at a time. What it did not reach is listed at the
  end.

## Paper numbers `[P]`

**SplatAD** (arXiv 2411.16816, CVPR 2025). Table 1, image novel-view synthesis. Settings: 6 cameras (7 on Argoverse 2),
full resolution, every other frame held out, LiDAR used by all methods, 10 sequences per dataset. Baselines are run with
the official drivestudio code.

| PSNR / SSIM / LPIPS | PandaSet | Argoverse 2 | nuScenes |
|---|---|---|---|
| PVG | 24.01 / 0.712 / 0.452 | 24.47 / 0.712 / 0.502 | 24.94 / 0.768 / 0.497 |
| Street Gaussians | 24.73 / 0.745 / 0.314 | 25.52 / 0.754 / 0.374 | 25.54 / 0.799 / 0.375 |
| OmniRe | 24.71 / 0.745 / 0.315 | 25.61 / 0.753 / 0.375 | 25.50 / 0.798 / 0.386 |
| NeuRAD | 25.80 / 0.753 / 0.250 | 26.18 / 0.721 / 0.310 | 26.17 / 0.790 / 0.312 |
| **SplatAD** | **26.76 / 0.815 / 0.193** | **28.42 / 0.826 / 0.270** | **27.54 / 0.849 / 0.302** |

- Training time (Table 1): SplatAD 1.2 h on nuScenes against OmniRe's 1.9 h, on one A100.
- The paper gives no Argoverse 2 LiDAR results for the drivestudio baselines, because drivestudio's memory needs did not
  scale well with more images at higher resolution.

**BézierGS** (arXiv 2506.22099). Table 1, held-out views (every 4th frame), 30k steps on one RTX A6000.

| NVS PSNR / SSIM / LPIPS | Waymo | nuPlan |
|---|---|---|
| DeformableGS | 29.52 / 0.889 / 0.100 | 26.20 / 0.824 / 0.159 |
| Street Gaussians | 28.92 / 0.877 / 0.110 | 25.76 / 0.788 / 0.185 |
| OmniRe | 29.41 / 0.884 / 0.101 | 26.01 / 0.819 / 0.173 |
| PVG | 29.64 / 0.864 / 0.179 | 26.38 / 0.772 / 0.222 |
| **BézierGS** | **31.51 / 0.903 / 0.092** | **29.42 / 0.860 / 0.133** |

- Code: MIT. Its scripts are Waymo-only, and it pins torch 2.0.1.
- It needs masks of moving objects, made from 3D boxes or a tracker plus Grounded-SAM.
- Its cost table (Table 3) was read only from a page summary `[U]`.

**Difix3D+** (arXiv 2503.01774, NVIDIA). A one-step diffusion model that repairs renders of another reconstruction. It is
not a reconstruction method itself.
- Driving data (in-house RDS, Table 3): Nerfacto 19.95 → 21.75 PSNR, LPIPS 0.530 → 0.402.
- Licence: NVIDIA, non-commercial. The model card says to use its successor, Fixer.

**drivestudio's other methods** (Street Gaussians, PVG, DeformableGS) land within ±0.6 dB of OmniRe on held-out views in
both tables above; some are slightly above it. None looks like a clear win.

## Our run: scene-0061, front camera only `[measured]`

| | OmniRe (drivestudio, D-012 M1) | SplatAD (neurad-studio 0d14d8e) |
|---|---|---|
| Frames used | 10 Hz, 191; every 10th held out (19) | 12 Hz, 224; 10% held out, evenly spaced (22) |
| Resolution / steps / inputs | 800×450 / 30,000 / LiDAR + 3D boxes | 800×450 / 30,001 / LiDAR + 3D boxes |
| Training time, RTX 5090 (shared) | 28 min 11 s | 74 min, including its periodic evaluations and LiDAR rendering |
| Training-frame PSNR, last step | 33.7 | 33.7 |
| **Held-out PSNR / SSIM / LPIPS** | **23.25 / 0.661 / 0.151** | **30.18 / 0.899 / 0.128** |
| Train-to-held-out gap | 10.4 dB | 3.5 dB |
| Splats | 1.23 M | 5.0 M (its cap, reached by step 2,500) |
| Checkpoint | 380 MB | 1.65 GB, including optimiser state |
| Lane shift | not measured | FID 148 at 2 m, 184 at 3 m, against 37 unshifted (its own evaluation) |

- **Check:** PSNR recomputed by us from the 22 saved held-out JPEGs is 30.15 (range 27.21–33.18). That matches
  `ns-eval`'s 30.18.
- **Looking at the renders:**
  - Held-out frames are close to the real ones; the lettering on a truck is legible.
  - 2 m to the right, the road, barriers and buildings hold together, but there are visible tears: the excavator breaks
    into fragments, and the road and barriers smear near the image edge.
- **Not like-for-like yet:**
  - the held-out frames differ (12 vs 10 Hz, different indices);
  - each codebase treats per-frame corrections on held-out frames its own way.
  - A same-frames evaluation has not been done.
- **Gotchas found:**
  - neurad-studio's `ns-eval` always overwrites the saved dataset path with `--data-root-path`, even when that option is
    unset (`nerfstudio/scripts/eval.py` line 70). So pass it.
  - The conda CUDA 12.8 toolkit keeps its headers under `targets/x86_64-linux/include`, and neurad-studio's setup
    script overwrites `CPATH`. So `recon/splatad_env.sh` uses `CPLUS_INCLUDE_PATH` instead.
  - `ns-render dataset --shift` is in the camera's axes (x = right). `ns-render interpolate --shift` is in world axes.

## Not yet checked (survey stopped 2026-11-26)

- **Per-scene:** AD-GS, DeSiRe-GS (no licence, per research/04), OG-Gaussian (occupancy instead of LiDAR, so
  camera-only), CoDa-4DGS, UniGaussian, MTGS, 3DGUT / NVIDIA NuRec, and any 2026 methods.
- **Generative repair:** Fixer (Difix's successor), StreetCrafter, ReconDreamer / ReconDreamer++, DriveDreamer4D,
  FreeVS.
- **Camera-only geometry priors** for pseudo-LiDAR on phone video: depth models and pose models.
- **Feed-forward update** of research/04 section B: DGGT, ReconDrive, EVolSplat4D, STORM, AnySplat, Depth Anything 3.
