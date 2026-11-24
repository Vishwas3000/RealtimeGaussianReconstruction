# Learning roadmap: Tesla-style world rendering, end to end

For someone who knows the basics of Gaussian splats and wants to understand the whole stack: cameras → 3D → rendering
→ real time. Each stage says **why it matters**, **what to understand**, **what to read**, **what to build** (and on
which machine), and **how you know you've got it**. Build steps line up with the project roadmap in
[`README.md`](../README.md), so learning and building are the same work.

Every paper, repo, page and video below was checked on 2026-11-24: arXiv titles via the arXiv API, repos via the
GitHub API, pages returned HTTP 200, video titles via YouTube oEmbed. Time estimates are a **rough guess** at about
6–8 hours a week: around 6 months for everything.

## The one-page mental model

Everything here converts between **2D images** and a **3D world**, in both directions, over **time**:

| Direction | Discrete and labelled (what the car "knows") | Photoreal (what it "sees") | Learned, no explicit 3D |
|---|---|---|---|
| **2D → 3D** (understand) | BEV / occupancy / boxes / lanes (stage 5) | Gaussian splats: fitted (stages 2, 6) or predicted (stage 7) | — |
| **3D → 2D** (draw) | game-engine rendering, the FSD screen (stage 3) | splat rasterisation (stage 2) | generative world model (stage 8) |

Tesla's three "renders" map onto this table (research/01, research/06):
1. **The in-car screen.** A game engine draws the network's 3D outputs.
2. **Generative Gaussian Splatting.** A network outputs 3D splats from 8 cameras in ~220 ms.
3. **The neural world simulator.** A video generator produces all 8 cameras at 24 fps from driving actions.

Two ideas run underneath everything:
- **Learning:** optimise something until rendered or predicted outputs match real data.
- **Compute:** make it fast enough (stage 9).

## The route

```
0 Map
 └─► 1 Cameras & 3D geometry   ← everything depends on this
      ├─► 2 Gaussian splatting, properly ─────► 6 Dynamic driving scenes ──┐
      ├─► 3 Real-time graphics: the FSD screen ────────────────────────────┤
      └─► 4 Deep-learning toolkit                                          │
           ├─► 5 Seeing in 3D: cameras → vector space ─────────────────────┼─► 10 Capstone
           ├─► 7 On-the-fly splats (Tesla's GGS)  ◄── also needs 2 ────────┤
           └─► 8 Generative world models (Tesla's simulator) ──────────────┘
 9 Making it real time: runs alongside stages 5–8
```

Shortcuts, if one system matters most:
- **Splats / on-the-fly 3D:** 0 → 1 → 2 → 4 → 6 → 7 → 9
- **FSD screen:** 0 → 1 → 3 → 4 → 5 → 9
- **World simulator:** 0 → 1 → 4 → 8 (stage 3 to view results)

## Which machine for what

| Machine | Use it for |
|---|---|
| **Mac (M5, 16 GB)** | geometry exercises, the renderer, viewing splats, tiny toys. One model job at a time |
| **RTX 5070 Ti PC (16 GB)** | inference and small training (gsplat, Brush, a small LSS, tiny diffusion). Needs **PyTorch ≥ 2.7** (CUDA 12.8); old repos must be ported. On Windows, I'd use WSL2 for CUDA builds |
| **Rented RTX 4090 box** | heavy training: Street Gaussians / OmniRe, OccWorld |

## Your first week

1. Watch AI Day 2021, 0:49:56 and 0:51:55–1:11:20 (stage 0).
2. Sign up at nuscenes.org and download `v1.0-mini` (4.2 GB). To start before the account arrives, grab one
   Argoverse 2 drive with no account at all: 7 surround cameras, 1.14 GB (see [`research/12`](../research/12-test-datasets.md)).
3. Run the nuScenes devkit tutorial notebook.
4. Write your own projection code and overlay LiDAR points on all 6 cameras (stage 1).
5. Start the 2D-Gaussian image fitter (stage 2). It's the best intuition builder in this whole list.

---

