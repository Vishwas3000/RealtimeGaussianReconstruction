# 02 — Camera-only BEV + 3D occupancy (the "Occupancy Network" layer)

Research date: 2026-11-24. Light web research only: nothing was downloaded, installed or run.
Trust tags: **[P]** primary (read at source: arXiv API / arXiv abs page, `gh api` repo metadata, README, repo tree, licence file, HTTP HEAD);
**[S]** secondary (search snippet or third-party summary); **[U]** uncertain / could not confirm.
In the tables every cell is **[P]** unless marked (S) or (U). Stars and last-push dates rot; they are **as of 2026-11-24**.

## TL;DR

- **Use the BEVDet/FlashOcc lineage for occupancy.** FlashOcc M0 (R50, 256×704, 1 frame) reports 31.95 mIoU on Occ3D-nuScenes and 197.6 FPS (TensorRT FP16, RTX 3090) [P]. The weights are on Google Drive. After the lift step the network is only 2D convolutions plus a reshape, which makes it the easiest occupancy network to export.
- **Use Sparse4D v3 for 3D boxes with tracking IDs.** It reports 0.5637 NDS, 0.477 AMOTA and 19.8 FPS at R50 256×704 [P], and the weights are GitHub releases (MIT licence). Its one custom CUDA op is optional because a `grid_sample` fallback is built in [P]. StreamPETR is the fallback choice: it has no `.cu` files at all and NVIDIA ships a TensorRT port of it.
- **Nothing runs on the Mac yet. No one has ported an occupancy network to CoreML or Apple Silicon** (searched, none found). The only Apple-Silicon evidence for any model on this list is one community fork of SparseBEV (a detector) that exports ONNX for ONNX Runtime's CoreML Execution Provider. It reports no latency. Plan: train and export on the CUDA box, then run ONNX Runtime on the Mac (CoreML EP) and on Windows. Do **not** try to install mmcv/mmdet3d on the Mac.
- **Most custom ops have a pure-PyTorch replacement; the splatting kernels do not.** These ops are what block the Mac: `bev_pool_v2` (BEVDet, FlashOcc, ALOcc), `voxel_pooling` (BEVDepth), multi-scale deformable attention (BEVFormer, TPVFormer, SurroundOcc via mmcv), `msmv_sampling` (SparseBEV, SparseOcc, OPUS, SuperOcc) and Gaussian/superquadric splatting kernels (GaussianFormer, SuperOcc, GaussTR). The replacements are LSS cumsum, mmcv's `grid_sample` path, and SparseBEV's PyTorch sampler, which is about 15% slower [P]. The splatting kernels are the hard case: none has a replacement.
- **Data: start on nuScenes-mini plus Occ3D-nuScenes mini.** The two downloads are about 4.2 GB and about 440 MB, and the mini split has 404 labelled frames [P]. nuScenes, Waymo and Argoverse 2 are all **non-commercial**. Waymo's terms also bar using models trained on its data in vehicles or production [P via WebFetch].

## Main table

