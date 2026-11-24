# 06 — How Street Gaussians works (and what "on the fly" really needs)

Read 2026-11-24 from the paper itself: arXiv 2401.01339v3 (Yan et al., Zhejiang University + Li Auto, ECCV 2024),
HTML version, including the supplementary material. Repo facts are from `gh api` on the same day.
Tags: `[primary]` = read in the paper or repo; `[derived]` = arithmetic on primary numbers; `[UNCERTAIN]` = not confirmed.

## One-sentence version

The cameras are not "converted" into splats. The scene is a cloud of fuzzy 3D blobs (Gaussians), and an optimizer
keeps moving, stretching, recolouring, adding and deleting blobs until renders of the cloud from every real camera
pose match the real photos. Moving cars get their own little cloud that is moved rigidly by a tracked box pose.

## What one Gaussian stores `[primary]`

| Attribute | Size | Notes |
|---|---|---|
| position μ | 3 floats | world frame for background, **box frame** for a car |
| scale S | 3 floats | |
| rotation R | 4 floats (unit quaternion) | covariance Σ = R S Sᵀ Rᵀ |
| opacity α | 1 float | |
| colour: spherical-harmonics (SH) coefficients | SH degree **1** → 4 per colour channel = 12 floats | degree reduced from 3 "to prevent overfitting" |
| semantic logits | M floats (background) / 1 scalar (car) | optional, only if 2D segmentation is supplied |

`[derived]` Background Gaussian without semantics: 23 floats ≈ 92 bytes in fp32. A car Gaussian replaces each SH
coefficient with k = 5 Fourier coefficients: 12 × 5 = 60 colour floats, 71 floats in total ≈ 284 bytes. The paper does
**not** report how many Gaussians a scene ends up with `[UNCERTAIN]`, so total memory per scene is unknown.

## How many camera views become one world `[primary]`

1. **Put every image in one world frame.** Each image has camera intrinsics K and a camera→world pose W, which comes
   from the rig calibration (camera→car) times the ego pose (car→world) that the dataset provides. Because of this,
   all cameras and all timesteps look at the **same** set of world-frame Gaussians. Overlapping fields of view are
   what tie the cameras together. Nothing is stitched in 2D.
2. **Seed the cloud (initialization).**
   - Aggregate the LiDAR sweeps into one point cloud and colour each point by projecting it into an image.
   - Points inside a tracked 3D box go to that car's cloud, transformed into the box's local frame. A car with fewer
     than 2K LiDAR points gets 8K random points inside its box.
   - Everything else is voxel-downsampled at 0.15 m and becomes the background, minus points no training camera sees.
   - Add a COLMAP (structure-from-motion) triangulation with the known camera poses, with moving objects masked out,
     to cover far regions LiDAR misses (trees across the road, distant signs). Removing SfM was worse than removing LiDAR.
3. **Render one training image.** For its time t: move each car cloud into the world with its pose, compute car colours
   for time t, concatenate cars + background into one cloud, project every Gaussian to a 2D ellipse
   (μ′ = K W μ, Σ′ = J W Σ Wᵀ Jᵀ), sort by depth and alpha-blend front to back:
   C = Σᵢ cᵢ αᵢ Πⱼ<ᵢ (1 − αⱼ).
   The sky is a separate learned 1024² cube map, blended in where the Gaussians are transparent: C = C_g + (1 − O_g)·C_sky.
4. **Compare and update.** Loss = colour (0.8·L1 + 0.2·D-SSIM) + 0.01·LiDAR depth L1 (worst 5 % of pixels ignored)
   + 0.05·sky mask BCE (mask from Grounding DINO + SAM) + 0.1·semantic CE (optional) + 0.1·entropy on car opacity.
   Gradients flow to every Gaussian attribute, the car pose corrections and the sky map.
5. **Grow and prune.** Standard 3DGS "adaptive density control": clone or split blobs where the gradient says
   detail is missing, delete transparent ones.
6. Repeat for **30,000 iterations** (Adam), cycling through all training images from all cameras and times.