## Stage 0 — The map (2–3 days)

**Why:** know what the finished system looks like before learning its parts.

**Understand:**
- The three Tesla renders above, and what each one takes in and puts out.
- Only the 2021–22 architecture is public. FSD v12+, the world simulator and GGS are described, not specified.

**Read / watch:**
- [Tesla AI Day 2021](https://www.youtube.com/watch?v=j0z4FweCy4M): 0:49:56 (the screen renders "vector space") and 0:51:55–1:11:20 (the full pipeline).
- Ashok Elluswamy's ICCV 2025 write-up: https://x.com/aelluswamy/status/1981644831790379245
- Our notes: [`README.md`](../README.md), [`research/01`](../research/01-tesla-public-disclosures.md), and the "How Tesla does it" section of [`research/06`](../research/06-street-gaussians-explained.md).

**You've got it when:** you can draw the three systems from memory and say what each one outputs.

## Stage 1 — Cameras and 3D geometry (≈2 weeks · Mac)

**Why:** every system here is "pixels ↔ 3D points". Mistakes here break everything later, silently.

**Understand:**
- **Transforms as matrices.** Homogeneous coordinates and 4×4 matrices that rotate and translate in one multiply.
- **The pinhole camera.** Intrinsics `K` (focal length, image centre); projection `pixel = K·[R|t]·X`, then divide by depth.
- **Why one image can't give 3D.** Going backwards from a pixel needs depth. That is exactly why LSS predicts a *depth distribution* per pixel (stage 5).
- **The frame chain.** Camera → car ("ego") → world. Calibration says where each camera sits on the car; the ego pose says where the car is at each moment.
- **Rotations.** Matrices, quaternions (each Gaussian stores its rotation as one) and yaw-only rotations (box headings, Street Gaussians' pose fixes).
- **Multi-camera rigs.** Overlapping fields of view.
- **Time sync.** nuScenes cameras fire at staggered times at 12 Hz, LiDAR at 20 Hz, labelled keyframes at 2 Hz (research/05).
- **Rectification.** Tesla rectifies every camera to one "virtual camera" (AI Day 2021, 1:01:59).

**Read / watch:**
- If rusty: 3Blue1Brown, [Essence of linear algebra](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab) and [quaternions](https://www.youtube.com/watch?v=d4EgbgTm0Bg).
- Image-formation lectures from Shree Nayar's [First Principles of Computer Vision](https://fpcv.cs.columbia.edu/).
- The [nuScenes tutorial notebook](https://github.com/nutonomy/nuscenes-devkit/blob/master/python-sdk/tutorials/nuscenes_tutorial.ipynb).

**Build (Mac):**
1. Write `world_to_pixel(point, camera, timestamp)` yourself, without the devkit's helpers.
2. Overlay LiDAR points on all 6 camera images, coloured by depth.
3. Project a labelled 3D box into the images.
4. Draw a top-down plot of the boxes around the car.

**You've got it when:**
- your overlay matches the devkit's `render_pointcloud_in_image`;
- you can explain why a pixel alone has no 3D position.

## Stage 2 — Gaussian splatting, properly (≈3 weeks · Mac + 5070 Ti)

**Why:** the core of Street Gaussians and of Tesla's GGS. You know the idea; now the maths and the optimisation.

**Understand:**
- **A Gaussian is a fuzzy ellipsoid.** Its mean `μ` is the centre; its covariance `Σ = R S Sᵀ Rᵀ` is the shape. It is built from a rotation and a scale so it stays valid while the optimiser changes it.
- **Projecting it to the screen.** A linear map turns a Gaussian into a Gaussian: `Σ' = A Σ Aᵀ`. Perspective projection isn't linear, so splatting approximates it locally with its Jacobian `J`: `Σ' = J W Σ Wᵀ Jᵀ`. This is the "EWA splatting" idea (Zwicker et al., 2001).
- **Alpha compositing.** `C = Σ cᵢ αᵢ Π(1 − αⱼ)`, front to back. It is the same equation as NeRF's volume rendering, but over sorted splats instead of samples along a ray.
- **The tile rasteriser.** Split the screen into tiles, sort splats by depth in each tile, then blend. Blending is ~60% of the time and sorting ~30% (research/08).
- **Spherical harmonics.** Colour that changes with viewing direction. Degree 0 is a flat colour.
- **Optimisation.** Render, compare with the photo (L1 + D-SSIM), take an Adam step. Densification clones or splits splats where detail is missing and prunes useless ones. The starting cloud comes from COLMAP (structure-from-motion) or LiDAR.
- **The idea to carry forward.** Here you **optimise the splats of one scene**. In stage 7 you **train a network that outputs splats**. Same loss; different thing being learned.

**Read:**
- [3D Gaussian Splatting](https://arxiv.org/abs/2308.04079): method and optimisation sections.
- [gsplat Mathematical Supplement](https://arxiv.org/abs/2312.02121): forward and backward maths, the precise version.
- [NeRF](https://arxiv.org/abs/2003.08934): skim for volume rendering.
- [gsplat docs](https://docs.gsplat.studio/).

**Build:**
1. **Mac (tiny; CPU is fine).** About 100 lines of PyTorch that fit a photo with a few thousand **2D** Gaussians (position, rotation + scale, colour, opacity), blended front to back and optimised with Adam. Watch them move.
2. **5070 Ti.** Run gsplat's [`examples/image_fitting.py`](https://github.com/nerfstudio-project/gsplat/blob/main/examples/image_fitting.py) and compare it with yours.
3. **5070 Ti.** Film a 1-minute phone video of a room, get camera poses with [COLMAP](https://github.com/colmap/colmap), and train in [Brush](https://github.com/ArthurBrussee/brush) (works on Windows, which keeps the Mac free).
4. **Mac.** View the result in [SuperSplat](https://github.com/playcanvas/supersplat) or [Spark](https://github.com/sparkjsdev/spark).
5. Turn knobs and note what breaks: SH degree 0 vs 3, densification off, fewer iterations.

**You've got it when:**
- you can explain every symbol in `Σ' = J W Σ Wᵀ Jᵀ`;
- you can say why sort order matters and what densification fixes.

**Our notes:** [`research/06`](../research/06-street-gaussians-explained.md), [`research/08`](../research/08-splat-render-cost.md).

## Stage 3 — Real-time graphics: the FSD screen (≈2 weeks · Mac · project phase 0)

**Why:** the in-car display is a game engine drawing the network's outputs. You'll use this renderer to show every later result.

**Understand:**
- **The GPU pipeline.** Triangles → pixels, vertex and fragment shaders, the depth buffer. Transparency needs sorting, the same problem splats have.
- **Instancing.** One draw call for 100k cubes; that's how occupancy voxels are drawn.
- **Smooth "blobs".** Marching cubes or surface nets turn a voxel grid into a smooth surface.
- **Lines.** Catmull-Rom splines for lanes, ribbons for the planned path.
- **Two clocks.** Perception updates at 12 Hz and the screen at 60 fps, so draw one perception frame late and interpolate between the two latest frames (snapshot interpolation). Damping and the 1€ filter stop jitter, and track IDs keep each car's mesh stable.

**Read:**
- [three.js examples](https://threejs.org/examples/): instancing, marching cubes, fat lines.
- Gaffer on Games, [Snapshot Interpolation](https://gafferongames.com/post/snapshot_interpolation/).
- [`research/05`](../research/05-renderer-and-runtime.md).

**Build (Mac), project phase 0:**
1. Convert nuScenes-mini ground truth to `frame.json`.
2. Draw it in a Three.js page at 60 fps: grey voxels from Occ3D labels, car meshes on the boxes, lanes, the ego car, a chase camera.
3. Log the same data to [Rerun](https://github.com/rerun-io/rerun) as a truth view; its [nuScenes example](https://github.com/rerun-io/rerun/tree/main/examples/python/nuscenes_dataset) is a ready scaffold.

**You've got it when:**
- a scene plays smoothly at 60 fps with no flicker;
- you can explain why the screen runs one perception frame behind.

## Stage 4 — Deep-learning toolkit: from CNNs to transformers (≈2–3 weeks · 5070 Ti)

**Why:** every network here is built from the same parts: perception, feed-forward splats and world models. Attention cost explains most of the speed limits in research/11.

**Understand:**
- **The training loop.** Model, loss, autodiff gradients, optimiser, batches, overfitting, validation.
- **Image backbones.** CNNs (ResNet, RegNet) and feature pyramids (FPN; BiFPN is Tesla's choice).
- **Attention.** Queries, keys, values. Self-attention vs **cross-attention**: cross-attention is how top-down "BEV queries" look at camera features. Positional encodings tell tokens where they are.
- **Tokens and patches (ViT).** An image becomes a grid of tokens. Full attention costs roughly tokens², which is why 8 cameras or higher resolution cost *more than proportionally*: the 1.3–1.8 exponents in research/11.
- **Pretrained backbones** (DINOv2 and others) and fine-tuning.

**Read / watch:**
- [The Illustrated Transformer](https://jalammar.github.io/illustrated-transformer/).
- Karpathy, [Let's build GPT](https://www.youtube.com/watch?v=kCc8FmEb1nY), with [nanoGPT](https://github.com/karpathy/nanoGPT).
- [Attention Is All You Need](https://arxiv.org/abs/1706.03762).
- [ViT](https://arxiv.org/abs/2010.11929).

**Build:**
1. Code along with the GPT video.
2. Write a toy cross-attention module where a 10×10 grid of BEV queries attends to image-patch features.

**You've got it when:**
- you can write attention from scratch;
- you can explain why doubling the camera images can more than double reconstruction time.

## Stage 5 — Seeing in 3D: cameras → vector space (≈4 weeks · 5070 Ti · project phases 1 and 3)

**Why:** this is Tesla's published 2021–22 stack, and it is what the screen draws.

**Understand:**
- **Bird's-eye view (BEV).** A top-down grid around the car where all cameras' features meet.
- **Two ways to get there:**
  - *Lift-splat* (LSS): predict a depth distribution per pixel, lift image features into 3D, pool them onto the BEV grid.
  - *Attention* (BEVFormer): BEV queries attend to the images. This is closest to Tesla's transformer.
- **Time.** Feature queues and temporal fusion (Tesla's video module, BEVFormer's temporal attention). Sparse4D's instance bank gives **tracking IDs**.
- **Occupancy.** A voxel grid of free/filled plus a class (Occ3D: 200×200×16 at 0.4 m). FlashOcc's channel-to-height trick gets there with only 2D convolutions.
- **Vector outputs.** Boxes with velocity. Lanes as polylines (MapTR) or as token sequences (Tesla's "language of lanes").
- **End-to-end.** One network outputs agents + map + plan (UniAD, SparseDrive). Tesla v12+ goes further: controls out.
- **Labels.** Perception is trained on labelled boxes and occupancy. Contrast stage 7, which needs no labels.

**Read / watch:**
- [Lift, Splat, Shoot](https://arxiv.org/abs/2008.05711): read it fully, it's the clearest.
- [BEVFormer](https://arxiv.org/abs/2203.17270), [Occ3D](https://arxiv.org/abs/2304.14365), [FlashOcc](https://arxiv.org/abs/2311.12058), [Sparse4D v3](https://arxiv.org/abs/2311.11722), [MapTR](https://arxiv.org/abs/2208.14437), [SparseDrive](https://arxiv.org/abs/2405.19620).
- [UniAD](https://arxiv.org/abs/2212.10156): skim.
- [AI Day 2022](https://www.youtube.com/watch?v=ODSJsviD_SU): occupancy 1:12:23–1:16:12, lanes 1:27:04–1:30:12.
- [CVPR 2022 WAD keynote](https://www.youtube.com/watch?v=jPCV4GKX9Dw).
- Our notes: [`research/02`](../research/02-bev-and-occupancy.md), [`research/03`](../research/03-vector-space-and-end-to-end.md).

**Build:**
1. **Your own net (phase 3).** A minimal LSS from scratch: ResNet-18, depth bins, cumsum pooling (as in [lift-splat-shoot](https://github.com/nv-tlabs/lift-splat-shoot)), predicting a BEV vehicle map on nuScenes-mini. It will overfit 10 scenes. That's fine: the goal is the pipeline.
2. **Pretrained models (phase 1).**
   - Port [FlashOcc](https://github.com/Yzichen/FlashOCC) and [SparseDrive](https://github.com/swc-17/SparseDrive) to PyTorch ≥ 2.7, rebuilding their custom ops for the 5070 Ti (`TORCH_CUDA_ARCH_LIST=12.0`).
   - Run inference and write `frame.json`.
   - Play it in your stage-3 renderer next to ground truth.

**You've got it when:**
- your LSS output lines up with the true boxes;
- you can point to where 2D becomes 3D in LSS and in BEVFormer;
- you can say why `bev_pool_v2` blocks the Mac.

## Stage 6 — Dynamic driving scenes: Street Gaussians and OmniRe (≈2 weeks · 4090 box · project phase 4)

**Why:** how a recorded drive becomes a photoreal 3D world with moving cars. Tesla's GGS speeds up exactly this.

**Understand:**
- **The scene graph.** Background splats live in world coordinates. Each car is its own cloud in its box frame, moved by a tracker's pose plus a learned correction.
- **Extra pieces.** Appearance that changes over time (4D SH), a sky cube map, LiDAR depth supervision, sky masks, and an entropy loss that separates cars cleanly from the background.
- **People.** Pedestrians bend, so OmniRe uses SMPL body models for them.
- **Limits.** Rigid objects only (Street Gaussians), dependence on tracker recall, 30–60 min per scene.

**Read:**
- Our walk-through: [`research/06`](../research/06-street-gaussians-explained.md).
- [Street Gaussians](https://arxiv.org/abs/2401.01339), [OmniRe](https://arxiv.org/abs/2408.16760).

**Build (4090 box):**
1. Reconstruct one nuScenes scene with [drivestudio](https://github.com/ziyc/drivestudio): Street Gaussians mode first, then OmniRe.
2. Write a full 3DGS PLY exporter. drivestudio's own export writes only points and colours.
3. View it on the Mac in Spark.
4. Move or swap a car and re-render.

**You've got it when:**
- the edited scene renders;
- you can explain what happens when the tracker misses a car.

## Stage 7 — On-the-fly splats: feed-forward reconstruction, Tesla's GGS (≈3 weeks · 5070 Ti)

**Why:** replace 30 minutes of per-scene fitting with one pass of a network trained on thousands of scenes, ~0.1–0.4 s.

**Understand:**
- **Amortisation.** Pay the optimisation once, during training, across many scenes.
- **Pixel-aligned splats.** For each pixel, predict a depth plus splat parameters, then unproject with the camera geometry from stage 1 (pixelSplat, MVSplat).
- **Large reconstruction models.**
  - Transformers over all image tokens (GS-LRM).
  - Geometry transformers that also predict the camera poses (VGGT), so DGGT needs no calibration.
- **Motion.** A velocity per splat moves it to any moment without a tracker (STORM). DGGT adds "dynamic" and "lifespan" heads.
- **Training without labels.** Render the predicted splats into other cameras and moments, compare with real photos. Dynamic objects emerge on their own.
- **Cost.** Image resolution is the main lever, because attention grows faster than the input (research/11).

**Read:**
- [pixelSplat](https://arxiv.org/abs/2312.12337), [MVSplat](https://arxiv.org/abs/2403.14627), [GS-LRM](https://arxiv.org/abs/2404.19702), [VGGT](https://arxiv.org/abs/2503.11651), [STORM](https://arxiv.org/abs/2501.00602), [DGGT](https://arxiv.org/abs/2512.03004), [Omni-Scene](https://arxiv.org/abs/2412.06273).
- The GGS paragraph of Ashok's write-up.
- Our notes: [`research/07`](../research/07-feedforward-recon-compute.md), [`research/11`](../research/11-realtime-compute-budget.md).

**Build (5070 Ti):**
1. Run [DGGT](https://github.com/xiaomi-research/dggt) inference. Its released weights are Waymo-trained, and its abstract claims zero-shot transfer to other datasets, so try nuScenes too. ReconDrive (nuScenes weights, research/04) is the alternative.
2. Time it at 6 and 8 cameras and at a lower resolution, and record the VRAM.
3. Replace the matching estimates in research/11.
4. View the output in Spark.

**You've got it when:**
- research/11 has measured rows from your card;
- you can explain why this is ~1,000× faster than stage 6, and what it gives up.

## Stage 8 — Generative world models: Tesla's simulator (≈4 weeks · 5070 Ti + 4090 box)

**Why:** Tesla's simulator generates all 8 camera videos from the driver's actions, with no explicit 3D at all.

**Understand:**
- **Autoencoders / VAEs.** Compress video into a small latent and decode it back. Tiny decoders are a big speed win.
- **Diffusion.** Learn to remove noise step by step. The **number of sampling steps is the "test-time compute" knob**. Latent diffusion runs in the compressed space; DiT uses a transformer as the denoiser.
- **Video.** Temporal attention. Chunk-by-chunk causal generation with a **KV cache**, so the next frames can react to new actions.
- **Conditioning.** Actions, trajectories, map layout, and consistency across cameras.
- **Real time.** Distil to 1–4 steps (DMD, Self-Forcing), use FP8, and split cameras across GPUs (OmniDreams).
- **A cheaper cousin.** Occupancy world models (OccWorld) predict future voxels instead of pixels. They plug straight into the stage-5 grid and the stage-3 renderer.

**Read / watch:**
- Lilian Weng, [What are Diffusion Models?](https://lilianweng.github.io/posts/2021-07-11-diffusion-models/).
- Calvin Luo, [Understanding Diffusion Models](https://arxiv.org/abs/2208.11970).
- Foundations: [VAE](https://arxiv.org/abs/1312.6114), [DDPM](https://arxiv.org/abs/2006.11239), [Latent Diffusion](https://arxiv.org/abs/2112.10752), [DiT](https://arxiv.org/abs/2212.09748), [DMD](https://arxiv.org/abs/2311.18828), [Self-Forcing](https://arxiv.org/abs/2506.08009).
- For intuition: [GameNGen](https://arxiv.org/abs/2408.14837), [DIAMOND](https://arxiv.org/abs/2405.12399).
- Driving: [Epona](https://arxiv.org/abs/2506.24113), [OccWorld](https://arxiv.org/abs/2311.16038), [OmniDreams](https://arxiv.org/abs/2606.03159).
- [CVPR 2023 WAD keynote](https://www.youtube.com/watch?v=6x-Xb_uT7ts), 0:14:12–0:16:07: Tesla's generated 8-camera video.
- Our notes: [`research/09`](../research/09-world-sim-realtime-compute.md).

**Build:**
1. **5070 Ti.** Train a tiny DDPM on MNIST or CIFAR-10 and watch quality against the number of sampling steps.
2. **4090 box.** Train [OccWorld](https://github.com/wzzheng/OccWorld) on Occ3D-nuScenes (its README says one 24 GB 4090) and play its forecasts in your renderer.
3. **5070 Ti or 4090.** Run single-camera inference with Epona or OmniDreams' single-view checkpoint ([flashdreams](https://github.com/NVIDIA/flashdreams)) and measure fps against steps. Whether either fits in 16 GB is unverified; OmniDreams' smallest preset targets a 32 GB RTX 5090.

**You've got it when:**
- you can explain why 2 steps instead of 50 makes real time possible, and what quality it costs;
- you have watched a model "dream" a few seconds of driving.

## Stage 9 — Making it real time (≈2 weeks, alongside stages 5–8 · all machines · project phase 2)

**Why:** every number in research/11 is an estimate until you measure it.

**Understand:**
- **Latency vs throughput.** Frame budgets: 16.7 ms per frame at 60 fps; 4.2 ms per view for 8 cameras at 30 fps.
- **Compute-bound vs bandwidth-bound.** Splat drawing scales with FP32 and memory bandwidth; networks scale with tensor cores (research/10).
- **Number formats.** FP32 → BF16/FP16 → FP8 → INT8/FP4. Watch for accumulate precision and "with sparsity" marketing figures.
- **Tools.** PyTorch profiler, `torch.compile`, CUDA graphs, ONNX export, TensorRT, ONNX Runtime (CoreML on the Mac). Custom CUDA ops are what block portability.

**Read:**
- Horace He, [Making Deep Learning Go Brrrr](https://horace.io/brrr_intro.html).
- [PyTorch profiler recipe](https://docs.pytorch.org/tutorials/recipes/recipes/profiler_recipe.html).
- [`research/10`](../research/10-hardware-specs.md), [`research/11`](../research/11-realtime-compute-budget.md).

**Build:**
1. Profile FlashOcc and DGGT on the 5070 Ti.
2. Export FlashOcc to ONNX with `bev_pool_v2` replaced by a gather, and run it on the Mac (project phase 2).
3. Measure Spark on the Mac at 1, 3 and 10 M splats.

**You've got it when:**
- each research/11 row you touched holds a measured number;
- you can say whether each workload is compute- or bandwidth-bound.

## Stage 10 — Capstone: Tesla end to end (≈1–2 weeks)

**Build:** one nuScenes scene, three views side by side:
1. the FSD-style screen driven by your perception outputs;
2. photoreal splats from feed-forward reconstruction;
3. a few seconds "dreamed" by a world model from the same starting point.

**You've got it when:**
- you can walk through every paragraph of Ashok's ICCV 2025 write-up and name the stage that explains it;
- you can write one page, in your own words, on how Tesla does it as far as public information goes.

---

## Glossary

| Term | Meaning |
|---|---|
| Intrinsics (`K`) | Focal length and image centre; turn camera-frame 3D points into pixels |
| Extrinsics / calibration | Where a camera sits on the car (rotation + translation) |
| Ego pose | Where the car is in the world at a given timestamp |
| BEV | Bird's-eye view: a top-down grid around the car |
| Occupancy grid | 3D voxels marked free or filled, plus a class |
| Vector space (Tesla) | Objects, lanes and the path as coordinates, not pixels |
| Covariance `Σ` | 3×3 matrix giving a Gaussian's ellipsoid shape and orientation |
| Jacobian `J` | Local linear approximation of a curved function (here, perspective projection) |
| Alpha compositing | Blending semi-transparent layers front to back |
| Spherical harmonics (SH) | A few coefficients giving colour as a function of view direction |
| Densification / pruning | Adding splats where detail is missing / removing useless ones |
| SfM / COLMAP | Recovering camera poses and sparse 3D points from photos |
| Per-scene optimisation vs feed-forward | Fitting one scene's parameters vs a trained network predicting them in one pass |
| Token | One chunk of input (e.g. an image patch) a transformer processes |
| Attention | Each token weighs all the others; full attention costs about tokens² |
| Backbone | The pretrained image feature extractor (ResNet, RegNet, ViT, DINOv2) |
| Latent / VAE | The compressed space an autoencoder maps images into and back out of |
| Diffusion step | One denoising pass; fewer steps = faster but lower quality |
| Distillation | Training a fast student to copy a slow teacher (e.g. 50 steps → 2) |
| KV cache | Stored keys/values from earlier frames, so generation continues without recomputing |
| Causal / autoregressive | Generating the next chunk only from previous ones |
| Latency vs throughput | Time for one result vs results per second |
| Compute- vs bandwidth-bound | Limited by maths units vs by memory speed |
| TFLOPS / TOPS | Trillions of float / integer operations per second (peak; often marketing) |
| FP16 / BF16 / FP8 / INT8 | Number formats: smaller is faster and uses less memory, but is less precise |
| PSNR | Render-vs-photo similarity score in dB; higher means closer |