| Method | arXiv | Year / venue | Code | Licence | ★ / last push | Weights | Reported speed (source, GPU) | Custom CUDA ops | Why it matters here |
|---|---|---|---|---|---|---|---|---|---|
| **LSS** | 2008.05711 | 2020 | nv-tlabs/lift-splat-shoot | NVIDIA src licence, **non-commercial** | 1397 / 2024-10 | yes (BEV vehicle seg, gdrive) | not reported (abstract) | **none**: pure-PyTorch `QuickCumsum` | Canonical lift-splat. Small enough to rewrite yourself as a learning exercise. |
| BEVDet / BEVDet4D | 2112.11790 / 2203.17054 | 2021–22 | HuangJunJie2017/BEVDet | Apache-2.0 | 1818 / 2024-07 | yes, **Baidu pan only** | R50-CBGS 30.1 FPS PyTorch; TRT-FP16 4.94 ms at 256×704 (README, RTX 3090) | `bev_pool_v2` | Base of FlashOcc, ALOcc and Fast-BEV++. Hosts BEVDet-Occ (36.1–42.0 mIoU). |
| BEVDepth | 2206.10092 | 2022 | Megvii-BaseDetection/BEVDepth | MIT | 894 / **2023-01** | yes (GitHub) | not reported in README | `voxel_pooling` (train + inference) | Introduced depth supervision from LiDAR. The repo is stale. |
| BEVFormer | 2203.17270 | 2022 | fundamentalvision/BEVFormer | Apache-2.0 | 4655 / 2024-08 | yes | PyTorch tiny 15.9 / small 5.1 / base 2.4 FPS; TRT-FP16 tiny 81.2 FPS with custom plugins (DerryHub/BEVFormer_tensorrt, RTX 3090) | deformable attention via mmcv-full (mmcv also has a `grid_sample` PyTorch fallback) | Most cited, but too slow at useful sizes. Parent of TPVFormer and SurroundOcc. |
| PETR / PETRv2 | 2203.05625 / 2206.01256 | 2022 | megvii-research/PETR | Apache-2.0 (LICENSE file; API says NOASSERTION) | 1075 / 2023-10 | yes | not extracted | none in repo (U: mmdet3d deps) | Position-embedding design, a plain transformer that exports cleanly. NVIDIA DL4AGX has a PETR TRT port. |
| **StreamPETR** | 2303.11926 | 2023 | exiawsh/StreamPETR | Apache-2.0 (LICENSE file) | 851 / 2024-06 | yes (GitHub releases) | R50 900q: 53.7 NDS, 26.7 FPS (README: RTX 3090, FP32, bs 1, no flash-attn) | **0 `.cu` files**; flash-attn optional | Streaming: 6 images per step plus a query memory. NVIDIA DL4AGX `streampetr-trt` port for Drive Orin. |
| **Sparse4D v3** | 2311.11722 | 2023 | HorizonRobotics/Sparse4D | MIT | 715 / 2026-05 | yes (GitHub releases) | R50 256×704: 0.5637 NDS, 19.8 FPS (README; GPU not stated next to FPS, (U) RTX 3090). SparseEnd2End reproduces 15.8 FPS PyTorch FP32 on RTX 3090 | `deformable_aggregation`, **optional** (`use_deformable_func=False` falls back to `grid_sample`) | Detection **plus tracking** (AMOTA 0.477), so the renderer gets stable object IDs. TRT port: ThomasVonWu/SparseEnd2End (MIT). |
| SparseBEV | 2308.09244 | ICCV 2023 | MCG-NJU/SparseBEV | MIT | 478 / 2026-05 | yes (gdrive) | r50: 55.6 NDS val, 15.8 FPS; 400q-36ep: 55.8 NDS, 23.5 FPS (RTX 3090 + 5800X, no fp16) | `msmv_sampling`, with a native PyTorch version (about 15% slower) | **The only model with an Apple-Silicon path found:** HF `chinmaygarde/SparseBev` (2026-03) exports opset-18 ONNX for the ORT CoreML EP. Its input is 48 images (6 cams × 8 frames) per call. Latency not reported. |
| Fast-BEV | 2301.12511 | 2023 | Sense-GVT/Fast-BEV | (U) `License` file present, not parsed | 827 / 2023-09 | yes (gdrive) | not extracted | 17 `.cu` (mmdet3d ops) | LUT-based view transform. CUDA-FastBEV TRT port (MIT). |
| **Fast-BEV++** | 2512.08237 | IROS 2026 | ymlab/advanced-fastbev | Apache-2.0 | 64 / 2025-12 | yes (gdrive) **plus an exported ONNX** | 134 FPS, R50-CBGS, 0.489 NDS, **Tesla T4 INT8** (paper text) | Inference: **zero custom plugins** (Index-Gather-Reshape). The repo still ships `bev_pool_v2` for training | Detection only. Its view transform is the design to copy for CoreML. |
| Occ3D (benchmark) | 2304.14365 | 2023 | Tsinghua-MARS-Lab/Occ3D | MIT (code + labels) plus nuScenes/Waymo terms | 588 / 2024-07 | CTF-Occ baselines | — | — | The occupancy labels everyone reports on (see the datasets table). |
| OpenOccupancy | 2303.03991 | 2023 | JeffWang987/OpenOccupancy | Apache-2.0 | 750 / 2024-12 | not checked | — | not checked | Denser occupancy benchmark; OPUS-V2 reports on it. |
| SurroundOcc | 2303.09551 | ICCV 2023 | weiyithu/SurroundOcc | Apache-2.0 | 1094 / 2025-06 | yes, **Baidu pan only** | not reported in README | mmcv deformable attention plus `chamfer_dist` | Its dense labels ("SurroundOcc-nuScenes") are used by GaussianFormer, SuperOcc and VGGT-Occ. |
| TPVFormer | 2302.07817 | CVPR 2023 | wzzheng/TPVFormer | Apache-2.0 | 1364 / 2024-09 | yes (Tsinghua cloud) | not reported | mmcv deformable attention | Tri-plane representation. Its README compares itself with Tesla's occupancy network (Tesla: 8 cams, dense-reconstruction supervision). |
| **FlashOcc** | 2311.12058 | 2023 | Yzichen/FlashOCC | Apache-2.0 | 584 / 2026-05 | yes (gdrive) | M0 R50 256×704: 31.95 mIoU, **197.6 FPS TRT-FP16 RTX 3090** (TRT mIoU 30.78; INT8 397 FPS) | `bev_pool_v2`. Its ONNX export emits a `TRTBEVPoolv2` custom op | Channel-to-height: BEV features are reshaped into a 200×200×16 grid using only 2D convolutions. Selected as the occupancy reference algorithm for Horizon J6E/M (README). |
| Panoptic-FlashOcc | 2406.10527 | 2024 | same repo | Apache-2.0 | — | yes (gdrive) | Depth-tiny-Pano: RayIoU 34.81, RayPQ 12.9, 39.8 FPS (**A100, PyTorch fp32**) | `bev_pool_v2` | Instance IDs on voxels. The closest thing found to "occupancy + objects in one net with weights", but it has no box heading or velocity. |
| **SparseOcc** (Liu et al.) | 2312.17118 | ECCV 2024 | MCG-NJU/SparseOcc | Apache-2.0 | 444 / 2024-08 | yes (GitHub releases) | r50 8f: RayIoU 36.8 (24 ep), 17.3 FPS (A100 fp32, including data loading) | `msmv_sampling`: the wrapper imports the CUDA extension unconditionally, so it needs a patch on Mac. `dvr` is only used for RayIoU evaluation | Fully sparse and panoptic. Introduced **RayIoU** because training with the camera mask games mIoU. Supports OpenOcc v2. |
| OPUS / OPUS-V2 | 2409.09350 / 2608.29187 | 2024 / 2026 | jbwang1997/OPUS | MIT | 188 / 2026-05 | yes | V2-T: 36.5 mIoU, 42.0 RayIoU, 25.8 FPS. GPU **not stated** in README; the OPUS v1 paper measures on A100 | `msmv_sampling`, `dvr` | Predicts occupancy as a sparse point set, which suits point-sprite rendering. |
| **SuperOcc** | 2601.15644 | 2026 | Yzichen/SuperOcc | Apache-2.0 | 47 / 2026-07 | yes (HF `yzzzzc/SuperOcc`) | T: 36.1 mIoU, 42.5 RayIoU, **30.3 FPS (RTX 4090, PyTorch FP32, bs 1)** | **11 `.cu`** (superquadric splat, `msmv_sampling`) | Best Occ3D speed/accuracy found that ships weights, but it is the worst for porting. |
| ALOcc | 2411.07725 | 2024 | cdb342/ALOcc | Apache-2.0 | 59 / 2025-12 | yes (HF `Dobbin/alocc`) | 2D-mini: 33.4 mIoU, 39.3 RayIoU, 30.5 FPS. Flow-2D: 7.0 FPS. GPU **not stated** in README | `bev_pool_v2` | **Occupancy flow with released weights**, the analogue of Tesla's occupancy flow. |
| GaussianFormer / -2 | 2405.17429 / 2412.04384 | ECCV 24 / CVPR 25 | huang-yh/GaussianFormer | (U) LICENSE file present, not parsed | 694 / 2025-03 | yes | not reported in README | **13 `.cu`** | Gaussians are directly splattable. mIoU 19.1–20.3 on SurroundOcc labels, a different benchmark. |
| GaussianWorld | 2412.10373 | 2024 | zuosc19/GaussianWorld | **none** | 184 / 2025-12 | yes | not reported | (U) inherits the GaussianFormer ops | Streaming Gaussian world model: 22.13 mIoU vs 19.85 single-frame. |
| RenderOcc | 2309.09502 | 2023 | pmj110119/RenderOcc | **none** | 412 / 2025-01 | one model (Swin-B) | not reported | BEVStereo pooling (U) | Trained from 2D labels only. 24.46 mIoU. |
| SelfOcc | 2311.12754 | CVPR 2024 | huang-yh/SelfOcc | Apache-2.0 | 388 / 2024-09 | yes | not reported | not checked | Self-supervised occupancy from video. |
| GaussianOcc | 2408.11447 | ICCV 2025 | GANWANSHUI/GaussianOcc | Apache-2.0 | 389 / 2026-02 | yes (gdrive/Baidu) | not extracted | tested on PyTorch 1.9.1 / CUDA 11.3 | Fully self-supervised, uses Gaussian splatting. |
| GaussTR | 2412.13193 | CVPR 2025 | hustvl/GaussTR | MIT | 220 / 2026-01 | yes | not reported. IoU 45.19 / mIoU 11.70 (FeatUp) | gsplat (CUDA) | Self-supervised and aligned with foundation models; open-vocabulary flavour. |
| GaussianFlowOcc | 2502.17288 | ICCV 2025 | boschresearch/GaussianFlowOcc | **AGPL-3.0** | 67 / 2025-10 | **none listed** | — | gsplat 1.2.0, CUDA 11.3 | Weak supervision plus temporal flow, but there are no weights and the licence is AGPL. |
| Let Occ Flow | 2407.07587 | CoRL 2024 | eliliu2233/occ-flow | **none** | 142 / 2026-09 | not checked | — | not checked | Self-supervised occupancy flow. |