Each extra camera is simply more training images seeing the same world. The paper's own Waymo runs use
**only the front camera** (`cameras: [0]`, frames 0–85 in `configs/experiments_waymo/*.yaml`). The code's default is the
three front cameras `[0, 1, 2]` `[primary: repo]`.

## How moving cars work `[primary]`

- **Each car is its own cloud in its own box frame**, and its shape never changes. At time t its Gaussians are placed
  in the world with the tracked box pose: μ_w = R_t μ_o + T_t and R_w = R_t R_o.
- **The tracker's poses are noisy, so they are learned too.** Each frame gets a learnable correction: ΔT_t (3D
  offset) and Δθ_t (yaw only). R′_t = R_t ΔR_t, T′_t = T_t + ΔT_t. With this, tracker poses came out *better* than
  ground-truth poses on Waymo (PSNR\* of moving objects 30.23 vs 29.84).
- **Appearance changes over time** (shadows, passing under trees) through "4D SH": each colour coefficient is a
  5-term cosine series over time, z(t) = Σᵢ fᵢ cos(iπt / N_t). Removing it costs 0.96 dB on moving objects.
- **Staying inside the box:** Gaussians that drift outside their car's box are pruned. An entropy loss pushes each
  car's rendered opacity to 0 or 1, so cars separate cleanly from the background ("no ghosting").
- **Nothing updates on the fly.** After training, every Gaussian is frozen. Rendering time t only means: look up the
  car poses for t, evaluate the cosine series, concatenate, splat. That is why it runs at 135 FPS, and why you can
  edit the scene by translating, rotating or swapping cars.

Ablation on Waymo, PSNR / PSNR\* on moving objects (Table 3): full model 34.61 / 30.23; no LiDAR 34.02 / 29.53;
no 4D SH 34.36 / 29.27; no pose optimization 34.18 / 28.24.

## Limits the authors list (Appendix C) `[primary]`

1. **Rigid only.** Walking pedestrians are not handled. OmniRe (drivestudio) adds SMPL-based human Gaussians and
   deformable nodes for this.
2. **Depends on the tracker.** A car the tracker misses has no cloud, so it smears into the background.
3. **Per-scene optimization.** Every new drive needs a fresh 30-minute fit. A generalizable feed-forward model is named
   as future work. That is exactly the gap Tesla's "~220 ms generative Gaussian splatting" claim fills.

## Compute

| Job | Hardware | Time / speed | Source |
|---|---|---|---|
| Street Gaussians fit, one scene (~86 frames, 1 camera, 1066×1600) | 1× RTX 4090 | ~30 min, 30k iterations | paper `[primary]` |
| Street Gaussians render | 1× RTX 4090 | 135 FPS at 1066×1600 (static 3DGS: 205 FPS; EmerNeRF: 0.21 FPS) | paper Table 1 `[primary]` |
| Preprocessing (LiDAR depth maps, Grounded-SAM sky masks, COLMAP, detector + tracker) | GPU | **not reported** | `[UNCERTAIN]` |
| Peak VRAM | — | **not reported** | `[UNCERTAIN]` |
| OmniRe fit (adds humans, non-rigid) | 1× RTX 4090 | ~1 h per scene | research/04 `[primary]` |
| Feed-forward 4D splats, inference ("on the fly") | 1× A100 | STORM 0.18 s/scene; DGGT ~0.4 s; DrivingForward 0.63 s and 7.58 GB | research/04 `[primary]` |
| Feed-forward 4D splats, training | multi-GPU | DGGT 8× H200; ReconDrive 8 GPU-days on H800; DrivingForward ~3 days on 1× A6000 at 40 GB | research/04 `[primary]` |
| Tesla "generative Gaussian splatting" | Tesla's own hardware | ~220 ms, hardware and resolution undisclosed | research/01 `[primary]` for the claim |

