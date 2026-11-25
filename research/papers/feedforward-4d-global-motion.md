# C4G / T4GS: "Learning Global Motion with Compact Gaussians for Feed-Forward 4D Reconstruction"

Read 2026-11-25 for the TeslaRender goal: surround cameras → a dynamic Gaussian world, rendered in real time.

**Sources** (nothing was downloaded, installed or run):
- arXiv abs page and the full HTML of v1, body and appendices A–F, read through a summarising fetch tool. Table 1 was
  extracted twice and gave identical numbers.
- The repo through the GitHub API: README, LICENSE, configs, encoder/decoder/test-loop source, issues.
- The Hugging Face paper and model APIs, the project page, and Table 13 of the parent paper C3G (arXiv 2512.04021).

**Tags:** `[primary]` = read at source (paper, page, repo, API); `[secondary]` = summary or search snippet;
`[UNCERTAIN]` = could not confirm; `[inference]` = my own reasoning or arithmetic.

**Bottom line:** one camera, no poses, 224×224 input, and a whole small scene described by 2,048 Gaussians that are
re-decoded for each requested time. The paper reports **no run time, FPS or memory at all**, reconstructs no driving
data, and the weights are non-commercial. **Verdict: useful idea** (a fixed Gaussian budget, independent of
cameras × pixels); do not build on this model.

## 1. Citation

- **Title:** "Learning Global Motion with Compact Gaussians for Feed-Forward 4D Reconstruction"; the method is C4G
  `[primary: arXiv abs]`. The repo, weights and project page now say **"T4GS: Learning Temporally Aware Compact
  Gaussians for Feed-Forward 4D Reconstruction"**; arXiv still lists only v1 under the old title `[primary]`.
- **Authors:** Mungyeom Kim\*, Minkyeong Jeon\*, Honggyu An\*, Jaewoo Jung, Hyuna Ko, Jisang Han, Hyeonseo Yu,
  Donghwan Shin, Sunghwan Hong, Takuya Narihira, Kazumi Fukuda, Yuki Mitsufuji†, Seungryong Kim† (\* co-first,
  † co-corresponding). KAIST AI; ETH Zürich / ETH AI Center; Sony AI; Sony Group Corporation `[primary: paper, README]`.
- **Venue:** arXiv preprint only, no conference named. **arXiv 2605.31595**, v1 submitted 29 May 2026, paper licensed
  CC BY 4.0 `[primary]`.
- **Project page:** https://cvlab-kaist.github.io/T4GS/ — no numbers; its "Quantitative Results" section is empty. The
  link in the arXiv comment (`cvlab-kaist.github.io/C4G`) returns 404 `[primary]`.
- **Code:** https://github.com/cvlab-kaist/T4GS; `repos/cvlab-kaist/C4G` resolves to it (renamed). Created 2026-05-22,
  last push 2026-10-29, 103★, 9 forks, 3 open issues; GitHub's licence field says "Other / NOASSERTION" (see §7)
  `[primary: GitHub API, 2026-11-25]`.
- **Weights: released.** https://huggingface.co/mungyeom011/T4GS: `t4gs.ckpt` (4,055,309,594 B) and
  `t4gs_vdm_refinement.safetensors` (175,017,544 B), tagged `license:cc-by-nc-4.0`, base models VGGT-1B and C3G
  `[primary: HF API, model card]`.

## 2. The problem

Feed-forward 4D models (4DGT, MoVieS, NeoVerse) predict Gaussians per pixel per frame. The authors say this gives
hundreds of thousands of near-duplicate Gaussians, ghosting at target timestamps, and a "view-dependent bias" that stops
the model using temporally distant frames to fill occluded regions (Fig. 1) `[primary]`. C4G instead turns an unposed
monocular video into a small, fixed set of Gaussians whose positions depend on the requested time, in one forward pass
`[primary: abstract, §3]`.

## 3. How it works

**What each Gaussian stores** `[primary: §3.1, §4.1, gaussian_adapter.py]`
- 14 numbers: mean (3, an offset from a fixed anchor at (0, 0, 1)), opacity (1), scale (3), rotation quaternion (4), and
  colour at SH degree 0, i.e. one RGB (3). `[inference]` 56 B in fp32, so a whole instant is ≈ 115 KB (2,048 × 56 B).
- **No** velocity, motion basis, per-Gaussian trajectory, deformation field, static/dynamic flag or lifespan `[primary]`.

