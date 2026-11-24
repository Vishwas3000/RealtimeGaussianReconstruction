# 09 — How much compute does real-time generative world simulation take?

Research date: **2026-11-24**. Light web research only: nothing downloaded or run.
Question: Tesla says its neural world simulator renders **all 8 cameras at 24 fps**, in real time and closed-loop with a human driver (see 01).
It has disclosed no architecture or hardware. This file collects **measured** speed and hardware from published systems, so the gap can be bounded.
Trust tags: **[P]** = read at the source (arXiv HTML text/tables, README, repo config, vendor page); **[S]** = press/secondary;
**[U]** = uncertain. **[arith]** = plain arithmetic on stated numbers, not a compute estimate. "n/r" = not reported where I looked.
All 26 arXiv IDs below were checked by title against the arXiv export API on 2026-11-24. All repos were checked with `gh api`.

## TL;DR

- **The only published real-time *multi-camera* driving number is NVIDIA OmniDreams** (2606.03159). OmniDreams-MV renders **4 views at 704×1280: 12 FPS per camera on 1×GB300, 48 on 4, 74 on 8, 105 on 16 GB300** (151 ms per 16-frame chunk). It is a 2B model run at 2 denoising steps [P, §5.3 Table 3]. The famous "68 FPS" is the **single-view** model (8-frame chunks, 118 ms each) on **one GB300** [P, Table 2]. NVIDIA defines real time as 30 FPS and says it is reached "on up to four cameras on NVIDIA GB300" [P, §9.1].
- **[arith] Tesla's claim is 8 × 24 = 192 camera-frames/s.** OmniDreams-MV on 4×GB300 delivers 4 × 48 = 192 camera-frames/s at 704×1280. Going from 4 to 8 views is not free, because cross-view attention grows. Tesla's per-camera resolution is unknown. So the closest public anchor is **"several datacenter Blackwell GPUs per simulator instance, with a ~2B, 2-step model"**, not one chip.
- **Other surround-view systems are much slower or undisclosed.** ZYT-World (5B, 1 step, 7 native ~720p views) runs at **4 FPS on 2 GPUs**; the GPU type was not found [P]. FAR-Drive (3.7B, 6×576×1024) takes **1.15 s per six-view frame on 1×H200** at 3 steps [P]. Decart Oasis 3 claims **22 FPS at 512×768 ×3 cameras, <200 ms latency** on HGX B200, GPU count not stated; it is API-only [P-vendor]. Cosmos-Predict2.5 multiview, GAIA-2/3 and Waymo's World Model publish **no speed at all**.
- **Every real-time system uses the same recipe.** Start from a pretrained bidirectional video DiT (Wan, Cosmos or HunyuanVideo, 1.3–14B). Make it causal or block-causal with a KV cache and a bounded window. Distil it to **1–4 steps** (Self-Forcing/DMD, consistency distillation, rCM, PCM). Swap in a **tiny VAE decoder**. Run attention and GEMMs in **FP8**, capture **CUDA graphs**, and shard across GPUs **by camera first**. Measured gains: 40→1 step gave a 107.7× faster generator (ZYT); a tiny VAE decoded 59.8× faster (ZYT); 16.7→29.5 FPS from the tiny VAE alone (MotionStream); 2.8→24 FPS from parallelism plus quantization (WorldPlay).
- **Compute anchors.** MAGI-1 is the only paper that states FLOPs: **~9 PFLOPS per second of 480p video** (24B model, 16 steps), served in real time on **24×H100/H800 with FP8** [P]. Single-GPU real time at 480p exists only for **~1.3–2B models at 2–4 steps** (Self-Forcing 17 FPS, LongLive 20.7, Matrix-Game 2.0 25, MotionStream 29.5, all on 1×H100). A 14B model reaches **11 FPS on 1×B200** (Krea) or **39 FPS at 480p on 4×H100** with pipelining (StreamDiffusionV2). Genie 3 (24 fps, 720p), Waymo, GAIA-3 and Tesla disclose no hardware.

## A. Driving world models

