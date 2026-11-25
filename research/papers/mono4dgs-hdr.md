# Mono4DGS-HDR: HDR 4D Gaussian splatting from alternating-exposure monocular video

Researched 2026-11-25. Read: all of arXiv 2510.18489 **v2** (HTML, with appendix); the project page; the repo via the GitHub API
(README, install.sh, requirements.txt, configs, trainer and precompute code); the Hugging Face repo API. v1 has the same Table 1
and GPU line; v2 adds Tables 6–8, A.4, a third limitation and "exposure values read from camera metadata". Nothing was installed,
run or downloaded apart from the pages themselves.

Tags: `[primary]` = read in the paper (location given), on the project page, in the repo or from an API. `[secondary]` = a summary or
search snippet. `[UNCERTAIN]` = could not confirm. `[inference]` = my own reasoning or arithmetic. "Not stated" means I searched and
found nothing.

## 1. Citation

- **Title:** Mono4DGS-HDR: High Dynamic Range 4D Gaussian Splatting from Alternating-exposure Monocular Videos `[primary]`
- **Authors:** Jinfeng Liu and Dan Xu (HKUST); Lingtong Kong, Mi Zhou and Jinwei Chen (vivo Mobile Communication) `[primary: paper,
  project page]`. The arXiv metadata and the BibTeX spell the fourth author "Jinwen Chen" `[primary: arXiv API, BibTeX]`.
- **Venue:** ICLR 2026. The arXiv comment says "This paper is accepted by ICLR 2026" `[primary]`, and iclr.cc lists it as a poster `[secondary]`.
- **arXiv:** 2510.18489 (cs.CV). v1 21 Oct 2025, v2 1 Mar 2026 `[primary: arXiv API]`.
- **Project page:** https://liujf1226.github.io/Mono4DGS-HDR/ `[primary]`
- **Code:** https://github.com/LiuJF1226/Mono4DGS-HDR, MIT, released 2026-10-04 (status in §6) `[primary]`
- **Data + prior weights:** https://huggingface.co/jinfengliu26/Mono4DGS-HDR `[primary]`

## 2. The problem

The input is one handheld camera's video whose frames alternate between short and long exposures. The frames are ordinary 8-bit LDR
images and the camera poses are unknown. The goal is a dynamic 3D scene that stores true scene brightness (HDR) instead of
clipped pixel colours, so it can be re-rendered from new views, at new times and at any exposure. Two things make this hard:
- Existing unposed 4D methods (MoSca, SplineGS, GFlow) recover camera motion by assuming brightness stays constant between frames,
  and alternating exposures break that.
- Only the LDR frames supervise the HDR appearance, so it flickers over time (§1) `[primary]`.

## 3. How it works

**What each Gaussian stores** `[primary: §3.1, A.1.2, A.2.3]`

| Attribute | Static Gaussian | Dynamic Gaussian |
|---|---|---|
| position | 3 floats | cubic Hermite spline with one control point every N_s = 4 frames, 3 floats each |
| rotation | quaternion | cubic polynomial in t: 4 coefficients × 4 = 16 floats |
| scale, opacity | 3 + 1, constant over time | same, also constant |
| colour | 36-dim feature → colour MLP (1 hidden layer, 36 ch) → HDR irradiance e ≥ 0. No spherical harmonics | same |

- **Camera response (CRF):** three per-channel tone-mapper MLPs (1 hidden layer, 128 ch) map log(e·Δt) to an LDR value. They are
  applied to the rendered HDR image ("2D tone mapping", taken from GaussHDR) `[primary: §3.1, A.2.3]`. In the code the hidden layer
  uses softplus, the output a sigmoid, and the input is log2(H) + log2(Δt) `[primary: repo scene/tone_mapper.py, trainer_world.py]`.
- **Motion:** every dynamic Gaussian follows its own trajectory. There is no deformation MLP and no tracker box `[primary: §3.1]`.
  Whether colour depends on viewing direction: not stated.
- **Size per Gaussian** `[inference: arithmetic]`: in a 100-frame clip a dynamic Gaussian has 25 control points, so
  75 + 16 + 3 + 1 + 36 = 131 floats (≈ 0.5 KB in fp32). The count grows linearly with clip length.