**How motion is modelled** `[primary: §3.2 Eq. 1–2, §4.3, encoder_vggt.py]`
- N = 2,048 learnable query tokens (width 2,048), each decoded into exactly one Gaussian. A sinusoidal time embedding ψ,
  passed through a 2-layer MLP H, is added to the tokens: F̂_t = F_t + H(ψ(t)) for context frames, Q̂_tb = Q + H(ψ(t_b))
  for the queries.
- The decoder runs **once per requested time t_b**: "Iterating over t_b ∈ 𝒯 yields a full dynamic reconstruction". The
  same query index at different times is an implicit trajectory; App. D builds point tracks from these centres.
- **"Global motion" is never formally defined.** Each Gaussian is placed from "the full global temporal context" (all
  context frames), which "forces the Gaussians to capture global motion rather than overfitting to individual frames"
  (§1, §4.3). Each query is reported to settle on "a distinct semantic region of the scene". That is read off attention
  maps (§3.3, Fig. 4); nothing in the design enforces it.
- The released checkpoint encodes time differently from v1: v1 normalises time so the target is 1 (A.1); the release
  embeds t − t_target with sinusoid period 100 `[primary: config/training/t4gs.yaml, HF card]`.

**Pipeline** `[primary: §3.2, A.1, code]`
1. Context frames are resized to 224×224, in training and at test (the test loop does it).
2. VGGT's aggregator encodes all frames jointly, **once per clip** ("extracting visual features once"): a DINOv2-L patch
   embed, then 24 frame- and 24 global-attention blocks at width 1,024. Its camera/depth/point/track heads are deleted.
3. A 2-layer transformer (width 2,048, 16 heads, MLP 4,096) runs self-attention over all context patch tokens plus the
   2,048 queries, **once per target timestamp**.
4. A linear layer turns each query into one Gaussian; a CUDA 3DGS rasteriser renders them.
5. Optional, and off for every benchmark number (README, HF card): video-diffusion "rendering enhancement" with
   Wan2.1-VACE-1.3B + a rank-128 LoRA, captions from Qwen3-VL-8B-Instruct. Also optional: "any-feature 4D lifting" of
   DINOv3 / VGGT / LSeg features (§3.4), whose code is not released.

**Losses** `[primary: §4.1, A.2, C.3]`
- Colour: MSE + 0.05·LPIPS on target views; dynamic pixels weighted λ_dyn = 3 (mask from an unnamed segmenter).
- Scale-shift-invariant depth and L1 normals against MoGe-2 pseudo-labels, λ = 0.001 each.
- Tracking: Huber between projected Gaussian centres and CoWTracker tracks where visibility > 0.5, λ = 0.1.
- Released recipe only, not in arXiv v1: 3D flow on moving and still pairs plus 2D flow, supervising the per-timestamp
  Gaussians, from Kubric/Spring ground truth or RAFT + MoGe pseudo-labels on EgoExo4D `[primary: t4gs.yaml]`.

**Pretrained models it leans on** `[primary: README, paper]`: VGGT-1B (backbone, via C3G); C3G (static compact-Gaussian
parent, initialises the decoder); MoGe-2 (depth/normal labels); CoWTracker (track labels); torchvision RAFT (flow
labels); Wan2.1-VACE-1.3B (optional refinement); Depth Anything 3 (camera poses for in-the-wild demos).

**Camera poses** `[primary: §3.1, B.2, code]`
- **Input: none.** The network sees only images and frame indices; no intrinsics or extrinsics.
- **Output:** a frame where the first context camera is the identity, at arbitrary scale. Rendering still needs a camera
  in that frame:
  - benchmarks align target poses at test time "following NoPoSplat", optimising them against the ground-truth target
    image. The released code allows up to 1,000 Adam steps per timestamp, early stop after 100 (`config/main.yaml`,
    `model_wrapper.py`);
  - the in-the-wild demo takes poses from Depth Anything 3 (`DA3-LARGE-1.1`) plus mean RealEstate10K intrinsics
    (`scripts/render_qualitative_davis.py`).

## 4. Numbers

