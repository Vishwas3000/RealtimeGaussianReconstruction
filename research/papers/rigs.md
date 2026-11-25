# RiGS: Rigid-aware 4D Gaussian Splatting from a Single Monocular Video

Read 2026-11-25 for the TeslaRender goal (6–8 surround cameras → dynamic Gaussian world → realtime render).

**Sources.** The arXiv HTML v1, read in full through Table 13 of the appendix (the 13.9 MB PDF was too large for the
fetch tool); the project page; the GitHub API and raw files of `ladvu/RiGS` and its dependencies. Nothing was
downloaded, installed or run.

**Tags.** [primary] = read in the paper, page, repo or API. [secondary] = summary or search snippet.
[UNCERTAIN] = not confirmed. [inference] = my reasoning. **Reading caveat:** the fetch tool paraphrases and quotes
at most 125 characters, so equations are transcribed, not copied. Every table number was extracted at least twice or
checked by arithmetic (each per-scene row of Table 12 re-sums to its printed total and average).

## 1. Citation

- **Title:** "RiGS: Rigid-aware 4D Gaussian Splatting from a Single Monocular Video" [primary]
- **Authors** [primary]: Chenyu Wu (Harvard and Zhejiang University; work done as a Harvard intern), Wanhua Li
  (Harvard and NTU; corresponding author), Zhu-Tian Chen (University of Minnesota – Twin Cities), Hanspeter Pfister
  (Harvard).
- **arXiv:** 2605.23672v1, cs.CV, submitted 22 May 2026, CC BY 4.0; the only version [primary].
- **Venue:** none stated in the paper or on the project page [primary]. The repo description ends "(CVPRF)", which
  probably means CVPR 2026 Findings [UNCERTAIN].
- **Project page:** https://ladvu.github.io/RiGS/. It links code, arXiv and a YouTube video and shows qualitative
  comparisons, but gives no numbers [primary].
- **Code:** https://github.com/ladvu/RiGS. No licence, no weights, and training cannot start because modules it imports
  are missing (§6) [primary].

## 2. The problem

The goal is to rebuild a dynamic 3D scene from one ordinary video, so that it can be rendered from new viewpoints.
Motion in such videos mixes slow, long-lasting movement (a person crossing the frame) with short, fast, complex changes
(an umbrella opening, limbs, thrown objects). According to the abstract, prior methods "either struggle to maintain
temporal consistency or fail to capture high-frequency dynamics" [primary].

## 3. How it works

### Representation (§3.1–3.4, Eqs. 7–10) [primary]

Gaussians are 2D Gaussian Splatting surfels rendered with gsplat; the code default is `model_type = "2dgs"`
[primary: code].

| Type | Stores | Motion over time t |
|---|---|---|
| Static | mean μ, scale s, rotation q, opacity o, colour c | none |
| Rigid | the same, plus K weights w, duration β^r and temporal centre γ^r | μ(t) = (Σ_j w_j T_j,t) μ; R(t) = (Σ_j w_j T_j,t)[:3,:3] R |
| Transient | the same, plus velocity v, duration β^t and temporal centre γ^t | μ(t) = μ + v (t − γ^t), a straight line |

- **Motion bases.** T_j,t ∈ SE(3) are **K = 10 bases** per time step, used for every scene. They are stored as a 6D
  rotation plus a translation and interpolated in time (§3.4, §4.1) [primary].
- **The bases are global, not per object.** Eqs. 7–8 carry no object index [primary]. The code initialises the bases
  with Shape-of-Motion-style code in `src/flow3d/init_utils.py` [primary: code]:
  - cuML k-means clusters the normalised 3D velocity directions of all foreground tracks;
  - clusters with 100 or fewer tracks are dropped;
  - each remaining cluster gets one SE(3) motion from a Procrustes fit;
  - each Gaussian's weights are 10·exp(−distance to each cluster centre);
  - no object IDs are used.

  So a "rigid" Gaussian is a soft blend of ten scene-wide rigid motions, not a member of one rigid object [inference].