**Pipeline** (`[primary]` unless tagged)
0. **Inputs.** Unposed monocular LDR frames cycling through 2 or 3 exposure levels. The exposure of every frame is known: "we use the
   known exposure values read from camera metadata". The CRF is unknown and learned (§3, A.3.4). In the repo each scene has an
   `exposures.json` with log2 exposure values (mosca_precompute.py). The intrinsics are unknown too (§3.3.2).
1. **2D priors** (§3.2, §4.1, A.2.3):
   - DepthCrafter: video depth.
   - SpatialTracker: long 2D tracks.
   - RAFT: optical flow, computed only between frames that share an exposure.
   - Epipolar-error maps from the flow, thresholded at 1e-5, give the dynamic masks.
   - **What the released code adds, not in the paper** `[primary: repo]`: every frame is exposure-normalised before it reaches the
     three models: linearised with gamma 2.2, divided by its exposure time, scaled to the mean exposure, re-encoded to 8 bit
     (`load_imgs_from_dir`). The video depth is also aligned to Metric3D metric depth (`align_metric_model: metric3d`).
2. **Bundle adjustment** (MoSca's), run on the static tracks. It gives the initial intrinsics and a pose for every frame (§3.2).
   The intrinsics are one shared focal length found by a field-of-view search (`iso_focal: True`, search 10–90) `[primary: configs/base_config.yaml]`.
3. **Stage 1: video Gaussians, 4K iterations** (§3.3.1, A.1.3, A.2.3).
   - All Gaussians are dynamic and live in an orthographic camera space: x, y are normalised pixel coordinates and z is depth.
   - Each tracklet, lifted with the prior depth, becomes one Gaussian.
   - Camera motion and object motion are both just Gaussian motion, so no poses are needed.
   - Result: an HDR version of the training video with consistent brightness.
4. **Video → world transform** (§3.3.2):
   - **Static or dynamic?** A Gaussian counts as dynamic if it falls inside the dynamic mask while unoccluded (checked against the
     rendered depth) in more than e.g. 10 % of frames.
   - **Move to world space** with the BA cameras. A static Gaussian gets the mean position and an averaged quaternion. A dynamic
     one gets a resampled spline and a least-squares fit of the rotation polynomial.
   - **Opacity and colour** are copied unchanged.
   - **Scale is re-fitted** so the projected 2D covariances match in every frame: 1,000 gradient steps, "1 minute".
5. **Stage 2: world Gaussians + camera poses, 11K iterations.**
   - The static and dynamic Gaussians are optimised jointly with the camera poses.
   - Every 2K steps, Gaussians wrongly marked dynamic are pruned (§3.3.3, A.2.3).
   - Test-frame poses are interpolated from the neighbouring frames (§4.1).

**Losses** `[primary: §3.3.3, A.1.4–A.1.6, A.2.3]`

| Loss | What it does | Weight |
|---|---|---|
| L_rgb | 0.8·L1 + 0.2·D-SSIM between the tone-mapped render and the input LDR frame | 1 |
| L_ue | unit exposure: φ(0) = 0.5 (real) / 0.73 (synthetic). Fixes the HDR scale (from HDR-NeRF) | 10 |
| L_dep | L1 to the prior depth | 1 |
| L_track | rendered flow vs RAFT at t ± N_e, or rendered track vs SpatialTracker (picked at random each iteration) | 0.01 |
| L_arap | keeps distances to the 5 nearest neighbours (as-rigid-as-possible) | 0.01 |
| L_vel, L_acc | smooth trajectories (from MoSca) | 10, 10 |
| **L_tlr** | temporal luminance regularisation, details below | 0.1 |
| L_pr (stage 2) | HDR reprojection: warp the stage-1 HDR frames (gradients stopped) with depth + poses, t′ ∈ {t±1, t±2}, static pixels only, same normalisation | 1 |

L_tlr warps the HDR render at t−1 to t with the **rendered** flow (gradients stopped) and takes
‖V ⊙ (H_warp − H_t)/(H_warp + H_t)‖₁, V masking occluded pixels; dividing by the sum removes the HDR scale. It starts after densification.

**In the repo but not in the paper's objective** `[primary: trainer_world.py l.2057, trainer_cam.py]`: a CRF-monotonicity term ×10,
a scale-variance term ×10, an opacity term, a depth term inside the reprojection loss, and a 1,000-step tone-mapper pre-fit
(RGB-equal + monotonic + unit exposure).

**Camera poses.** None are needed as input. MoSca-style BA provides the initial K and poses, and stage 2 refines the poses. The HDR
reprojection loss only works because stage 1 has already removed the exposure differences between frames (§1, §3.3.3) `[primary]`.
Whether the focal length is also refined in stage 2: not stated.

## 4. Numbers

| Quantity | Value | Source |
|---|---|---|
| Reconstruction ("Training time") | **1.5 h per scene**: the same as MoSca-HDR and SplineGS-HDR. GaussHDR and HDR-HexPlane: 1 h | Table 1 `[primary]` |
| …what the 1.5 h covers | 4K + 11K = 15K iterations. Whether preprocessing (DepthCrafter, SpatialTracker, RAFT, BA) is included: **not stated**. The code logs preprocessing time separately; the paper never reports it | A.2.3; repo mosca_precompute.py `[primary]` |
| Scale re-fit in the video → world step | ~1 min (1,000 gradient steps) | §3.3.2 `[primary]` |
| Render speed | **161 FPS at 864×480**. MoSca-HDR 82, SplineGS-HDR 79, GaussHDR 51, HDR-HexPlane 1 | Table 1 `[primary]` |
| …how the code times it | Times only HDR rasterisation + tone mapping. Trajectories are evaluated before the timer starts, and the timed block has no `torch.cuda.synchronize()`. The figure is probably optimistic `[inference]` | repo trainer_world.py `render_train` `[primary]` |
| GPU | "a single RTX 3090 GPU" (24 GB) for all experiments | A.2.3 `[primary]` |
| Peak memory | **not stated**. The only mention is a "storing memory" trade-off when choosing N_s (§4.3) | — |
| Gaussian count | **not stated**. The code stops stage-1 densification at 150,000 Gaussians and starts from up to 16,384 uniform + 16,384 dynamic tracks | repo trainer_cam.py l.429, configs/base_config.yaml `[primary]` |
| Clip size | 50–100 frames at 864×480 | §4.1, A.2.1 `[primary]` |

**Quality vs the strongest baseline** `[primary]`. That baseline is MoSca-HDR, the authors' own HDR adaptation of MoSca: same tone
mapper, all baselines trained for 15K iterations, posed baselines given the authors' BA cameras (§4.2). HDR metrics are computed
in the μ-law domain (§4.1).

| Benchmark | Mono4DGS-HDR | MoSca-HDR | Source |
|---|---|---|---|
| Syn-Exp-3 test: HDR PSNR / SSIM / LPIPS | 37.64 / 0.959 / 0.042 | 36.89 / 0.952 / 0.053 | Table 1 |
| Syn-Exp-3 test: LDR PSNR at the observed / novel exposures | 34.75 / 34.54 | 34.08 / 33.92 | Table 1 |
| Syn-Exp-3: HDR-TAE (flicker, lower is better) | 0.057 | 0.059 | Table 1 |
| Real-Exp-3 test: LDR PSNR / HDR-TAE | 27.65 / 0.067 | 27.23 / 0.076 | Table 2 |
| Real-Exp-2 (training frames): LDR PSNR / HDR-TAE | 31.82 / 0.046 | 30.28 / 0.054 | Table 2 |

**Exposure robustness** (Syn-Exp-3 test, HDR PSNR; 37.64 with exact exposures) `[primary]`:
- The 3 exposures in random order: 37.37. A random exposure for every frame: 37.42 (Table 6).
- Exposure metadata off by ±0.25 EV: 37.28. ±0.5 EV: 35.55. ±0.75 EV: 34.32 (Table 7).

**Ablations** `[primary]`:
- **No stage 1** (world Gaussians built straight from lifted tracks): Real-Exp-3 PSNR falls from 27.65 to 26.47 (Table 3).
- **No L_tlr:** PSNR barely moves, but HDR-TAE rises from 0.067 to 0.082 (real) and from 0.057 to 0.071 (synthetic) (Table 3).
- **No priors:** without the depth loss, HDR PSNR falls from 37.64 to 35.56; without the flow/track loss, to 35.05 (Table 8).

**Datasets** `[primary: §4.1, A.2.1, README]`. 25 short clips built from four HDR-video datasets (Kronander 2014, Froehlich 2014,
Kalantari 2013, Chen 2021):
- **Syn-Exp-3:** 9 scenes of ~100 frames, 3 exposures, with HDR ground truth. The "synthetic" part is that the LDR inputs are
  tone-mapped from HDR video with a fixed CRF (eq. 10).
- **Real-Exp-3:** 8 real alternating-exposure clips, 3 exposures, 50–60 frames, no HDR ground truth.
- **Real-Exp-2:** 8 real clips, 2 exposures, scored on the training frames.

**None is a driving dataset.** There is no Waymo, nuScenes, KITTI, Argoverse or PandaSet. A full-text search of v1 and v2 finds no
"driving", "vehicle", "street", "night" or "tunnel" `[primary]`. One synthetic scene is named `cars` `[primary: repo configs]`;
what it shows `[UNCERTAIN]`. At least one scene (Students_2) has a fixed camera `[primary: project page]`.

## 5. Limitations

**The authors' own** `[primary: A.5, failure cases in Fig. 15]`:
1. It depends on the depth, flow and track priors. Bad flow gives the wrong static/dynamic split.
2. It cannot handle blur from fast camera or object motion.
3. The as-rigid-as-possible (ARAP) loss rules out complex non-rigid motion; it fails on fire.

A.4 adds two more:
- Low-light frames are noisy, and RAW-domain methods (RawNeRF, LE3D) would suit them better.
- Reflective and transparent surfaces are not modelled.

**For our goal** (`[inference]` unless tagged):
- **One handheld camera, short clips.** 50–100 frames at 864×480 `[primary]`.
  - A 6–8 camera rig is calibrated and synchronised, and its poses come with the dataset.
  - So the pose-free machinery (stage 1, BA, L_pr) solves a problem we don't have.
  - Fusing several cameras is not addressed.
- **The car's own motion.** Flow is only computed between frames with the same exposure.
  - At 30 fps with 2 exposures those frames are 66.7 ms apart: the car travels 0.93 m at 50 km/h and 1.85 m at 100 km/h (arithmetic).
  - In stage 1 a Gaussian's size is fixed in normalised pixel units: scale is constant over time (§3.1 `[primary]`) and the
    projection is orthographic, so its on-screen size can change only by rotating.
  - Driving forward makes everything grow on screen, so expect stage 1 and the 2D-covariance re-fit to struggle.
- **Spotting movers.** The dynamic masks come from epipolar error `[primary]`. A car driving the same way as the ego car moves
  along the epipolar lines and produces little epipolar error, a known blind spot of this test.
- **Unbounded streets.** There is no sky or far-field representation and no LiDAR. It was never tested beyond small clips `[primary: datasets]`.
- **Night and glare.** These are where HDR matters, and where long exposures blur in a moving car, which is limitation 2 above.
  The input is 8-bit LDR `[primary: repo cv2.imread]`, with no raw path.
- **Offline by design.**
  - The video depth, the long tracks, BA and the splines all use the whole clip `[primary: §3.2]`.
  - 1.5 h per clip is about 24,500× Tesla's ~220 ms (arithmetic, different hardware and inputs).
- **Car cameras.** Automotive sensors usually make HDR inside one frame, using in-frame multi-exposure or split-pixel designs,
  rather than alternating exposures from frame to frame. Tesla also says its networks take raw sensor data.
  - Neither the paper nor its references discuss automotive capture `[primary: full-text search]`.
  - Its only remark on HDR hardware: scanline-exposure/ISO and beam-splitter cameras exist but are "often impractical" (§2) `[primary]`.

## 6. Fit for our goal

**Code, licence, weights** `[primary: GitHub API and HF API, read 2026-11-25]`:
- **Repo:** exists, MIT. Created 2025-10-21; code released 2026-10-04 (commit a5d0f37); last push 2026-10-04. 31 stars, 1 fork,
  1 open issue (from 2025-10-23, asking for Hugging Face artifacts). No GitHub releases.
- **Hugging Face repo** `jinfengliu26/Mono4DGS-HDR` (MIT tag, created 2026-10-04):
  - Preprocessed data, ~4.3 GB per the README.
  - Prior checkpoints, ~2.42 GB: RAFT, SpatialTracker, GMFlow, BootsTAPIR, DenseTrack3D, Video-Depth-Anything.
  - No trained scenes, since every scene is fitted from scratch.
- **Priors fetched at run time:**
  - DepthCrafter comes from `tencent/DepthCrafter` on top of `stabilityai/stable-video-diffusion-img2vid-xt` (fp16, with CPU
    offload of the model).
  - Metric3D comes via torch.hub.
  - The MIT licence covers only this repo. I did not check the prior models' licences.
- **Software stack:** Python 3.10, conda gcc/g++ 9 (Linux); **PyTorch 2.4.1 + CUDA 11.8**, pytorch3d, xformers, PyG wheels for
  torch-2.4.1+cu118, cupy-cuda11x, mmcv-full 1.7.2. **Five custom CUDA extensions** built by install.sh: four
  diff-gaussian-rasterization variants (alphadep, alphadep-add3, alphadep-cam, alphadep-cam-add3) and simple-knn.

**Roadmap stage** `[inference]`. A side-read for stage 6: an appearance add-on for Street Gaussians / OmniRe when exposure changes.
The idea carries into stage 7 as a feed-forward head that outputs HDR irradiance and takes exposure as an input.

**Would it run on the 5070 Ti 16 GB?**
- **Measured:** nothing. The paper used a 24 GB RTX 3090 and reports no memory `[primary]`. The config sizes the tracker's chunk
  for a "(24GB GPU)" and says to reduce it to save memory `[primary: base_config.yaml]`.
- **My inference:**
  - At 864×480 with at most ~150k stage-1 Gaussians, the optimisation itself probably fits in 16 GB.
  - The memory peaks are more likely in DepthCrafter (video diffusion) and SpatialTracker.
  - The real blocker is software. CUDA 11.8 cannot target sm_120, so all of these need a cu128 rebuild: torch, the five
    extensions (with TORCH_CUDA_ARCH_LIST=12.0), pytorch3d, xformers, PyG, cupy and mmcv-full 1.7.2. mmcv-full 1.7.2 on
    torch ≥ 2.7 is the most likely to fail `[UNCERTAIN]`.
  - The rented 4090 (sm_89, supported by CUDA 11.8) should run the pinned stack unchanged.
  - The M5 Mac cannot run it: the rasteriser and cupy need CUDA.

**The one idea worth borrowing** `[inference, built on the primary facts above]`:
- **The idea:** store HDR irradiance in every Gaussian; render each frame through a small learned log-domain tone mapper fed
  that frame's known exposure; pin the HDR scale with the unit-exposure loss (HDR-NeRF → GaussHDR lineage, §2 `[primary]`); add
  this paper's scale-free temporal luminance loss.
- **For a car:** one shared HDR world with one tone mapper per camera (or one shared CRF plus each frame's exposure and gain from
  metadata), so auto-exposure differences between the 8 cameras, and across tunnel entries and exits, stop fighting the fit.
- **The evidence that supports it** `[primary]`:
  - Giving every frame a random exposure costs only 0.22 dB of HDR PSNR (Table 6).
  - The exposure metadata needs to be accurate to about ±0.25 EV (Table 7).
- **If true HDR is the aim:** follow A.4's pointer to RAW-domain splatting (LE3D, a 3DGS method cited in A.4), which is closer to
  Tesla's raw-input claim.

**Verdict: useful idea.** Read §3.1, §3.3.3 (TLR), A.1.4 (unit exposure) and A.3.4, about 30 minutes, and don't run it.
- The exposure/tone-mapping module transfers cheaply to stage-6 driving reconstructions.
- The method itself is a monocular, handheld optimiser for alternating-exposure LDR video. It takes 1.5 h per clip, uses no driving
  data and has no path to realtime.

## 7. Dead ends

- **Preprocessing time** (DepthCrafter, SpatialTracker, RAFT, BA), and whether the 1.5 h includes it: not stated. The code logs
  it, but I ran nothing.
- **Peak VRAM and final Gaussian count:** not stated in the paper, the README or the configs.
- **How the baselines' FPS was measured:** not stated. So the 2× render-speed lead over MoSca-HDR is unverified `[UNCERTAIN]`,
  and the timing caveat in §4 applies to the paper's own number.
- **Paper vs code mismatches:** configs/base_config.yaml defaults to `frames_per_control_point: 2`, against N_s = 4 in the paper.
  The code also has the extra loss terms, the exposure-normalised inputs to the priors and the Metric3D alignment. Which settings
  produced the paper's tables `[UNCERTAIN]`.
- **Datasets:** which scene comes from which source dataset, and what the `cars` scene shows: not found.
- **Automotive HDR capture:** not discussed in the paper or its references. I did not search further, per the brief.
- **Licences** of DepthCrafter, Stable Video Diffusion, SpatialTracker, RAFT and Metric3D: not checked.
- **Reproduction:** nothing was reproduced. Every number above is the authors'.