**On the 16 GB Mac:** the official code needs CUDA (the 3DGS rasterizer is a CUDA kernel), so dynamic Street Gaussians
fitting belongs on the 4090. **Static** splat training does run on Apple GPUs:
- Brush (`ArthurBrussee/brush`, Apache-2.0, 5.4k★): "macOS/windows/linux … training is fully supported natively"
- OpenSplat (now `WebODM/OpenSplat`, AGPL-3.0, 2.3k★): Metal backend

Both are `[primary: README]`, static scenes only, and good for learning the core optimizer before the dynamic version.
Viewing a trained scene works on the Mac: Spark (three.js) can move each splat per frame, which is what animating
car clouds needs (research/04).

## Is it realtime? (summary added 2026-11-24, from the numbers above)

- **Drawing an already-built scene: yes.** 135 FPS at 1066×1600 on one 4090 `[primary]`. On the Mac: **not measured**.
  Speed depends on the number of splats, which the paper does not report.
- **Building the scene from live cameras: no.** That takes about 30 minutes per scene.
- **Feed-forward models: close.** 0.18–0.63 s per update on an A100 (2–5 updates/s), and Tesla's claim is ~220 ms `[primary]`.
- **Design that would give a realtime FSD-style splat view** `[derived]`:
  - rebuild or refresh the splat world at a few Hz;
  - move the car clouds with tracker poses at 12 Hz, interpolated to 60 FPS;
  - draw every frame.
- **Quality falls off away from the recorded path.** The paper only shows lateral shifts of up to 2 m (Fig. 14).
  Anything never seen is empty.

## How Tesla does it on the fly (added 2026-11-24)

**What Tesla said** `[primary: Ashok Elluswamy's X article, re-fetched 2026-11-24 via api.fxtwitter.com/aelluswamy/status/1981644831790379245]`:
- On normal 3DGS: it "depends on camera views with large baseline … Typical vehicle motion … is quite linear", needs
  "good initialization from other pipelines", and optimization takes "10s of minutes".
- On Tesla's Generative Gaussian Splatting: it "has great generalization, runs in ~220 ms, doesn't require
  initialization, can model dynamic objects and can be jointly trained with the end-to-end AI model". The Gaussians
  come from "the production vehicle configuration's cameras". It is presented as one of the "interpretable
  intermediate tokens" used for debugging the end-to-end net.
- On the neural world simulator: "By adjusting the amount of test-time compute used, the same model can simulate the
  world in real-time". The demo is a person driving for more than 6 minutes, with all 8 cameras generated at
  24 fps. Its purpose is testing driving models, not the customer display.
- Not disclosed: the architecture, the hardware the 220 ms was measured on, and whether any of this reaches the
  in-car screen.

**The open recipe that matches it: feed-forward reconstruction** `[primary: arXiv abstracts 2501.00602, 2512.03004]`:
- STORM: a transformer "directly infers dynamic 3D scene representations — parameterized by 3D Gaussians and their
  velocities — in a single forward pass". It is trained only with reconstruction losses (dynamic objects and their
  masks emerge without labels), reconstructs "in 200ms" and "supports real-time rendering".
- DGGT: also predicts camera poses (no calibration needed), plus a dynamic head, a "lifespan" head for visibility over
  time, and a diffusion refinement.
- Versus Street Gaussians:
  - the minutes of per-scene optimization are replaced by a network trained once on many scenes;
  - per-Gaussian velocities replace tracker boxes.

**`[derived]`, not Tesla-confirmed:**
- "Jointly trained with the end-to-end model" most likely means a Gaussian decoder head on the driving network's shared
  backbone features. It would serve both as an auxiliary training signal and as a window into what the network "sees".
- "Adjusting test-time compute" fits a generative model that can trade sampling steps for speed. Tesla declined to name
  the architecture at CVPR 2023.

## Licence

`zju3dv/street_gaussians`: GitHub reports NOASSERTION; research/04 read it as ZJU research/education/personal use only.
Fine for learning. drivestudio (MIT) re-implements Street Gaussians and supports nuScenes, so it is the better route
for 6-camera nuScenes data `[primary: research/04]`.