| Quantity | Value | Source |
|---|---|---|
| **Reconstruction latency** | **Not reported**: not in the paper, appendices, project page, README or model card | `[primary]`, all five read |
| Render FPS, inference VRAM, FLOPs | Not reported | `[primary]` |
| Timing in the code | Test loop times "encoder" (backbone + every per-timestamp decoder pass), the rasteriser, and pose alignment separately; writes `benchmark.json` and `peak_memory.json` | `model_wrapper.py` `[primary]` |
| Gaussians per timestamp | **2,048** ("2K"). 4DGT 272K, MoVieS 802K, NeoVerse 802K, Shape of Motion 128K, MoSca 342K | Table 1 `[primary]` |
| Input | 1 camera, 224×224. Benchmark context 32 frames (DyCheck, stride 2) or 16 (ADT, TUM stride 6; NVIDIA stride 2). Training clips 12 context + 11 target frames | §4.1, B.1, A.5, configs `[primary]` |
| Model size | 4.06 GB fp32 checkpoint, "weights only" → ≈ 1.0 B parameters | HF API `[primary]`; count `[inference]` |
| Training, C4G stage | 4× H100, batch 1 per GPU, AdamW 1e-5 (backbone 1e-7). 30k steps per README/config, none in the paper. Wall-clock not stated | §4.1, README `[primary]` |
| Training, inherited | C3G: 8× H100, batch 8 per GPU, 450K steps. VGGT-1B: 64× A100 for 9 days | C3G paper `[primary]`; research/07 |
| Diffusion module | 4× H100, 50K steps, LoRA rank 128, 480×832, Kubric | A.4 `[primary]` |
| Parent C3G (static; same backbone and 2-layer decoder) | 2 views 0.091 s, 4,150 MiB; 24 views 0.466 s, 4,372 MiB; 4.273 s with test-time optimisation. GPU and resolution not stated | C3G Table 13 `[primary]`, a different paper |

**Main benchmark, Table 1** `[primary]`: novel views from monocular input, no diffusion, metrics on co-visible regions
only (§4.2). PSNR / SSIM / LPIPS.

| Dataset | C4G | Strongest other method |
|---|---|---|
| DyCheck (5 scenes) | 15.64 / 0.388 / 0.384 | Shape of Motion (per-scene) 14.13 / 0.313 / 0.690; best LPIPS MoVieS 0.359 |
| ADT (4 sequences) | 22.35 / 0.631 / 0.313 | NeoVerse 21.94 / 0.629 / 0.270; best SSIM / LPIPS 4DGT 0.717 / 0.260 |
| TUM-Dynamics (9 videos) | 19.52 / 0.603 / 0.306 | 4DGT 17.27 / 0.578 / 0.329 |
| NVIDIA (7 scenes) | 20.51 / 0.489 / 0.393 | NeoVerse 15.86 / 0.322 / 0.492 |

- `[inference]` The caption's "superior rendering quality across all datasets" holds for PSNR only; on ADT (SSIM,
  LPIPS) and DyCheck (LPIPS) another method wins.
- **The lead grows as inputs get sparser** (Table 2, TUM) `[primary]`: at frame gap Δt = 2 NeoVerse beats C4G on SSIM /
  LPIPS (0.671 / 0.216 vs 0.647 / 0.267); at Δt = 8 C4G keeps 19.23 dB while NeoVerse falls to 15.94 and 4DGT to 16.27.
- **Point tracking**, δ16 at Δt = 2/4/8/16 (Table 10) `[primary]`: DriveTrack C4G 55.51 / 52.00 / 37.19 / 49.89 vs
  NeoVerse 47.77 / 47.81 / 33.26 / 41.95; on ADT NeoVerse wins (96.06 / 97.83 / 94.67 / 82.76 vs 93.98 / 88.43 /
  76.06 / 71.86).
- **With the diffusion module** (VBench, 100 in-the-wild videos, Table 7): image quality 0.4483 vs NeoVerse 0.6401
  `[primary]`.

**Datasets** `[primary unless tagged]`
- Training, arXiv v1: Spring (37 scenes), Kubric (1,144 synthetic scenes × 4 camera trajectories), RealEstate10K
  (static). The released recipe adds EgoExo4D: Kubric 0.35, EgoExo4D 0.30, RE10K 0.25, Spring 0.10 (README).
- Tests: DyCheck, Aria Digital Twin, TUM-Dynamics, NVIDIA Dynamic Scenes (view synthesis); RGB-Stacking and DAVIS
  (feature lifting); DAVIS (segmentation).
- **Driving: no reconstruction or view synthesis.** The only driving data is DriveTrack, for point tracking (App. D).
  DriveTrack is point-track annotation on Waymo Open Dataset video `[secondary: search result for the DriveTrack
  paper]`. No Waymo, nuScenes, KITTI, Argoverse or PandaSet reconstruction. STORM, DGGT, VGD and other driving models
  are neither cited nor compared (keyword search of the HTML).

