# Instant4D: 4D Gaussian Splatting in Minutes

Read 2026-11-25 for the TeslaRender goal (6–8 surround cameras → dynamic Gaussian world → realtime render).

**Sources.** arXiv 2510.01119v1 as HTML through the fetch tool, plus its PDF pages 7 and 13–16 viewed as page images;
the NeurIPS 2025 camera-ready PDF, pages 1–10 viewed as page images; the project page; `gh api` on the repo and raw
files of `Zhanpeng1202/Instant4D`; the RoDyGS paper (arXiv 2412.03077), whose table Instant4D's DyCheck baselines come
from. Nothing was installed or run.

**Tags.** [primary] = read in the paper, page, repo or API. [secondary] = a fetch-tool paraphrase or search snippet I
did not check against the source. [UNCERTAIN] = not confirmed. [inference] = my reasoning or arithmetic.

## Bottom line

- It is **per-scene optimisation of one monocular video**, not a feed-forward model [primary].
- The "minutes" split about evenly between preprocessing and fitting. On an A6000, an 82-frame 854×480 clip takes
  148.76 s of geometry recovery (MegaSaM depth and poses, plus 2.76 s of pruning) and 148.00 s of Gaussian fitting
  (Table A1) [primary rows; sums inference].
- The speed comes from a geometry-first initialisation, not a new motion model: back-project consistent depth,
  voxel-prune it (−92% memory), then fit 1,500–5,000 iterations without densification, using isotropic, RGB-only 4D
  Gaussians with the rotation fixed to identity [primary].
- With R = I, a Gaussian cannot move. Moving things become a flipbook of short-lived, static Gaussians. There are no
  velocities and no object identity [inference from Eq. 7 and the released code].
- It has no driving data, no multi-camera input, and only small, slow, short scenes. Verdict: **useful idea** for
  stage 6.

## 1. Citation

- **Title:** "Instant4D: 4D Gaussian Splatting in Minutes" [primary].
- **Authors:** Zhanpeng Luo (University of Pittsburgh), Haoxi Ran (Carnegie Mellon University; "Project Lead"),
  Li Lu (Sichuan University) [primary: camera-ready p. 1].
- **Venue:** NeurIPS 2025, Main Conference Track; DOI 10.52202/085713-1005 [primary: proceedings page].
- **arXiv:** 2510.01119, cs.CV, v1 submitted 1 Oct 2025 and still the only version; comment "Accepted by NeurIPS 25"
  [primary].
- **Project page:** https://instant4d.github.io/ [primary].
- **Code:** https://github.com/Zhanpeng1202/Instant4D (status in §6) [primary].

## 2. The problem

The input is a casual phone or web video with unknown cameras. The goal is a dynamic 3D scene that can be rendered from
nearby new viewpoints and times. Earlier methods take hours per clip, because they optimise camera poses, flow, tracks
or deformation networks jointly with the scene [primary §1]. Instant4D's aim is to get this down to minutes.

## 3. How it works

**What one Gaussian stores (paper §3.3)** [primary]: a 4D mean (x, y, z, t); one shared spatial scale s_xyz and one
temporal scale s_t; an opacity α; a 4×4 rotation R "fixed to the identity (R = I)"; a plain RGB colour; and a motion
attribute m. The paper says this "cuts the per-Gaussian parameter count by over 60%", without naming the baseline.

**Dropped from full 4DGS** (Yang et al., ICLR 2024, the representation it builds on) [primary]:
- the two quaternions of the 4D rotation (anisotropy);
- the 4D spherical-cylindrical-harmonic (SCH) colour;
- adaptive density control: pruning lets them "reduce the need of the densification stage" (§3.2), and the "Ours" row
  of Table 2 has no densification tick.

**Motion** [primary unless tagged]:
- The paper conditions the 4D Gaussian on time, μ_xyz|t = μ_1:3 + Σ_1:3,4 Σ_4,4⁻¹ (t − μ_4) (Eq. 7), and says this
  "encodes continuous motion without explicit trajectory storage".
- **Catch** [inference]: with R = I and a diagonal scale, Σ_1:3,4 = 0, so the conditioned mean never moves. Only the
  temporal opacity o_t = o·N(t; μ_4, s_t²) changes. The paper's line that dynamic Gaussians "change their position
  and scaling according to the deviation of timestamp t" contradicts its own R = I.
- The released code agrees with R = I: both quaternion groups are initialised to identity and get learning rate 0.0
  (`scene/gaussian_model.py` L368, L377). The spatial scale is one value repeated three times (L181–183).