## Also checked (short)

- ProtoOcc 2412.08774 (AAAI 2025 (S)), SPA-junghokim/ProtoOcc: no licence; weights on gdrive and HF. 1-frame 39.56 mIoU at 12.83 FPS [P, README]; RTX 3090 per search snippet [S].
- GSD-Occ 2407.13155, harrylin-hyl/GSD-OCC: no licence; 25★; weights on gdrive. 39.4 mIoU at 20.0 FPS on **A100** [P, paper].
- QuadricFormer 2506.10977 (NeurIPS 2025 (S)), zuosc19/QuadricFormer: no licence. Weights not checked.
- SPOT-Occ 2602.04240, chensuzeyu/SpotOcc: Apache-2.0, 18★, weights released. Reports SSC mIoU 13.7 on nuScenes, a different metric from Occ3D.
- GaussRender 2502.05040 (ICCV 2025 (S)), valeoai/GaussRender: a training-time plug-in that improves other models. Not a runtime model.
- Cam4DOcc 2311.17663 (MIT, forecasting benchmark); OccWorld 2311.16038 (Apache-2.0, occupancy world model); UniOcc 2503.24381 (benchmark with per-voxel flow); OccNet / OpenOcc 2306.02851 (OpenDriveLab/OccNet, Apache-2.0, 710★). These are useful later for prediction and forecasting, not for a first renderer.
- FB-OCC 2307.01492, NVlabs/FB-BEV: **NVIDIA Source Code License-NC** [P]. COTR 2312.01919: Apache-2.0, last push 2024-04.
- Tesla's own occupancy network has **no paper, code or weights**. It is known only from AI Day / CVPR'22 talk coverage: 8 cameras, per-voxel occupancy plus flow, class-agnostic [S, press summaries].

