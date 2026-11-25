# Papers the owner sent: 4D Gaussian splatting

Synthesis written 2026-11-25. The owner sent four papers as "good reads for building our goal" (surround cameras → a
dynamic Gaussian world → realtime render). Four agents each read one paper in full, plus its project page and code. The
lead session then re-checked the key numbers against the raw arXiv HTML, and the code and weights through the GitHub and
Hugging Face APIs `[measured]` (log at the end). Nothing was installed or run.

| File | Paper | Kind |
|---|---|---|
| [feedforward-4d-global-motion.md](feedforward-4d-global-motion.md) | **T4GS** (arXiv title "Learning Global Motion with Compact Gaussians for Feed-Forward 4D Reconstruction", first called C4G). KAIST + Sony, arXiv 2605.31595, May 2026 | feed-forward |
| [rigs.md](rigs.md) | **RiGS**: Rigid-aware 4D Gaussian Splatting from a Single Monocular Video. Harvard, arXiv 2605.23672, May 2026 | per-scene fit |
| [instant4d.md](instant4d.md) | **Instant4D**: 4D Gaussian Splatting in Minutes. NeurIPS 2025, arXiv 2510.01119 | per-scene fit |
| [mono4dgs-hdr.md](mono4dgs-hdr.md) | **Mono4DGS-HDR**: HDR 4D Gaussian Splatting from Alternating-exposure Monocular Videos. ICLR 2026, arXiv 2510.18489 | per-scene fit |

## Answer

**They are good reads, but none of them is a pipeline to build on.**
- All four take **one handheld camera**, and none of them reconstructs **driving** data.
- Three optimise each scene for minutes to hours.
- The only feed-forward one, T4GS, reports **no speed at all**.

Each paper has **one idea worth taking**, and those ideas slot into stages 6 and 7 of the roadmap. For the realtime build
itself, STORM, DGGT and VGD (research/07) remain the closest open baselines.

## Side by side `[measured]` unless tagged

| | T4GS | RiGS | Instant4D | Mono4DGS-HDR |
|---|---|---|---|---|
| Input | 1 camera, 16–32 frames, 224×224, no poses | 1 camera video | 1 camera video | 1 camera, exposure alternates frame to frame |
| How the scene is built | one forward pass | per-scene fit | per-scene fit | per-scene fit |
| Time per scene | **not reported**. Parent C3G: 0.466 s for 24 views, GPU not stated | ~30 min for 270 frames at 480×360; 1.8 h on DyCheck (A100) | 296.76 s for 82 frames at 854×480 (A6000): half preprocessing, half fitting | 1.5 h per clip of 50–100 frames at 864×480 (RTX 3090) |
| Render speed | not reported | ~160 FPS at 480×360 | 247 FPS at 854×480 | 161 FPS at 864×480 |
| Gaussians | 2,048 per timestamp | ~0.3 M per scene (averages) | not reported | not reported (code caps stage 1 at 150k) |
| Driving data | none (DriveTrack point tracking only) | none | none | none |
| Code | MIT for its own code since 2026-10-27; non-commercial parts; weights CC BY-NC 4.0 | no licence; **training can't start** | no licence; **crashes at iteration 3,000** (calls a function that doesn't exist) | MIT; code released 2026-10-04 |
| On our 5070 Ti | port from PyTorch 2.2 / CUDA 12.1 | pins torch 2.11 + cu128, but broken | rebuild the custom ops; one user reports a run on an RTX 5090 after nine fixes `[agent]` | rebuild everything from PyTorch 2.4.1 / CUDA 11.8 |
| Verdict | useful idea | useful idea | useful idea | useful idea |

## The idea to take from each

1. **T4GS: a fixed Gaussian budget.** 2,048 learnable queries attend over the whole clip and are decoded at any time
   you ask for.
   - The Gaussian count no longer grows with cameras × pixels, which is the scaling problem research/07 and research/11
     identified.
   - Each query keeps its identity over time, so tracks come for free.
   - For us: one query set per tracked agent for the movers, over a pixel- or voxel-aligned static background (stage 7).
   - **If you read only one of the four, read this one.**
2. **RiGS: decide moving vs static per object, not per pixel.** This is the largest effect in its ablation: a per-pixel
   mask costs 1.43 dB (Table 3).
   - Its motion test is epipolar, which is blind to a car driving along the same line as the ego car.
   - We have poses and depth, so we can score each instance by its 3D residual after removing ego-motion.
   - Use: catch movers the tracker missed, so they don't smear into the background (stage 6).
3. **Instant4D: initialise from geometry and skip densification.**
   - Back-project depth with known poses and voxel-prune it.
   - Give static points a whole-clip lifetime and moving points a few frames.
   - Fit a few thousand iterations.
   - Its ablation: fitting 181 → 42 s, memory 10.7 → 0.83 GB, +0.61 dB (Table 2).
   - Cheapest experiment of the four: Street Gaussians already seeds from LiDAR but still runs 30k iterations with
     densification. Try the short schedule there (stage 6).
4. **Mono4DGS-HDR: one tone mapper per camera.** Store HDR colour in each Gaussian and render every frame through a small
   learned tone mapper fed that frame's exposure.
   - Eight cameras with independent auto-exposure, and tunnel exits, would stop fighting the fit.
   - Its own numbers: a random exposure on every frame costs only 0.22 dB, but the exposure metadata must be accurate to
     about ±0.25 EV (Tables 6–7).
   - Stage 6, later a stage-7 head.

## What the papers don't say up front `[measured]`

- **Instant4D's Gaussians cannot move.** The rotation is fixed to the identity (§3.3; learning rate 0.0 in the code), so
  the time-conditioned mean never shifts. A moving object becomes a flipbook of short-lived static Gaussians, with no
  velocity and no identity.