| System | Source | FPS / time (as stated) | Resolution | Views | GPU × count | Precision | Steps | Params | Tricks | Where | Tag |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **OmniDreams-SV** | 2606.03159 (code: NVIDIA/flashdreams, Apache) | **68 effective FPS**; 118 ms per 8-frame chunk; 78/100/103 FPS on 2/4/8 GPUs | 704×1280 | 1 | **1×GB300** | paper n/r; released GB300 config uses quantized SDPA, other presets FP8 KV/projections | **2** (no CFG: `guidance_scale=1.0`) | 2B (Cosmos-Predict2.5 base) | Self-Forcing+DMD with a long-context teacher, rolling KV, window 6 latents, LightVAE in / LightTAE out, static-shape KV + CUDA graph, KV update on a side thread | §1, §5.1–5.3 Table 2; `integrations_v2/omnidreams/config.py` | [P] |
| **OmniDreams-MV** | same | **12 / 48 / 74 / 105 FPS per camera** on 1/4/8/16 GPUs; 1,289 → 151 ms per 16-frame chunk | 704×1280 | **4** (cross-left, front-wide, front-tele, cross-right) | **1–16×GB300** | n/r | 2 | 2B | Same, plus pixel-shuffle condition encoder and context parallelism over cameras → time → space; window 8 latents | §5.2–5.3 Table 3, §9.1 | [P] |
| OmniDreams RTX 5090 presets | flashdreams docs | "real-time" claimed, **no FPS given** | 1168×640; "-fast" preset 1024×560 | 1 | 1×RTX 5090 (32 GB); text encoder on CPU | FP8 LightVAE, Sage3 FP8 attention | 2 | 2B | Shorter window (`window_size_t=4`) | `docs/source/models/omnidreams.md`; config docstring | [P] |
| **ZYT-World** | 2609.21712 (2026-09) | **4 FPS for the full 7-view rig**; generator 107.7× faster than the 40-step teacher | native ~720p per view (aspect 5:1 to 5:4) | **7** (4 fisheye + 3 pinhole) | **2 GPUs, type not found** | W8A8 | **1** (1/2/4-step students exist) | 5B DiT | TF → consistency distill → self-rollout DMD + RigCritic; 19M TinyVAE (vs 555M Wan decoder, 59.8× faster) | Fig. 1–2, §3, §6.1 | [P] |
| FAR-Drive | 2603.14938 | **1.15 s per six-view frame** (3 steps); 0.84 s (1 step); 15.94 s/it at 20 steps with no optimisations | 576×1024 | 6 (nuScenes) | **1×H200** (an NPU is also in Table 4) | n/r | 1–20 | 3.7B | Frame-level AR, KV/latent caching, condition caching, CFG off | §4.3 text, Table 4 | [P] |
| Oasis 3 (Decart, 2026-06) | decart.ai vendor page | **22 FPS, <200 ms latency** | "512×768×3" | **3** synchronized | NVIDIA HGX B200 on CoreWeave; **count n/r** | n/r | n/r | n/r | n/r; API only | vendor page | [P-vendor] |
| X-World (XPeng) | 2603.19979 | n/r ("low-latency" streaming) | n/r | multi-cam | n/r | n/r | 4 per chunk | n/r | chunk-wise causal, few-step | §4.2 | [P] |
| Epona | 2506.24113 | **~0.3 s per frame (10 steps); ~2 s (100 steps)** | 512×1024 | 1 (front) | **1×RTX 4090** | n/r | 10 / 100 | 2.5B (image DiT 1.2B) | AR diffusion; the planner runs in ~0.02–0.3 s | §4.1 Table 2 | [P] |
| Vista | 2405.17398 | n/r | 576×1024 at 10 Hz | 1 | n/r (≥32 GB suggested, see 04) | n/r | 50 DDIM | 2.5B (UNet 1.6B) | SVD-based | App. C.1, C.4 | [P] |
| GAIA-2 (Wayve) | 2503.20523 | **n/r** | 448×960 | up to 5 | n/r | n/r | 50 | 8.4B (+ tokenizer 85M enc / 200M dec) | latent compression 384×; CFG off by default | §2.1–2.2, §5 | [P] |
| GAIA-3 (Wayve, 2025-12) | press only | n/r | n/r | n/r | n/r | n/r | n/r | 15B | n/r | trade press | [S] |
| Waymo World Model (2026-02, on Genie 3) | Waymo blog | "efficient real-time" variant; **no numbers** | n/r | camera + lidar; count n/r | n/r | n/r | n/r | n/r | "more efficient variant", "dramatic reduction in compute" | blog | [P-vendor] |
| Cosmos-Predict2.5 auto/multiview | 2511.00062 | n/r | n/r | 7 | docs: **≥8 GPUs × ≥80 GB** for multiview | n/r | teacher n/r; 2B distilled to **4** (rCM) with about the same benchmark score | 2B | rCM (consistency + DMD) | §4.2.3 Tables 7–8; `docs/inference_auto_multiview.md` | [P] |
| Cosmos 3 Nano-Sim-Auto | flashdreams integration README | n/r ("seven RGB views can be very slow on one GPU") | n/r | 1–11 (presets 1/4/7) | 80 GB+ GPU | n/r | n/r | n/r | n/r | `integrations_v2/cosmos3_nano_sim_auto/README.md` | [P] |
| MagicDrive-V2 (offline reference) | 2411.13807 | **28.92 min for 241 frames** | 848×1600 | 6 | 8×H20 | n/r | n/r | n/r | sequence parallel | App. D Table III | [P] |
| comma "Learning to Drive from a World Model" | 2504.19077 | n/r | 128×256 at 5 Hz | 1 | n/r | n/r | 15 Euler | 250M / 500M / 1B DiT | KV cache, future anchoring | §4.3, §4.5 | [P] |
| OccWorld (occupancy, not video) | 2311.16038 | 18.0 FPS (OccWorld-O) | 200×200×16 occupancy | — | GPU n/r in the table | n/r | — (AR tokens) | n/r | VQ tokens | Table 1 | [P] |