## Datasets

| Dataset | What | Size | Licence | Laptop subset |
|---|---|---|---|---|
| nuScenes v1.0 | 1000 scenes × 20 s; 6 cameras, 5 radars, 1 lidar, 360° [P, arXiv 1903.11027] | ~400 GB full; ~60 GB keyframes only [S] | **CC BY-NC-SA 4.0**, non-commercial. Commercial licence from Motional [S] | `v1.0-mini.tgz` = 4,167,696,325 bytes (~4.2 GB) [P, HTTP HEAD]; 10 scenes [U: from memory, consistent with 404 Occ3D-mini frames] |
| Occ3D-nuScenes | 200×200×16 voxels at 0.4 m; x/y ±40 m, z −1 to 5.4 m; 18 classes (17 + free); camera and LiDAR visibility masks; scenes 600/150/250 train/val/test [P] | frames: mini 404, train 28,130, val 6,019, test 6,008. Downloads: mini ≈ 440 MB, trainval ≈ 32 GB, test ≈ 6 GB (includes images) [P, CVPR2023 challenge README] | MIT for labels, plus the nuScenes terms [P] | **mini (404 frames, ~440 MB)**: the right first target |
| Occ3D-Waymo | 5 cameras; 0.1 m or 0.4 m voxels; up to ±80 m [P, Occ3D README] | not verified | Waymo terms: non-commercial only. Trained models and weights may **not** be used to operate vehicles or in production [P via WebFetch of waymo.com/open/terms] | none found |
| Waymo Open (perception) | — | **not verified** | as above | — |
| Argoverse 2 Sensor | 1000 scenarios of about 15 s; about 1 GB per log; about 1 TB extracted [S] | ~1 TB [S] | **CC BY-NC-SA 4.0**, non-commercial; code and APIs MIT [S] | none found; no Occ3D-style AV2 occupancy labels were checked |
| OpenOcc v2 (OccNet) | nuScenes-based occupancy **plus flow** labels [S] | not verified | nuScenes terms (U) | SparseOcc has a config for it [P] |