- **Fading in and out.** Rigid and transient Gaussians are gated by o(t) = o·σ(α(β − |t − γ|)), with α = 3.0. β and γ
  are initialised from point-track visibility (Eq. 9, §4.1) [primary].
- **Colour:** whether c is RGB or spherical harmonics is not stated.

### Pipeline [primary unless tagged]

1. **Preprocess the single video.**
   - In-the-wild video: intrinsics, poses and metric depth from ViPE, with MoGe as the depth model. §3.2 also cites
     MegaSaM.
   - Benchmarks: depth from Metric3D (NVIDIA) or the dataset's LiDAR (DyCheck). Cameras from MoSca's camera module,
     which §4.1 calls the "MoCa module [28]".
   - Flow and its uncertainty from SEA-RAFT; 2D tracks from BootsTAP; objects and their IDs from SAM2. App. 6 adds SAM
     through a modified "AutoSeg".
   - The repo's script runs a modified ViPE that also outputs flow and static masks, then TAPIR/BootsTAPIR tracks
     [primary: README].
2. **Object-wise dynamic mask** (§3.3, App. 6).
   - For each SAM2 object i in frame t, s_i,t is a weighted mean of the Sampson (epipolar) error over the object's
     non-occluded pixels.
   - The weights are (1 − m_occ)/(1 + u)², with u = SEA-RAFT uncertainty and m_occ = a forward–backward occlusion mask.
   - F comes from LMEDS on 10,000 sampled correspondences.
   - Frames with s_i,t > 1e-4 are kept and averaged. The object is dynamic if its average exceeds max_i(s_i)/4.
   - The mask is the union of the dynamic objects: "if any part of an object exhibits motion at any time, the entire
     object should be treated as dynamic".
3. **Initialise.** Static Gaussians from outside the mask (§3.4); rigid Gaussians "from tracks within the dynamic
   masks" (§4.4). The code defaults to 40,000 foreground Gaussians [primary: code].
4. **Warm up** static, then rigid Gaussians plus the bases: 3K + 12K iterations on NVIDIA, 5K + 40K on DyCheck (App. 6).
5. **Split.** After warm-up, a rigid Gaussian whose duration β^r drops below a threshold becomes transient. This keeps
   happening during joint training.
   - The paper gives no threshold. The code has `lifespan_thres = 3.0` and converts every 3,000 steps from step 10,000
     to 20,000 [primary: code]. Whether these are the paper's settings is [UNCERTAIN].
   - How v is initialised at conversion is not stated.
6. **Joint training** of all three types: Adam, batch 1, 30K iterations (NVIDIA) or 100K (DyCheck). **Camera poses are
   fixed**: "not optimized to speed up the training" (§4.1).
7. **Render at time t:** move the rigid and transient Gaussians, apply the opacity gates, splat with the static ones.

### Losses (weights from Table 4; Eqs. 6, 13–17) [primary]

- **Photometric:** 0.9·L1 + 0.1·SSIM term.
- **Mask:** 0.5·BCE between the rendered dynamic mask (static = 0, dynamic = 1) and the object-wise mask.
- **Geometry:** 0.05·scale-and-shift-invariant depth L1 + 0.05·normal consistency.
- **Correspondence:** 2.0·L1 on 3D track positions + 0.01·scene-flow L1 (forward and backward). The scene flow is
  optical flow lifted to 3D "using camera parameters and metric depth". It guides both rigid and transient Gaussians.
- **Regulariser:** (1/N) Σ (0.5/β_i^r + 0.5·var(s_i)). It pushes rigid durations up and scales towards isotropic (from
  Gaussian Marbles). App. 7 reports that β ends up with two peaks, which keeps the rigid/transient split clean.

### Pretrained models and inputs [primary]

- **Models used:** ViPE (a modified fork in the repo), MegaSaM (cited), MoGe or Metric3D-v2 (depth), SEA-RAFT, BootsTAP,
  SAM2 plus SAM, and MoSca's camera solver.
- **The depth model barely matters.** Table 10, NVIDIA PSNR: Metric3D-v2 27.43, MoGe 27.49, UniDepth 27.28,
  DepthPro 27.31.