## B. General interactive / streaming video models (scaling reference)

| System | Source | FPS / latency (as stated) | Resolution | GPU × count | Precision | Steps | Params | Tricks | Where | Tag |
|---|---|---|---|---|---|---|---|---|---|---|
| GameNGen (DOOM) | 2408.14837 | **20 FPS**; 10 ms per U-Net step + 10 ms decoder; 1-step distilled gives 50 FPS at some quality cost | 320×240 (padded to 320×256) | **1×TPU-v5** | n/r | **4 DDIM, not distilled** | SD-1.4 U-Net (count n/r) | noise augmentation, 64-frame context, narrow domain | §3.3.2, Table 1 | [P] |
| DIAMOND (CS:GO) | 2405.12399 | **10 Hz** | dynamics model 56×30, upsampled to 280×150 | **1×RTX 3090** | n/r | 3 (dynamics) + 10 (upsampler) | 381M (51M upsampler) | EDM, tiny resolution + upsampler | §6 | [P] |
| Oasis (Decart, 2024) | vendor blog | **20 FPS**; 47 ms per frame | 360p | H100 (count n/r; "multi-GPU" mentioned) | n/r | n/r | n/r (open release is "Oasis 500M") | custom inference stack | blog | [P-vendor] |
| Genie 3 (DeepMind) | blog | **24 FPS**, "real time" | 720p | **n/r** | n/r | n/r | n/r | n/r | blog | [P-vendor] |
| Genie 2 | blog | "distilled version … real-time with a reduction in quality"; no numbers | n/r | n/r | n/r | n/r | n/r | distillation | blog | [P-vendor] |
| MineWorld | 2504.08388 | 5.91 / 3.18 / 3.01 FPS (parallel decoding) vs 2.00 / 1.08 / 0.89 (plain AR) | 224×384 | GPU for timing n/r (trained on 32×A100) | n/r | — (AR tokens) | 300M / 700M / 1.2B | parallel token decoding | §4.2 Table 2 | [P] |
| CausVid | 2412.07772 | **9.4 FPS throughput, 1.3 s initial latency** | 640×352 | **1×H100** | n/r | **4** (DMD from 50) | n/r | causal DiT + KV cache | Table 3 | [P] |
| **Self-Forcing** | 2506.08009 | **17.0 FPS, 0.69 s latency** (chunk-wise); 8.9 FPS, 0.45 s (frame-wise) | 832×480 | **1×H100** | n/r | **4** ([1000,750,500,250]) | 1.3B (Wan2.1) | self-rollout + DMD, rolling KV (recomputing KV instead drops to 4.6 FPS) | Table 1, §4, App. | [P] |
| **MAGI-1** | 2505.13211 | **<1 s per 24-frame chunk** (= 24 fps playback), time-to-first-chunk 2.3 s; "**~9 PFLOPS per second of video**" | 480p (3:4) | **24×H100/H800** (3 nodes) | **FP8 W8A8** (SmoothQuant, +30%) | **16** | 24B (4.5B runs on 1×4090, speed n/r) | chunk-pipelined AR, Ulysses parallelism, VAE on separate hardware, CUDA graphs | §4.2.1–4.2.2, Table 6 | [P] |
| **Matrix-Game 2.0** | 2508.13009 | **25.15 FPS** | 352×640 | **1×H100** | n/r | **3** (cut from 4: 21.03 → 25.15 FPS) | 1.8B | Self-Forcing-style, KV cache, action modules in half the blocks only, Wan2.1 VAE | Table 3, §4.2 | [P] |
| Yan-Sim | 2508.08601 | **50–60 FPS** | **1080P** | **GPU type and count n/r** (diffusion and VAE "on separate GPUs") | **FP8** on all GEMMs (1.5–2× over FP16; 1.18× end-to-end) | 4 DDIM | SD-based U-Net (n/r) | VAE 2×32×32 compression, shift-window denoising, pruning, CUDA graph, compile (1.15×) | §5.1 | [P] |
| Yan-Gen | 2508.08601 | **12–17 FPS on 1×H20; 30 FPS on 4×H20** | n/r | H20 | n/r | few-step | Wan-based (n/r) | sequence parallelism | §5.2 | [P] |
| Hunyuan-GameCraft | 2506.17201 | **6.6 FPS**; <5 s per action | n/r (720p class [U]) | n/r | n/r | 8 (PCM) + CFG distillation | HunyuanVideo-based (n/r) | 10–20× from distillation | §4.3 | [P] |
| **WorldPlay / HY-World 1.5** | 2512.14614 | **24 FPS** (2.80 → 3.80 → 16.0 → 24.0 as optimisations stack) | **720p** | **8×H800** | Sage attention + float/matmul quantization | **4** | README: 8B (HunyuanVideo) and 5B (Wan) variants; which one is timed [U] | 16-frame chunks, mixed DiT/VAE parallelism, streaming VAE decode, Triton serving | §3.5, Table 4; HY-WorldPlay README | [P] |
| LingBot-World-Fast | 2601.20540 | **16 fps**, latency <1 s | 480p | "one GPU node" (type n/r) | n/r | few-step | 28B MoE (14B active) | causal adaptation + few-step distillation | §3.1.3, conclusion | [P] |
| LongLive | 2509.22622 | **20.7 FPS** | 832×480 | **1×H100** | INT8 option (2.7 → 1.4 GB) | n/r | 1.3B | short window + sink frames, KV re-cache on prompt switch | abstract, Table 1 | [P] |
| Rolling Forcing | 2509.25161 | **16 fps** | 832×480 | "single GPU" (type not found) | n/r | 5 | 1.3B | rolling denoising window | Fig. 1, §3 | [P] |
| MotionStream | 2511.01266 | **29.5 FPS / 0.39 s** (Wan2.1 1.3B, 480P, tiny VAE); 23.9 FPS / 0.49 s (Wan 2.2; 720P per abstract) | 480P / 720P | **1×H100** | bf16, FlashAttention-3 | n/r | 1.3B / Wan 2.2 | Self-Forcing distillation, attention sink, tiny VAE | abstract, §4, App. | [P] |
| StreamDiffusionV2 (video-to-video, not a world model) | 2511.07399 | 1.3B: **42.26 FPS at 480P**, 61.57 at 512²; 14B: **39.24 FPS at 480P**; time-to-first-frame <0.5 s; 4×RTX 4090: ~16 FPS at 480P | 832×480, 512×512 | **4×H100** (also 4×4090) | bf16, no TensorRT, no quantization | 1–4 | 1.3B / 14B | pipeline parallelism over steps and layers (adds throughput, not latency) | abstract, §5.2 | [P] |
| Krea Realtime 14B | HF `krea/krea-realtime-video` | **11 fps** | n/r on card | **1×B200** | FP8 recommended on H100 | 4 | 14B (Wan2.1) | Self-Forcing | model card | [P] |