## Notes on the most relevant models

1. **FlashOcc / Panoptic-FlashOcc.** After LSS-style lifting (`bev_pool_v2`) it has a flat BEV map, and the occupancy head is 2D convolutions followed by a reshape of channels into height. Swap `bev_pool_v2` for LSS's cumsum trick or a `scatter_add` and the whole graph is standard ONNX ops. The README's TensorRT path needs mmdeploy plus a custom `TRTBEVPoolv2` plugin [P], so it is Linux/NVIDIA only. The C++ TensorRT port its README links (`drilistbox/TRT_FlashOcc`) returns **404** [P]. Caveat: the 31.95 mIoU model was trained with the camera mask. SparseOcc's FAQ notes that such models over-fill space behind surfaces, so expect thick occupancy in the renderer.
2. **Sparse4D v3.** It keeps an instance bank across frames, so you feed 6 images per frame and get boxes with track IDs back, which is exactly what an FSD-style display needs to avoid flicker. Setting `use_deformable_func=False` routes through `F.grid_sample` [P, `blocks.py`]. Pinned stack: torch 1.13 + cu116 and mmcv-full 1.7.1 [P].
3. **StreamPETR.** No custom CUDA in the repo, a streaming query memory, and an official NVIDIA TensorRT ONNX-conversion guide (DL4AGX) [P]. It is the safest detector to export if Sparse4D's export fights you. It gives no tracking IDs. Pinned to PyTorch 1.9 [P].
4. **SparseBEV, via the HF CoreML fork.** The quickest proof that a nuScenes 6-camera network runs on the Mac at all: an opset-18 ONNX file (4.6 MB graph plus 181 MB weights) already exists [P, HF API]. The fork made three changes: 5D `grid_sample` became 4D, 6-D indexing became `gather`, and masked assignment became `torch.where` [P]. Those same changes apply to SparseOcc, OPUS and SuperOcc, which share `msmv_sampling`. It costs 8 frames × 6 cameras of backbone per call, there is 0 download history, and its accuracy after export is unverified.
5. **SparseOcc → OPUS-V2 → SuperOcc.** This is the upgrade path once the basic pipeline works: sparse queries, RayIoU 36.8 → 42.0 → 42.5 at similar or higher FPS. Each adds custom kernels; SuperOcc's superquadric splatting has no PyTorch fallback (U: not checked in code).
6. **ALOcc-Flow.** The only camera-only **occupancy flow** model found with downloadable weights (HF) [P]. Use it later for motion trails or "occupancy flow" colouring.

## Recommended starting model

**Decision:** use two networks, both on R50 at 256×704 and following nuScenes conventions. **FlashOcc M0** produces occupancy (Occ3D 200×200×16) and **Sparse4D v3** produces 3D boxes with track IDs. The CUDA box trains them and exports ONNX with pure-PyTorch replacements for the custom ops. Mac and Windows run them through ONNX Runtime: CoreML EP on macOS; DirectML or CUDA EP on Windows (U: EP coverage not tested).
**Why:**
- Both have downloadable weights (gdrive and GitHub releases) and both report real-time speeds on a 3090-class GPU.
- Each has exactly one custom op, and each op has a known CUDA-free replacement.
- FlashOcc's post-lift graph is only 2D convolutions, the friendliest shape for CoreML.
- Sparse4D adds tracking, and its MIT licence and May 2026 push make it the best-maintained of the options.
- Running two networks costs two backbones. Sharing the backbone (the UltimateDO idea) is a training project for later.