- So a moving object is a stack of spatially fixed Gaussians seeded from each frame's depth, each alive for a few
  frames: dynamic s_t = 2/fps in arXiv v1, "k/fps" in the camera-ready; static s_t = the clip length (§4.1).
  The renderer drops Gaussians whose temporal weight is below 0.05 (`gaussian_renderer/__init__.py` L123).

**Pipeline** [primary unless tagged]:
1. **MegaSaM camera tracking.** DROID-SLAM's differentiable bundle adjustment, extended to dynamic video. Depth Anything
   initialises the depth and UniDepth the focal length. The outputs are camera-to-world poses, the focal length, and a
   per-frame motion-probability map at H/8×W/8 (§3.1, Fig. 2, App. B.2).
2. **Consistent video depth.** "An additional first-order optimization" (§3.2). In the code this is MegaSaM's
   `cvd_opt` with RAFT optical flow (`--w_grad 2.0 --w_normal 5.0`, `script/reconstruct.sh`).
3. **Motion mask.** Upsample the motion probability, apply an Otsu threshold, and add pseudo-frames at both ends of the
   clip to clean up boundary frames (§3.2). The released `script/prune.py` uses a fixed 0.5 threshold instead.
4. **Back-projection.** Every pixel of every frame goes to world space (Eq. 5). A 512×512, 4 s, 30 FPS clip "yields
   ∼30 M raw 3D points" (§3.2).
5. **Grid pruning.** The voxel edge is S_v = λ_s · mean_i(D̂_i / f̂). Each occupied voxel keeps one centroid, with
   colour, timestamp, s_t and motion probability averaged. Low-support voxels are dropped, and voxels are made larger
   in unbounded regions such as sky (§3.2).
   - Lite: λ_s = λ_d = 4. Full: λ_s = 1, with no pruning in dynamic regions (§4.1).
   - The released `prune.py` hard-codes factors 2 (static) and 0.5 (dynamic) instead.
6. **Fit.** 5,000 iterations on DyCheck and 1,500 on NVIDIA. Standard 3DGS hyper-parameters, except a position
   learning rate of 1e-5 and a 5,000-step schedule (§4.1).
7. **Render at time t.** Cull by temporal opacity, then splat with a CUDA rasterizer derived from 4DGS / Inria.

**Losses:** "only requires a single photometric loss" (App. A) [primary]. In the code this is
(1 − 0.2)·L1 + 0.2·(1 − SSIM) (`script/optimize.py` L138–140) [primary]. The code also has opacity-mask, rigidity
and motion terms, but they are weighted 0.0 in both configs I read (`dycheck/apple`, `nvidia/Balloon1`) [primary].
There is no depth or flow loss during the Gaussian fit [primary].

**Pretrained models it leans on** [primary]: MegaSaM (`megasam_final.pth`, 20.8 MB, shipped in the mega-sam repo);
Depth Anything ViT-L (`depth_anything_vitl14.pth`, though the arXiv reference list cites V2; the filename looks like V1
[inference]); UniDepth; RAFT (`raft-things.pth`). Not used: point tracking and SAM-style segmentation (App. B.2).
MonST3R and CUT3R were tried and dropped because they "struggle with frequently shifting point clouds when processing
a long sequence" (§4.2) [primary].

**Camera poses:** none are needed as input. MegaSaM estimates the extrinsics and the focal length from the monocular
video. On NVIDIA, the baselines marked * were re-run with visual SLAM instead of COLMAP [primary].

## 4. Numbers

**GPU:** "a single NVIDIA A6000" (§4.1, App. B.1) [primary]. The memory size is not stated.