## 5. Limitations

**The authors' own (App. F)** `[primary]`
- Gaussians exist only for regions seen at least once. Distant viewpoints and regions hidden in every input frame render
  as holes "with zero-valued pixels"; the diffusion fill "tends to hallucinate plausible content".
- It "cannot extrapolate beyond the temporal range of the input views": trained only on interpolated timestamps, it
  cannot predict future Gaussians.
- Also in the paper, though not listed as a limitation: pose-free output has arbitrary scale, so the benchmarks need
  test-time pose alignment (B.2).

**What matters for our goal** `[inference unless tagged]`
- **Monocular only.** No camera-ID, rig or calibration input. Its only multi-view exposure is Kubric training clips that
  add one frame from each of 4 viewpoints `[primary: A.5]`. Feeding 6–8 surround cameras as one token sequence is
  untested and multiplies the tokens 6–8×.
- **Pose-free is the wrong trade for a car.** We have calibrated rigs and metric ego-motion. C4G ignores both, returns an
  arbitrary scale, and needs a separate pose model (DA3) just to render.
- **Ego-motion.** At 50–100 km/h a car moves 1.4–2.8 m per frame at 10 Hz. The training videos (synthetic objects, room
  walk-throughs, ego/exo-centric human video) move far less.
- **Large, unbounded scenes.** 2,048 Gaussians from 224×224 input for the whole scene; per-pixel driving models at 8
  cameras produce 0.3–1.8 M per update (research/11). One user reports "severe blur" without the diffusion module, lower
  PSNR/SSIM/LPIPS than NeoVerse on their own benchmark, and scale misalignment that pose optimisation sometimes made
  worse `[primary: GitHub issue #3, a user's unverified report]`.
- **Fast movers.** No velocity: every instant costs a decoder pass, and nothing after the last input frame can be
  rendered. In its favour: robust to large frame gaps (Table 2), and the best DriveTrack tracking among the feed-forward
  methods compared (Table 10).
- **Run time** is unknown (estimate in §6). The decoder re-attends to every context token for each timestamp, so
  decoding every frame of a clip costs more than encoding it.

## 6. Fit for our goal

**Roadmap stage 7** (feed-forward reconstruction), as the counterpoint to pixel-aligned splats (pixelSplat, MVSplat,
STORM, DGGT). It does not replace DGGT as the stage 7 build.

| | STORM | DGGT | VGD | C4G |
|---|---|---|---|---|
| Cameras × frames, resolution | 3 × 4, 160×240 | 3 × 4, 518×518 | 6 × 1–2, 352×640 | 1 × 16–32, 224×224 |
| Gaussians | per pixel, with velocities | per pixel, plus dynamic and lifespan heads | — | 2,048 per timestamp, re-decoded |
| Measured latency | 0.18 s, A100 | 0.39 s, A100 | 0.26 s, A100, bf16 | **none published** |
| Built for driving | yes, Waymo | yes, Waymo | yes | no |

STORM, DGGT and VGD are from research/06–07 ("—" = not recorded there); C4G from this paper `[primary]`. Like DGGT, C4G
needs no input poses.

**Could it run on the 5070 Ti 16 GB?**
- **Measured: nothing for C4G.** The parent C3G measured 4,150–4,372 MiB (≈ 4.1–4.3 GiB) and 0.091–0.466 s for 2–24
  views, on an unnamed GPU `[primary]`.
- **Software** `[primary: requirements.txt, README, main.py]`: PyTorch 2.2.0 + CUDA 12.1, xformers 0.0.24, Python 3.10,
  and a custom CUDA rasteriser (`diff_gaussian_rasterization_w_pose`, Inria non-commercial licence) built from source.
  The Trainer sets no precision flag, so runs are probably fp32 `[inference]`.
- **Porting** `[inference]`: needs torch ≥ 2.7 with CUDA 12.8, a matching xformers (or none), and the rasteriser rebuilt
  with `TORCH_CUDA_ARCH_LIST=12.0`. The Mac is out: no CUDA rasteriser.
- **Memory** `[inference]`: ≈ 1 B parameters is 4.1 GB in fp32. The decoder uses fused `scaled_dot_product_attention`,
  so no attention matrix is stored `[primary: gmae.py]`. C3G used 4,372 MiB for 24 views, so 16–32 frames should fit.
