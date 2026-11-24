# 12 — Camera datasets to test with

Checked 2026-11-24. `[measured]` = checked directly this session (bucket listing, HTTP HEAD, GitHub/HF API, page text).
`[from 02/03]` = carried over from those research files, which tag the source. Licences rot; re-check before
anything beyond personal learning.

## Today, no account needed

| Dataset | What you get | Size | Licence | How |
|---|---|---|---|---|
| **Argoverse 2 Sensor** | **7 surround "ring" cameras** + 2 front stereo cameras, LiDAR, 3D box labels, HD map, ego poses and calibration per drive | **one drive ≈ 1.14 GB** (3,036 files: cameras 987 MB, LiDAR 151 MB; a val log, measured). 1,000 drives total | data **CC BY-NC-SA 4.0** (non-commercial); code MIT `[measured: argoverse.org/about.html]` | `s5cmd --no-sign-request cp "s3://argoverse/datasets/av2/sensor/val/<log-id>/*" ./av2/` (the official guide uses `--no-sign-request`) `[measured]` |
| **3DGS Tanks & Temples + Deep Blending** | photo sets with COLMAP camera poses already computed, ready for splat training | **683 MB** `[measured]` | research/academic use; see the INRIA repo | https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/datasets/input/tandt_db.zip |
| **Mip-NeRF 360** | the standard splat benchmark scenes (garden, bicycle…) | **12.5 GB** `[measured]` | see Google Research's page | gsplat's `examples/datasets/download_dataset.py` fetches it |
| **comma2k19** | 1 front camera (HEVC video) + per-frame camera poses + CAN; highway driving; **no labels** | 1-minute sample (`Example_1`) **inside the GitHub repo**; full set ~100 GB torrent in ~10 GB chunks `[measured: README]` | MIT `[measured]` | `git clone https://github.com/commaai/comma2k19` |
| openpilot demo route | a real comma device drive replayed through openpilot's model and UI | small | MIT | `tools/replay/replay --demo` `[from 03]` |

## With a free sign-up

| Dataset | What you get | Size | Licence | Access |
|---|---|---|---|---|
| **nuScenes v1.0-mini** | **6 cameras**, LiDAR, radar, 3D boxes, maps, 10 scenes. **Every pretrained model in our plan uses it** (FlashOcc, SparseDrive, Sparse4D, LSS) | **4.2 GB** `[from 02, HTTP HEAD]` | CC BY-NC-SA 4.0 `[from 02/03]` | account at nuscenes.org |
| Occ3D-nuScenes mini | occupancy labels (200×200×16) **plus the camera images** for the mini split | ~440 MB `[from 02]` | MIT labels + nuScenes terms | must "register on the website and agree to the terms of use" of nuScenes/Waymo `[measured: README]` |
| **NVIDIA PhysicalAI-Autonomous-Vehicles** | 1,700 h, **306,151 clips × 20 s**, multi-camera on every clip, LiDAR on 298k, radar on 160k, ego motion, calibration, machine labels | **133 TB** total; download single clips | custom NVIDIA licence; the card says "ready for commercial/non-commercial AV use per the license agreement" `[measured: HF card]` | Hugging Face, gated with automatic click-through approval `[measured: gated=auto]` |
| **NVIDIA PhysicalAI-AV-NuRec** | **1,601 ready-made 3D reconstructions of real drives** from 7 cameras (USDZ + map + mesh), built for NVIDIA's 3DGUT Gaussian renderer | ~1.8 TB total (≈1.1 GB per scene on average `[derived]`) | custom NVIDIA licence; the card's agreement mentions a 12-month term | Hugging Face, gated auto `[measured]` |
| Waymo Open | 5 cameras + LiDAR; DGGT's weights and Street Gaussians' official configs use it | per-segment files (~20 s each) | non-commercial; trained models may not be used in vehicles `[from 02]` | Google sign-in `[measured: download page]` |
| PandaSet | 6 cameras + 2 LiDARs | not checked | not checked | sign-up form at pandaset.org `[measured: devkit README]` |

## Which to use for which roadmap stage (docs/LEARNING_ROADMAP.md)

- **Stage 1 (geometry):** Argoverse 2 (one drive, no account) or nuScenes-mini. Same exercises: project LiDAR into the surround cameras.
- **Stage 2 (splats):** the 683 MB Tanks & Temples / Deep Blending set, or your own phone video run through COLMAP.
- **Stage 3 (renderer):** nuScenes-mini + Occ3D mini (occupancy voxels), or Argoverse 2 (boxes + HD map, but no occupancy labels).
- **Stage 5 (perception):** **nuScenes-mini.** The pretrained weights expect nuScenes' 6-camera layout.
  MapTR / StreamMapNet also have Argoverse 2 checkpoints (research/03).
- **Stage 6 (driving reconstruction):** drivestudio has loaders for nuScenes, Waymo and Argoverse (research/04).
  NuRec's ready-made scenes let you look at results before training, but converting USDZ to a Mac viewer is **unverified**.
- **Stage 7 (feed-forward):** DGGT's released weights are Waymo-trained, with zero-shot transfer claimed. ReconDrive's are nuScenes-trained.

## Dead ends / not verified

- Argoverse 2's per-camera frame rate was not checked. One drive has about 2,900 camera images across 9 cameras.
- PandaSet's current licence and size were not checked. Its devkit was last pushed 2023-08.
- No unofficial re-uploads (e.g. nuScenes mirrors on Hugging Face) are listed. Their licence status is doubtful.