| What | Number | Setting | Source |
|---|---|---|---|
| End-to-end, one clip | **295.76 s** printed (the rows sum to 296.76 s [inference]); the text says "finishes in 6 minutes" | A6000, 82 frames, 854×480 | arXiv App. B.1, Table A1 [primary] |
| ├ preprocessing | depth 23.98 s, camera tracking 23.47 s, video-depth optimisation 98.55 s, grid pruning 2.76 s → **148.76 s** [sum: inference] | same | Table A1 [primary] |
| └ Gaussian fit | forward 55.47 s + backward 92.53 s → **148.00 s** [sum: inference] | same | Table A1 [primary] |
| Preprocessing rate | "approximately 0.8 seconds per frame", "about 5 minutes" for the 379-frame "apple" (Full) | A6000 | §4.1 [primary] |
| DyCheck time | Lite **0.03 h**, Full **0.12 h** (7.2 min), described as "mean training time per scene" | GPU not restated (§4.1 times are on an A6000) | Table 3, §4.2 [primary]; whether this includes preprocessing: not stated [UNCERTAIN] |
| Lite "full training pipeline" | 96 s at 988 MB (235 frames); 131 s at 1,147 MB (379 frames) | A6000 | §4.1 [primary]. 988 MB is far below Table A1's 2,935 MB depth and 9,602 MB tracking peaks, so this almost certainly excludes preprocessing [inference] |
| NVIDIA time | 0.02 (unit not printed; hours fits the other rows [inference]); fit 42 s with pruning vs 181 s without; "in average 2 minutes" | GPU not stated | Table 1, Table 2, §1 [primary] |
| DAVIS clips | Bear (82 frames), Breakdance (68): "2 min for SLAM calibration and 2 min for 4D reconstruction" | not stated | §4.3 [primary] |
| Sora clips (5 s) | "around 5 minutes including preprocessing time" | not stated | project page [primary] |
| Render FPS | 822 @ 480×270 and 676 @ 860×480 (Table 1); 981 (Table 2, resolution not stated); ">400 Hz" (§4.1); ">500 FPS" (§4.2); **247 FPS @ 854×480** (App. B.1) | A6000 named only for B.1 | [primary]; 822 vs 981 on the same NVIDIA data is not reconciled |
| Peak memory | **9,602 MB** (camera tracking); 5,501 MB (video depth); 2,935 MB (depth); 3,878 MB (backward); "less than 4 GB" for the fit | A6000, 82 × 854×480 | Table A1, App. B.1 [primary] |
| Memory on DyCheck | Lite 1.1 GB, Full 8 GB ("peak GPU memory during optimization"); 4DGS (Wu) 21 GB, RoDynRF 15 GB, D-NeRF 12 GB | | Table 3 [primary] |
| Effect of pruning (NVIDIA) | memory 10,676 → 832 MB (−92%), fit 181 → 42 s, render 154 → 981 FPS, PSNR 23.38 → 23.99 dB | | Table 2, §3.2 [primary] |
| RGB vs 4D SCH | NVIDIA: SCH 23.83 dB, 59 s, 2,806 MB, 588 FPS vs RGB 23.99 dB, 42 s, 832 MB, 981 FPS. DyCheck: SCH costs 1.0 dB (24.52 → 23.52) | | Tables 2, 4 [primary] |
| Gaussian count | **Not reported.** Only "∼30 M raw 3D points" before pruning, and "reduces the number of Gaussians by 92%" (§1), backed only by the memory drop | | §1, §3.2 [primary] |
| DyCheck quality | Full **24.52 dB**, Lite 23.02 dB average PSNR (5 scenes). Best listed baseline: Deform3D 22.63 (GT poses). Best pose-free: RoDyGS 17.37 | | Table 3 [primary] |
| …the omitted baseline | 4DGS (Yang et al., GT poses) on the same 5 scenes: 27.31 / 25.09 / 26.81 / 26.30 / 21.11 → **25.32 dB**, 0.80 dB above Instant4D Full, and ahead on 4 of 5 scenes | | RoDyGS App. H [primary]; average [inference] |
| NVIDIA quality | **23.99 dB**, vs DynamicNeRF 26.10 (74 h), RoDynRF 25.89 (28 h) and Casual-FVS 24.57 (0.25 h). Best of the visual-SLAM group (InstantSplat* 22.56, 4DGS* 18.34) | | Table 1 [primary] |

**Datasets** [primary]: NVIDIA Dynamic Scenes (7 scenes, 12 frames from 12 viewpoints); DyCheck iPhone (5 of its 7
scenes: apple, block, paper-windmill, spin, teddy; RoDyGS protocol); DAVIS and Sora-generated clips (qualitative only).

**No driving dataset is used.** Waymo, nuScenes, KITTI, Argoverse and PandaSet do not appear [primary for the pages I
read; the full-text search was done by the fetch tool, so secondary]. The only outdoor remark is about "unbounded
regions (e.g., skies)" [primary].

**How to read the DyCheck numbers:**
- The RoDyGS protocol trains on camera 0 and tests on 12.5% of frames sampled from the same sequence [primary: RoDyGS
  App. A.2]. The first author confirms "they use 1/8 of total input image sequence for testing" and that "gaussian
  splatting is more of interpolating … rather than generating for unseen region" (issue #10) [primary].