- **Speed** `[inference; treat as ±3×]`, FLOPs from the code's dimensions at 224×224:
  - VGGT encoder ≈ 9.5 TFLOP for 16 frames, ≈ 22 TFLOP for 32. Decoder ≈ 1.4 TFLOP per decoded timestamp at 16 frames,
    ≈ 3.1 at 32. Decoding all 16 timestamps (≈ 23 TFLOP) costs more than encoding them.
  - Cross-check: C3G's 0.466 s for 24 views is ≈ 18 TFLOP, i.e. ≈ 38 TFLOPS achieved on its unnamed GPU.
  - If the 5070 Ti achieves 22–44 TFLOPS (25–50 % of its 87.9 dense FP16 TFLOPS; fp32 sits at the slow end): encoding
    16 frames ≈ 0.2–0.45 s, plus ≈ 33–66 ms per decoded timestamp, so ≈ 0.75–1.5 s for a 16-frame clip decoded at every
    frame. That is 3–7× Tesla's ~220 ms, for one 224×224 camera instead of eight.
  - Easy saving: a frozen depth head runs on every call, only for visualisation `[primary: encoder_vggt.py]`.
- **Fine-tuning on one 24 GB 4090** `[inference]`: the full recipe will not fit. ≈ 1 B parameters under AdamW is ≈ 16 GB
  of weights, gradients and optimiser state before activations, and MoGe-2, CoWTracker and RAFT are loaded as
  supervisors. A decoder-only fine-tune (≈ 72 M parameters; the encoder config has `freeze_backbone` `[primary]`) should
  fit.

**The one idea worth borrowing: make the Gaussian count a fixed budget, not "one per pixel per camera".** Learnable query
tokens attend over the features of the whole clip and are decoded at whatever time you ask for; each token keeps its
identity over time, which gives tracks for free. `[inference]` For us: a query set per tracked agent (or per region) for
the movers, on top of a pixel- or voxel-aligned static background, so the dynamic part stops growing with cameras ×
pixels. Batch the timestamps; the released code decodes them one at a time in a Python loop `[primary: encoder_vggt.py]`.

**Verdict: useful idea.**
- Not a must-read: monocular, 224×224, pose-free, 2,048 Gaussians, no driving reconstruction, no run time,
  non-commercial weights.
- Not a skip: the only design in our notes whose Gaussian count does not grow with cameras × resolution, which is the
  scaling problem research/07 and research/11 identify.
- Read §3.2, Tables 1–2 and App. F; skip §3.4 and the diffusion module.

## 7. Dead ends

- **No run time anywhere:** no reconstruction latency, render FPS, VRAM or FLOPs for C4G in the paper (every section and
  appendix), project page, README or model card. The code can produce them; none are published.
- **Training gaps:** wall-clock and H100 memory size not stated; the 30k-step count is only in the README and config.
- **Evaluation resolution not stated.** The code resizes the context to 224×224; the target render size comes from the
  evaluation loaders, which I did not read.
- **Baseline inputs:** not stated whether baselines got the same context frames, or ground-truth vs estimated poses. B.3
  says only that NeoVerse gets the same test-time pose alignment.
- **Inconsistencies in the paper** `[primary]`: ablation "Ours" scores (DyCheck 15.54, TUM 18.94) differ from Table 1
  (15.64, 19.52) without explanation; MoSca's ADT PSNR is printed as 2.419, probably a typo; App. C.2's text says
  "Bonn" where its table says TUM-Dynamics; §3.3 says "trained solely with the rendering loss", yet depth, normal and
  tracking losses are used.
- **Released weights vs the paper** `[UNCERTAIN]`: code and weights follow the revised "T4GS" recipe (relative time
  embedding, EgoExo4D, flow losses). Nothing shows that `t4gs.ckpt` reproduces arXiv v1's Table 1.
- **The licence came late** `[primary]`: LICENSE (MIT for the project's own code) and THIRD_PARTY_LICENSES.md first
  appeared on 2026-10-27; issue #4 (2026-08-28) asking for a licence is still open. Third-party parts are
  non-commercial: the Inria rasteriser, CoWTracker (FAIR non-commercial), CroCo (CC BY-NC-SA); VGGT keeps its own
  licence.
- **DriveTrack's link to Waymo** comes only from a search snippet; the paper gives no DriveTrack sequence count, camera
  or resolution.
- **C3G is a loose anchor:** its timing GPU and resolution are not stated.