**Alternatives rejected:**
- *Panoptic-FlashOcc alone.* It has instance IDs but no box heading or velocity, and it runs at only 39.8 FPS on an A100 in fp32.
- *BEVFormer / TPVFormer / SurroundOcc.* Deformable attention and 2.4–15.9 FPS in PyTorch on a 3090.
- *SparseOcc / OPUS / SuperOcc as the first model.* They are more accurate, but they rely on more custom kernels (SuperOcc has 11 `.cu` files) and SparseOcc consumes 8 frames. Keep them as stage 2.
- *SparseBEV for boxes.* Its CoreML fork already exists, but it re-processes 48 images per call. Use it only as a day-1 smoke test of ORT CoreML on the Mac.
- *BEVDet detector.* Its weights are Baidu-only.
- *GaussianFormer family and self-supervised models (SelfOcc, GaussianOcc, GaussTR).* Many CUDA kernels, much lower mIoU, no FPS reported.
- *LSS / FB-OCC.* NVIDIA non-commercial licences. That is fine for learning, but it is a reason to flag them.

**Practical warning [U, not tested]:** the pinned training stacks predate CUDA 11.8, which is the release that added RTX 4090 (sm_89) support [U: from memory, not checked this session]: FlashOcc uses torch 1.10 + cu111 with mmcv-full 1.5.3, Sparse4D uses torch 1.13 + cu116, StreamPETR uses torch 1.9. Budget time to rebuild them on torch 2.0 + cu118, which is the stack SparseBEV and SparseOcc already document [P], or use a container.

## Apple Silicon / Windows facts gathered

- mmcv `main` ships `multi_scale_deformable_attn_pytorch`, which is built on `F.grid_sample` [P, source]. Deformable attention can therefore run without CUDA, only slower.
- PyTorch MPS `grid_sampler_3d` (5D `grid_sample`) landed through PR #160541 ("Merged" label, 2025-08-15) [P]. Mapping that to PyTorch ≥ 2.9 is [U: inferred from the merge date]. Older versions need `PYTORCH_ENABLE_MPS_FALLBACK=1`, which runs the op on the CPU [S].
- ORT CoreML EP: pass `MLComputeUnits` explicitly, otherwise ORT drops the CoreML EP at the first unsupported partition [P, the fork's README; not tested here].
- No CoreML, MLX or Core ML Tools conversion of any occupancy network was found (two searches). This is a **real gap, not an oversight**.

## Dead ends

- **DA-Occ** (2507.23599): withdrawn on arXiv ("preparing a significantly revised version") [P].
- **UltimateDO** (2409.11160, FlashOcc + detection in one net, +1.1 ms): paper only. There are no configs for it in the FlashOCC tree [P].
- **drilistbox/TRT_FlashOcc**: the TensorRT C++ port linked from the FlashOcc README returns **404** [P].
- **"SparseOcc" name clash**: Tang et al. 2404.09502 is an unrelated paper; MCG-NJU's SparseOcc is 2312.17118 [P].
- **Wrong arXiv ID caught**: 2408.14628 is a cosmology paper. GaussianOcc is **2408.11447** [P].
- **VGGT-Occ** (2605.16911): "code will be released", none yet [P, abstract]. **SuperQuadricOcc** (2511.17361): code also only promised [S].
- **GaussianFlowOcc**: no pretrained weights in the README and an AGPL-3.0 licence [P].
- **Baidu-only weights**: BEVDet detectors and SurroundOcc [P]. They are hard to fetch from outside China.
- **BEVDepth**: last push 2023-01, stale [P]. **DAOcc** (2409.19972) appears in "occupancy" lists but needs LiDAR [P, title], so it is not camera-only.
- **"Live on Apple Silicon MPS" page** (akilalours.github.io/opendrivefm): the page never mentions MPS or a Mac chip [P via WebFetch].
- **All three big datasets are non-commercial.** There is no commercially clean path without a licence.

## Open questions

- **Real Mac latency for any of these is unknown.** No one reports it. Measure one model at a time: start with the SparseBEV ONNX smoke test, then FlashOcc M0.
- Which ops ORT CoreML EP actually places on the GPU/ANE (GridSample, ScatterND, Gather) and how much falls back to the CPU. Untested.
- Does `bev_pool_v2` → `scatter_add` (or Fast-BEV++ Index-Gather-Reshape) reproduce FlashOcc's 31.95 mIoU exactly? The code makes this plausible, but it is unverified.
- GPU behind Sparse4D v3's 19.8 FPS, OPUS-V2's 25.8 FPS and ALOcc's 30.5 FPS: not stated in their READMEs.
- Fast-BEV++: the abstract claims 0.488 NDS, but the body attributes 134 FPS to an R50-CBGS run at 0.489 NDS. It is unclear whether these are the same config.
- Waymo dataset size, AV2 camera count, and whether any AV2 occupancy labels exist: not verified.
- Licence text of GaussianFormer and Fast-BEV: the files exist but were not parsed.