- So these scores measure interpolation along the recorded path, not new viewpoints [inference].
- Only PSNR is reported; SSIM appears only in an ablation, and there is no LPIPS. Whether the metrics are masked is not
  stated [primary].

**Arithmetic slips** [inference]:
- D-NeRF's average is printed as 21.50, but its five per-scene values average 21.90.
- The isotropic ablation is "1.25 dB" in the text but 24.52 − 23.00 = 1.52 dB in Table 4.
- The "29% better than SOTA" claim matches (24.52 − 17.37) / 24.52, i.e. the gap divided by their own score.
- "30×" has no named baseline. App. A says "20× faster than RoDyGS", and Table 3 gives 8× (Full) to 33× (Lite) against
  RoDyGS's 1.0 h.

## 5. Limitations

**The authors' own** [primary §5, §4.3]:
- **Long videos.** SLAM keeps a depth map per frame, so memory grows linearly; "multi-minute scenes or continuous video
  streams" are out of reach.
- **Reflective or transparent surfaces.** Depth estimation becomes unstable.
- **Low texture.** In Kite-surf the ocean fills the view, the SLAM poses fail, and the surfer "occasionally disappears".

**What matters for our goal** [inference unless tagged]:
- **Does the speed carry over to long, fast driving clips? Partly.** The fitting speed-up (initialise from depth,
  prune, skip densification) should transfer. The preprocessing does not: it is monocular, and its memory grows
  linearly with frames. The flipbook representation cannot handle fast movers. Details below.
- **Monocular only.** MegaSaM tracks one camera and has no rig model. Six to eight cameras would mean either one run
  per camera (inconsistent worlds) or replacing MegaSaM with the dataset's calibrated poses. The second is easy on
  nuScenes or Waymo and removes the preprocessing half of Table A1, but what remains is then a fast 4DGS
  initialisation, not Instant4D's pipeline.
- **Ego-motion at 50–100 km/h** is 14–28 m/s, or 1.4–2.8 m between frames at 10 Hz. None of the evaluated datasets is
  a vehicle capture. Forward driving gives little parallax, which is the 3DGS weakness Tesla's own post names ("vehicle
  motion … is quite linear", research/06 [primary there]). MegaSaM is not tested on it here.
- **Large unbounded streets.**
  - There is one voxel size per clip, proportional to mean depth / focal. Street depth runs from ~2 m to the sky, so
    either near detail is over-pruned or far points are kept densely. Only the sky gets special handling (§3.2
    [primary]).
  - Point budget: ~30 M raw points for 512×512 × 120 frames. A hypothetical 20 s clip from 6 cameras at 10 Hz and
    1600×900 is 1,200 images and ~1.7 billion pixels, about 55× more before pruning.
- **Fast movers.** There is no velocity and no correspondence across frames. A car crossing at 20 m/s moves ~2 m
  between 10 Hz frames, so between frames it would cross-fade (ghost) rather than move. Rendering 60 FPS from 10 Hz
  input, or predicting ahead, is not possible. There is no object identity either, so cars cannot be moved or swapped
  the way Street Gaussians' box clouds can.
- **Run time.** Table A1 is ~3.6 s per frame end-to-end (296.76 s / 82). At 0.8–1.8 s per frame, preprocessing alone
  would take ~16–36 min for 1,200 images, if it ran on them at all. That is Street Gaussians territory (~30 min,
  research/06), and one small clip already takes ~1,350× Tesla's ~220 ms.

## 6. Fit for our goal

**Roadmap stage:** stage 6 (per-scene dynamic scenes), as a side read next to Street Gaussians and OmniRe; the
conditional 4D Gaussian maths also fits stage 2. Not stage 7: nothing is learned across scenes [inference].

**Code status** (gh api, 2026-11-25) [primary]:
- **Repo:** created 2025-09-19, last push 2025-11-13. 200 stars, 27 forks, 39 commits, 16 issues (6 open). No
  releases and no tags.
- **Licence: none.** The API returns `null`, `/license` returns 404, and the root has no LICENSE file, so default
  copyright applies, with no right to reuse [inference]. The vendored `diff-gaussian-rasterization` carries Inria's
  "free for non-commercial, research and evaluation use" header. The mega-sam submodule is Apache-2.0, but the
  UniDepth it runs is CC BY-NC 4.0.
- **Weights:** Instant4D has none to release, because each scene is optimised from scratch [inference]. The
  preprocessing checkpoints come from third parties (README, `reconstruct.sh`).
- **Custom CUDA:** the rasterizer (JIT-compiled on the first run through `torch.utils.cpp_extension.load`),
  simple-knn, fused-ssim, pointops2, torch-scatter, and MegaSaM's lietorch and correlation kernels.