## Latency vs throughput (they are different numbers)

- **Chunk latency is the control latency.** OmniDreams returns an 8-frame single-view chunk in 118 ms, or a 16-frame 4-view chunk in 151 ms. The driving action is held fixed for the whole chunk, and the chunk length is set by the VAE's temporal compression [P, §5.3, §6]. Oasis 3 claims <200 ms; Oasis 2024 claims 47 ms per frame; GameNGen 50 ms per frame [P].
- Self-Forcing argues that "real-time" needs both throughput above playback rate **and** low latency [P, §4]. Its chunk-wise model has 0.69 s latency, the frame-wise one 0.45 s. CausVid: 1.3 s. MAGI-1: 2.3 s to the first chunk, then <1 s per chunk. StreamDiffusionV2: <0.5 s to the first frame.
- **Multi-GPU helps throughput more than latency.** Pipeline parallelism (StreamDiffusionV2) raises FPS but not per-frame latency. Context parallelism over cameras (OmniDreams) cuts both, scaling near-linearly up to 4 GPUs for 4 cameras and with diminishing returns after that (1,289 → 330 → 209 → 151 ms) [P, Table 3].

## What makes real time possible (measured effects only)

1. **Few-step distillation, the biggest lever.** Measured: 40 steps → 1 step gave a 107.7× faster generator (ZYT-World); PCM 8 steps plus CFG distillation gave 10–20× (GameCraft); 4 → 3 steps took Matrix-Game 2.0 from 21.0 to 25.2 FPS. Cosmos-Predict2.5 2B keeps its benchmark score at 4 steps [all P]. OmniDreams runs at 2 steps and ZYT-World at 1. GameNGen is the exception: 4 undistilled DDIM steps suffice because its domain is narrow.
2. **Causal attention + KV cache + bounded window.** Every real-time model listed generates autoregressively over chunks. Self-Forcing measured that recomputing the cache instead of rolling it drops throughput to 4.6 FPS [P]. OmniDreams caps attention at 6–8 latent frames with attention sinks, so tensor shapes stay static and CUDA graphs can be used [P].
3. **A cheap pixel decoder.** ZYT's 19M TinyVAE decodes 59.8× faster than the 555M Wan decoder. MotionStream's tiny VAE took Wan2.1 from 16.7 to 29.5 FPS. OmniDreams' LightTAE costs 5–6 ms per chunk on one GPU [P]. Yan's VAE compresses 2×32×32 instead of 1×8×8 [P].
4. **Low precision.** FP8 GEMMs gave 1.5–2× per GEMM and 1.18× end-to-end (Yan). FP8 W8A8 gave +30% (MAGI-1). ZYT uses W8A8, LongLive INT8, and OmniDreams' released presets use FP8 attention/KV [P].
5. **Systems work.** torch.compile + CUDA graphs (Yan 1.15×; MAGI-1 cut 30.4% of first-chunk latency); KV-cache updates moved off the hot path (OmniDreams); the VAE on separate GPUs (Yan, MAGI-1); hoisting step-invariant RoPE/patchify out of the step loop (OmniDreams) [P].
6. **Smaller problems.** Low resolution (DIAMOND 56×30, GameNGen 320×240, comma 128×256 at 5 Hz, Matrix-Game 352×640), small models (0.4–2B), and **fewer cameras**: OmniDreams stops at 4 views for real time [P].