- **Instant4D leaves out its strongest baseline.**
  - Its DyCheck table includes Wu et al.'s 4DGS and Deform3D, the latter with ground-truth poses.
  - It does not include Yang et al.'s 4DGS (ICLR 2024), which is the representation Instant4D builds on.
  - In the source table both papers use (RoDyGS appendix), Yang et al. with ground-truth poses averages **25.32 dB** on
    Instant4D's five scenes, against Instant4D's 24.52, and is ahead on four of the five.
- **T4GS has no timing anywhere.** The full text contains no latency, runtime, milliseconds or seconds. Its arXiv
  project link (…/C4G) returns 404; the live page is cvlab-kaist.github.io/T4GS.
- **RiGS's released code cannot train.**
  - `src/runner/__init__.py` imports `dynamic`, `static` and `fused_v2`, and none of them is in the repo.
  - Issue #2 (2026-06-25) is still open. Its only comment is another user asking for an update.
- **Instant4D's released code crashes at its first save.**
  - At the default `--save_iterations 3000`, `script/optimize.py` calls `scene.render_evaluate_dycheck`.
  - That method is defined nowhere in the repo, so the run stops with an AttributeError before anything is saved.
  - The last push was 2025-11-13.
- **Mono4DGS-HDR's 161 FPS** is timed without a CUDA sync and leaves out evaluating the trajectories, so it is probably
  optimistic `[agent's code reading, not re-checked]`.

## How to use them (Claude's recommendation)

- **Read, don't install.** About 2 hours in all:
  1. T4GS §3.2, Tables 1–2 and App. F.
  2. RiGS §3.3 and Table 3.
  3. Instant4D §3.2, Table 2 and Table A1.
  4. Mono4DGS-HDR §3.1, §3.3.3 and A.1.4.
- **Why not install:** none takes several cameras or driving input; two have no licence and broken code; the other two
  need a CUDA 12.8 port for the 5070 Ti.
- **Try the four ideas as stage-6/7 experiments** once the Street Gaussians / OmniRe baseline runs. Start with Instant4D's
  short schedule on a LiDAR-seeded scene.
- **For more papers in this direction,** look for feed-forward 4D methods built for multi-camera driving, like STORM and
  DGGT, rather than monocular ones.

## Spot-check log `[measured]`, 2026-11-25

- **arXiv API:** titles, authors, dates and comments for all four papers.
- **Raw arXiv HTML:**
  - T4GS: 2,048 queries; Table 1 PSNR 22.35 / 19.52 / 20.51 against 21.94 / 17.27 / 15.86; 224×224 training; 4× H100;
    no timing words in the full text; DriveTrack only in App. D.
  - RiGS: one A100; 30 min and 160 FPS at 480×360; Tables 1, 2, 11 and 12.
  - Instant4D: one A6000; Table A1 rows and the 9,602 MB peak; Tables 1, 2 and 3; 247 FPS; R = I; "30×" with no named
    baseline.
  - Mono4DGS-HDR: Table 1 (1.5 h, 161 FPS, 37.64 vs 36.89); one RTX 3090; Table 2 (27.65); Table 7 (±0.75 EV → 34.32).
  - C3G Table 13: 0.466 s and 4,372 MiB.
  - RoDyGS appendix: the Yang et al. 4DGS row, and references [62] = Wu, [67] = Yang.
- **GitHub (`gh api`):**
  - licences, created and pushed dates, and stars for all four repos;
  - RiGS: the runner's imports against the files present, and who commented on issue #2;
  - T4GS: README pins, licence text, and the date the LICENSE file was added;
  - Mono4DGS-HDR: install.sh pins and its five CUDA builds;
  - Instant4D: the save step calls `scene.render_evaluate_dycheck`. That step runs at the default iteration 3,000
    (`script/optimize.py` lines 253–257, with no dataset check). GitHub code search finds the name nowhere else in the
    repo, and `scene/__init__.py` defines only `render_evaluate_sora`.
- **Hugging Face API:** T4GS weights, 4.06 GB + 0.18 GB, cc-by-nc-4.0.
- **Agent slips:** none that changes a conclusion. The Mono4DGS-HDR report spelled one author "Jinwei"; arXiv says
  "Jinwen", and the note records both.

## Not verified

- **Every time and quality number is the authors' own.** Nothing was run, here or on our GPUs.
- **Preprocessing times** for RiGS and T4GS.
- **Gaussian counts** for Instant4D and Mono4DGS-HDR.
- **T4GS:** whether its released checkpoint reproduces arXiv v1's Table 1.
- **C3G:** which GPU its timings were measured on.
- **Mono4DGS-HDR:** whether its code runs as released.

## Update 2026-11-25: the owner switched to one camera (docs/DECISIONS.md D-011)

The verdicts above were judged against the surround-camera goal. With one camera, two of the papers move up:
- **Instant4D** becomes a candidate pipeline for M3, the owner's own video.
  - About 5 minutes per clip, and its MegaSaM front-end estimates the poses.
  - Commenting out the one broken call in the save step should get a run past iteration 3,000 [inference, untested].
  - Its flipbook motion is still a limit for moving cars.
- **T4GS** becomes the first model to time for M4.
  - It is monocular and feed-forward, and its weights are public. CC BY-NC 4.0 is fine for learning.
  - Its 224×224 input and lack of driving training are still limits.
- **RiGS:** still idea-only, because its code cannot train.
- **Mono4DGS-HDR:** still idea-only. A phone's auto-exposure changes are a milder version of its problem, so the
  per-frame tone-mapper idea still applies.