- **Versions:** Python 3.10. Torch is installed from the cu126 index ("change to your CUDA version") with no version
  pinned. For PyTorch > 2.7, swap `.type()` → `.scalar_type()` in three MegaSaM CUDA files. UniDepth's xformers clashes
  with new PyTorch, so it needs a separate environment (README).
- **Health:** the code was missing at release (issues #3–#6, #9) and became "workable now" on 2025-10-30.
  - Today `optimize.py` L257 still calls `scene.render_evaluate_dycheck`, which `scene/__init__.py` does not define.
    With the default `--save_iterations 3000`, a run crashes at iteration 3,000.
  - There is no evaluation script (issue #12).
  - Two users report DAVIS quality below the paper's (issue #10).
  - No maintainer comment after 2025-11-13 in the issues I opened (#5, #10, #12, #13, #16).

**5070 Ti 16 GB:**
- **Measured:** nothing on a 5070 Ti and nothing by us. The paper's figures, all on one A6000: a 9,602 MB peak for
  82 frames at 854×480, a fit under 4 GB, and Lite 1.1 GB / Full 8 GB [primary].
- **Third-party:** issue #16 (2026-03-06) reports a full run on an RTX 5090 (sm_120) with PyTorch 2.10+cu128 after
  nine fixes. One fix adds "120" to MegaSaM's CUDA arch list [primary: issue text]. The outcome is not verified.
- **Inference:** a short clip (~80 frames at 854×480) should fit, given the 9.6 GB peak. Longer clips may not: SLAM
  memory grows with frame count, and nobody reports where 16 GB runs out. Every custom op must be rebuilt for sm_120
  (TORCH_CUDA_ARCH_LIST=12.0), and a few patches are needed before a run finishes. The Mac is out: everything is CUDA.

**The one idea worth borrowing: geometry-first initialisation with motion-aware lifetimes and no densification.**
1. Back-project depth from every frame with known poses. For driving, use the dataset's poses and LiDAR or mono depth
   instead of MegaSaM.
2. Voxel-downsample with a voxel size proportional to depth.
3. Give static points a whole-clip lifetime and dynamic points a lifetime of a few frames.
4. Fit a few thousand iterations without density control.

Their own ablation shows what this buys: 181 → 42 s, 10.7 → 0.83 GB and +0.61 dB (NVIDIA, Table 2) [primary]. Street
Gaussians already seeds from LiDAR with 0.15 m voxels, but still runs 30k iterations with density control
(research/06 [primary there]). Trying the short, densification-free schedule there is a cheap stage-6 experiment
[inference].

**Verdict: useful idea** — not must-read, not skip [inference]. It shows that a good point-cloud initialisation can
cut per-scene 4D fitting to a couple of minutes, and that preprocessing is half the wall-clock time. Everything else
misses our setting: monocular SLAM; a flipbook "motion" with no velocities; evaluation only on short, slow,
interpolation-style benchmarks; a missing strongest baseline; and minutes rather than milliseconds.

## 7. Dead ends

- **Gaussian count:** the absolute count after pruning is not in the paper, the project page or the README.
- **What the timings include:** whether Table 3's 0.03 h and 0.12 h include MegaSaM is not stated; only the Lite
  memory figure suggests they exclude it. The baseline behind "30×", and the GPU and resolution behind the Table 1 and
  Table 2 FPS, are not stated either.
- **Masked metrics:** whether the DyCheck PSNR is masked (mPSNR) is not stated in Instant4D, nor in the parts of RoDyGS
  I read.
- **Released configs do not match the paper** [primary]:
  - the NVIDIA config runs 5,000 iterations (paper: 1,500) with `sh_degree: 1` (paper: RGB);
  - densification is on (from iteration 500, every 100), where the paper's model has none;
  - the position learning rate is 1.6e-4 (paper: 1e-5);
  - the pruning factors are 2 / 0.5 (paper: λ = 4/4, or 1 / none);
  - the motion threshold is 0.5 (paper: Otsu).
- **Unanswered and unreproduced:** issue #15 (the train/test split) has no answer, the NVIDIA data link is reported
  dead (issue #13), and I found no independent reproduction of the paper's numbers.
- **Versions:** arXiv v1 and the camera-ready differ in at least one detail (dynamic s_t = 2/fps vs k/fps). The rest
  was not diffed.
- **Nothing was run.** There is no measured time or memory on our 4090, 5070 Ti or Mac.