## [arith] Camera-frames per second, from stated numbers only

| System | Views × FPS | Camera-frames/s | Resolution | Hardware |
|---|---|---|---|---|
| Tesla claim (01) | 8 × 24 | **192** | n/r | n/r |
| OmniDreams-MV | 4 × 12 / 48 / 105 | 48 / **192** / 420 | 704×1280 | 1 / 4 / 16 × GB300 |
| OmniDreams-SV | 1 × 68 | 68 | 704×1280 | 1 × GB300 |
| Oasis 3 | 3 × 22 | 66 | 512×768 | B200, count n/r |
| ZYT-World | 7 × 4 | 28 | ~720p native | 2 GPUs, type n/r |
| FAR-Drive | 6 ÷ 1.15 s | ~5.2 | 576×1024 | 1 × H200 |
| MAGI-1 | 1 × 24 | 24 (at ~9 PFLOP per video-second, i.e. 0.375 PFLOP per frame) | 480p | 24 × H100/H800 |

Caveats: model sizes (2–24B), step counts (1–16), resolutions and quality differ, and GB300, H200 and H100 are not equal per chip.
These rows bound the order of magnitude. They are not a fit.

## Dead ends (as of 2026-11-24)

- **Tesla:** no architecture, resolution, step count or hardware (01). Same for **Genie 3** (24 fps, 720p; hardware and params n/r), **Genie 2** ("distilled … real-time", no numbers), the **Waymo World Model** ("efficient real-time" variant, no numbers), **GAIA-3** (15B, press only) and **GAIA-2** (8.4B, 50 steps, no speed).
- **World Labs RTFM:** "interactive framerates using just a single H100 GPU"; no FPS, resolution or parameter count.
- **Cosmos-Predict2.5 / Cosmos 3 Nano-Sim-Auto:** distilled to 4 steps, but no FPS is published. Multiview needs ≥8×80 GB; Sim-Auto needs 80 GB+ and warns that 7 views "can be very slow on one GPU".
- **OmniDreams gaps:** the paper states no precision. The **public checkpoint is single-view only** (`single_view/2b_res720p_30fps_i2v_hdmap_distilled.pt`), so the 4-view numbers cannot be reproduced from released weights. The RTX 5090 presets give resolution but no FPS.
- **GPU type missing:** ZYT-World (2 GPUs), Yan-Sim (1080P/60), LingBot-World-Fast ("one GPU node"), Rolling Forcing, MineWorld timing, Hunyuan-GameCraft.
- **Oasis:** `etched-ai/open-oasis` now returns **404** on GitHub. The weights `Etched/oasis-500m` are still on HF (MIT, gated auto). The blog does not state the full model's size.
- **No speed reported:** X-World (XPeng), comma's world-model paper, Vista, OccWorld's GPU. DriveDreamer-family papers were not re-checked here; 04 found none real-time.

## Open questions

- How does OmniDreams-MV scale from 4 to 7–8 views? Cross-view attention and token count grow with the number of cameras, and NVIDIA reports real time only "up to four cameras". No 7-view FPS exists for OmniDreams, Cosmos 3 Sim-Auto or Cosmos-Predict2.5.
- What does Tesla render per camera? AI5/AI4-class chips or datacenter GPUs? How many steps? "Adjusting test-time compute" fits step-count distillation, but that is speculation.
- How much perception-relevant fidelity survives 1–2 step generation? OmniDreams and ZYT both evaluate with detectors (LET-3D-AP, etc.); a quality-vs-steps curve for driving metrics was not extracted here.
- FLOPs per frame are published only by MAGI-1. Anything else would need profiling, for example on the 4090. Real 4090 anchors: Epona 0.3 s per frame (10 steps, 512×1024); StreamDiffusionV2 ~16 FPS at 480P on 4×4090; DIAMOND 10 Hz on a 3090; MAGI-1 4.5B fits one 4090 (speed n/r).