- **Not needed:** 3D boxes, LiDAR (except DyCheck's provided depth), a body model, or labels. None is mentioned.
- **Camera poses:** one camera, with poses from ViPE (MoSca for the benchmarks), frozen during training. The code flags
  `pose_opt` and `test_time_pose_opt` default to False [primary: code]. DyCheck evaluation uses test-time pose
  alignment.

## 4. Numbers

All runs are on "a single NVIDIA A100 GPU" (§4.1); 40 GB or 80 GB is not stated [primary].

| What | Value | Source |
|---|---|---|
| Reconstruction time, example | "about 30 minutes" for a 270-frame 480×360 video at 30K iterations | §4.1 [primary] |
| Reconstruction time per scene | NVIDIA 0.29–0.36 h (mean 0.31 h, 30K it); DyCheck 1.54–2.30 h (mean 1.81 h, 100K it) | Table 12 [primary] |
| Shorter schedule | DyCheck at 45K it: 0.85 h and 19.44 mPSNR, against 1.8 h and 19.50 | Table 11 [primary] |
| Excluded from those times | Preprocessing. The mask pipeline alone takes 34.133 s (flow 1.763 + segmentation 23.151 + Sampson 8.308 + composition 0.911 s); video length and GPU not stated. Pose, depth and tracking times are not reported. | Table 5 [primary] |
| Render speed | ~160 FPS for the 480×360 example; 132 FPS on DyCheck (resolution not stated); 196 FPS for the 45K model | §4.1, Table 11 [primary] |
| Inference memory | 1.0 GB (DyCheck, column "Infer. Mem") | Table 11 [primary] |
| Training VRAM | 0.50–9.12 GB per scene; mean 2.99 GB (NVIDIA), 3.69 GB (DyCheck) | Table 12 [primary] |
| Gaussian count | 0.18–0.45 M per scene. NVIDIA mean 344,947 (302,236 static + 42,710 dynamic); DyCheck mean 295,965 (221,396 + 74,568). Rigid vs transient split not given. | Table 12 [primary] |
| Dynamic-mask quality | DAVIS 2016 IoU: RiGS 81.9 in 34.1 s; SegAnyMo 85.3 in 176.3 s; RoMo 65.9 in 552.7 s | Table 6 [primary] |

**Quality on the main benchmarks** [primary]:
- **NVIDIA Dynamic Scenes** (7 scenes, DynamicNeRF protocol, Table 1): RiGS 27.43 PSNR / 0.051 LPIPS. The strongest
  baseline, MoSca, scores 26.72 / 0.070, so RiGS gains 0.71 dB. Best baseline LPIPS: RoDynRF, 0.067. Table 1 has no
  SSIM column; Table 3 gives 0.879 for the full model.
- **DyCheck iPhone** (7 scenes, masked metrics, Tables 2 and 13): RiGS 19.50 mPSNR / 0.705 mSSIM / 0.240 mLPIPS.
  MoSca scores 19.32 / 0.706 / 0.264, close to a tie. Shape of Motion: 17.32 / 0.598 / 0.296.
- **Baseline provenance:** whether baselines were re-run on the same A100 or copied from their papers is not stated
  (Table 11). MoSca's per-scene numbers are rounded, which suggests they were copied [inference].
- **Ablation** (Table 3, NVIDIA PSNR, full model 27.43): a per-pixel Sampson mask in place of the object-wise one
  26.00 (**−1.43 dB**, the largest effect); no transient Gaussians 26.87; no rigid Gaussians 27.11; no scene flow 27.27.

**Datasets** [primary]:
- NVIDIA Dynamic Scenes (7 scenes, people and objects close to the camera).
- DyCheck iPhone: 7 scenes evaluated (§4.2 says the dataset has 14), handheld moving camera, LiDAR depth.
- DAVIS: Judo and dog-agility, qualitative only; DAVIS 2016 for mask IoU.
- **No driving dataset.** Waymo, nuScenes, KITTI, Argoverse and PandaSet are never mentioned. Driving appears once, as an
  application in the introduction, citing DeSiRe-GS.

**Context** [inference]: 160 FPS at 480×360 (0.17 MP) is not faster per pixel than Street Gaussians' 135 FPS at
1066×1600 (1.7 MP, on a 4090). 30 min for 270 frames is about 6.7 s of optimisation per input frame.

## 5. Limitations

**The authors' own** [primary]. There is no limitations, failure-case or future-work section; I searched for those
words, and every failure shown is a baseline's. The closest admissions:
- App. 8: averaging the score over a whole object means "localized motions are diluted by the dominant static parts of
  an object".
- Over-marking (calling too much dynamic) helped on Balloon2, 28.25 → 28.45 PSNR (Table 7).
- §3.4: the bases alone lack "flexibility in modeling short-term, high-frequency, or locally complex motions", which is
  why transient Gaussians exist.

**For our goal** [inference]:
1. **Monocular only.** With 6–8 cameras the poses would come from the dataset, which is easier than ViPE. But the mask
   step runs per video, and nothing links an object's ID across cameras. Tracks, the basis initialisation and the code
   all assume one video.
2. **Ego-motion at 50–100 km/h** is 13.9–27.8 m/s, or 1.4–2.8 m between frames at 10 Hz. The test cameras barely move
   (NVIDIA uses a camera rig; DyCheck is handheld). Worse, the motion score is an epipolar test:
   - Under forward ego-motion, epipolar lines radiate from the focus of expansion.
   - A car driving straight ahead or straight towards us therefore moves *along* its epipolar line. Its Sampson error
     stays near zero, and it would be labelled static.
   - That is the most common case on the road. Driving data gives poses and depth, so a 3D residual after removing
     ego-motion is the right score there.
3. **Large unbounded scenes.** The tested scenes are small (0.18–0.45 M Gaussians). There is no sky or far-field model
   and no LiDAR or SfM initialisation, both of which Street Gaussians relies on for streets.
4. **Many independent movers.** Ten scene-wide bases must explain every mover. Dozens of cars moving differently would
   need K to grow with the number of objects. The busiest test scene is Playground.
5. **Fast movers.** Transient Gaussians (a straight line plus a lifespan) suit brief, fast objects in principle. They
   are untested at road speeds.
6. **Run time.** 17–22 min (NVIDIA) to 1.5–2.3 h (DyCheck) per clip on an A100, plus preprocessing. That is the same
   class as Street Gaussians (~30 min) and roughly 5,000–40,000× slower than Tesla's ~220 ms.

## 6. Fit for our goal

**Roadmap stage.** A side read for Stage 6 (per-scene dynamic reconstruction), next to its "People" and "tracker recall"
bullets. It does not belong in Stage 7: there is no feed-forward network. Its transient Gaussians (position + velocity +
lifespan) parameterise motion the same way as STORM's per-Gaussian velocities and DGGT's lifespan head (research/07)
[inference].

**Could its rigid-part discovery replace Street Gaussians' tracked 3D boxes? No.**
- It outputs a 2D binary moving/static mask per SAM object, with no 3D boxes and no per-object pose tracks [primary].
- Its "rigid" motion comes from scene-wide k-means over track velocities, with no object identity
  [primary: paper and code]. So there is no per-car cloud to move, delete or swap, which is what box-frame clouds give
  [inference].
- It has the forward-motion blind spot above [inference].
- **What it could add:** catching movers the tracker missed, so they do not smear into the background (Street Gaussians'
  limit #2) [inference].

**Pedestrians.** RiGS uses no body model [primary]. A person is a set of dynamic Gaussians blended from the global
bases, plus transient Gaussians for fast, short-lived parts. It was tested only on people close to the camera: NVIDIA
Jumping, Skating, Umbrella and Playground, and DAVIS Judo (qualitative) [primary]. OmniRe's SMPL bodies remain the
driving-tested option [inference].

**Running it on the 5070 Ti (16 GB):**
- **Measured, on an A100:** training VRAM up to 9.12 GB (Teddy), inference memory 1.0 GB, at most 0.45 M Gaussians
  [primary].
- **Inferred:** one clip's training and rendering fit in 16 GB. Preprocessing memory (ViPE, SAM, BootsTAP) is unknown,
  and render speed on a 5070 Ti has not been measured anywhere.
- **Software** [primary for the pins and files; inference for the rest]:
  - `requirements.txt` pins `torch==2.11.0+cu128`, `torchvision==0.26.0+cu128` and `cuda-toolkit==12.8.1`. That meets
    our PyTorch ≥ 2.7 / CUDA 12.8 rule, but no PyTorch wheel index is listed, so the install may need
    `--index-url .../whl/cu128`.
  - These compile CUDA and need `TORCH_CUDA_ARCH_LIST=12.0`: gsplat and fused-ssim (both installed unpinned from git),
    and the ViPE fork's `csrc/`, which has `.cu` files such as `corr_ext/correlation_cuda_kernel.cu`.
  - RAPIDS cuML 26.2 (used for k-means) runs on Linux, or on Windows through WSL2. NVIDIA's platform page lists
    Blackwell 120 [secondary].
- **Blocker, verified today: it cannot train on any GPU** [primary].
  - `src/runner/__init__.py` imports `.dynamic`, `.static` and `.fused_v2`, and all three files return 404 on `main`.
  - Issue #2 (25 Jun 2026) reports this. It is still open with no maintainer reply.
  - In issue #3, one user could not finish ViPE preprocessing on a 4090 after more than an hour.

**The one idea worth borrowing: decide moving vs static per object, not per pixel**, and supervise the rendered dynamic
mask with that decision. In Table 3 this is the largest single effect: a per-pixel Sampson mask costs 1.43 dB.
- **Our version** [inference]: segment instances in each camera, score each one with a 3D residual after removing
  ego-motion (we have poses and depth), and send whole instances to the dynamic set.
- **Uses** [inference]: a safety net for objects the tracker missed, and a label-free moving-object mask for STORM-style
  training.
- **Authors' standalone code** [primary]: `ladvu/EasyMoSeg`, MIT licence, 2 commits, SAM1 and SAM2 submodules. Its README
  just says "TODO".

**Verdict: useful idea.** Read §3.3 and Table 3 (about 30 minutes) and skip the rest. Reasons: it is monocular, tested
only on small scenes, needs 20 min to 2 h of per-scene optimisation, has no driving data and no licence, and its
released code does not run.

## 7. Dead ends: what I couldn't find or confirm

- **Venue.** "(CVPRF)" is unconfirmed: the CVF open-access Findings list returned 403, and web search found no listing.
- **Rigid→transient threshold.** The paper gives no value, and the code's `lifespan_thres = 3.0` cannot be tied to it
  because the runner code that would use it is missing. "βr is set to 2.0" (§4.1) is ambiguous: Table 9 sweeps βr = 1–10
  and peaks at 4 (27.49 PSNR).
- **Not stated in the paper:** how v is initialised at conversion, how 2D tracks are lifted to 3D, whether colour is RGB
  or spherical harmonics, and the evaluation resolution for NVIDIA and DyCheck. The only stated resolution is the
  480×360 timing example; the code's default `data_factor = 2` halves images [primary: code].
- **Preprocessing time** for pose, depth and tracking is not reported anywhere. Table 5 does not give the video length or
  GPU for its 34.133 s; it matches Table 6's 34.1 s, so it is probably one DAVIS video [inference].
- **Code vs paper:** the code has `alpha_lambda = 0.1` while the paper has λ_α = 0.5. They may be different terms
  [UNCERTAIN].
- **Repo:** the GitHub git-tree and issue-comment API calls returned 403 (rate limit), so I checked key files through raw
  URLs and web pages instead. I have not ruled out `.cu` files inside RiGS itself.
- **Weights:** no RiGS scene checkpoints are released. Issue #1 (Hugging Face hosting) has no reply.
- **Repo stats** [primary: API]: created 2026-04-07; last push 2026-06-05; 3 commits ("init", "clean up", "update
  readme"); 28 stars, 2 forks, 3 open issues; `license: null`.
