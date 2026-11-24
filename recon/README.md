# Reconstruction: OmniRe (drivestudio) on an RTX 50-series GPU

Per-scene dynamic Gaussian-splat reconstruction of a nuScenes drive from its 6 cameras, using
[drivestudio](https://github.com/ziyc/drivestudio)'s OmniRe. LiDAR seeds the splats, and the tracked boxes let each
moving object get its own splats. The output is a scene that can be re-rendered from any camera.

It runs in **WSL2 Ubuntu 22.04**, because drivestudio's compiled dependencies (gsplat, pytorch3d, nvdiffrast) build
reliably only on Linux. drivestudio pins torch 2.0 + CUDA 11.7, which has no kernels for Blackwell (sm_120). Here it
runs on torch 2.7.1 + CUDA 12.8 with those dependencies rebuilt, and no drivestudio source changes. Why: D-010 in
[`docs/DECISIONS.md`](../docs/DECISIONS.md).

`<repo>` below is this repository's WSL path, e.g. `/mnt/c/Users/<you>/OneDrive/Documents/GitHub/RealtimeGaussianReconstruction`.

## Setup (once, from Windows)

```
wsl --install -d Ubuntu-22.04 --no-launch
wsl -d Ubuntu-22.04 -u root -- bash -c "useradd -m -s /bin/bash dev; printf '[boot]\nsystemd=true\n\n[user]\ndefault=dev\n' > /etc/wsl.conf"
wsl --terminate Ubuntu-22.04
wsl -d Ubuntu-22.04 -u root -- bash <repo>/recon/setup_wsl.sh system     # CUDA 12.8 toolkit, compilers
wsl -d Ubuntu-22.04 -- bash <repo>/recon/setup_wsl.sh python             # venv, torch, builds, GPU smoke test
```

The last step ends with `recon/smoke_test_gpu.py`; all four checks (torch, gsplat, pytorch3d, nvdiffrast) must say `[ok]`.

When a WSL command uses shell variables, run it as `wsl -d Ubuntu-22.04 -e bash -c '...'`. `wsl -- ...` goes through
a login shell that expands the variables before your command sees them.

## Data (inside WSL)

```
cd ~/drivestudio && source ~/venvs/drivestudio/bin/activate && export PYTHONPATH=$PWD
mkdir -p data/nuscenes && ln -sfn <repo>/Dataset/nuscenes data/nuscenes/raw
python datasets/preprocess.py --data_root data/nuscenes/raw --target_dir data/nuscenes/processed \
  --dataset nuscenes --split v1.0-mini --start_idx 0 --num_scenes 10 --interpolate_N 4 --workers 8 \
  --process_keys images lidar calib dynamic_masks objects
python <repo>/recon/extract_sky_masks.py --data_root data/nuscenes/processed_10Hz/mini
```

- Output: `processed_10Hz/mini/000 … 009`, at 10 Hz with 6 cameras each. Folder `000` is scene-0061.
- `extract_sky_masks.py` replaces drivestudio's sky-mask tool, which needs mmcv + torch 1.8 and cannot run on sm_120.
  The output format is the same.

## Train

```
python <repo>/recon/train_with_vram.py --config_file <repo>/recon/configs/omnire_nuscenes_nosmpl.yaml \
  --output_root ~/work_dirs --project omnire --run_name scene000 \
  data.scene_idx=0 data.pixel_source.load_smpl=False
```

- `train_with_vram.py` runs drivestudio's `tools/train.py` unchanged and prints peak GPU memory at exit.
- For a quick check, add
  `trainer.optim.num_iters=2000 render.render_full=False render.render_test=False render.render_novel=null`.
- The config is OmniRe for 6 nuScenes cameras without the SMPL body model, so pedestrians become deformable Gaussians.
  Real SMPL bodies need the SMPL model file (registration at smpl.is.tue.mpg.de) plus drivestudio's pre-computed
  human poses.
- Results go to `~/work_dirs/<project>/<run_name>/`: `images/` holds the step visualisations (render vs. real
  cameras, and each layer separately), plus checkpoints, metrics and videos.

## Measured on the RTX 5070 Ti (16 GB)

Scene-0061 (`000`), 6 cameras at 1/3 resolution (≈533×300), 2,000-step smoke run:

| | |
|---|---|
| Speed | 0.081 s/step (≈12.3 steps/s); 2,000 steps in 2 min 42 s, 4 min 37 s including loading |
| Peak PyTorch memory | 3.11 GB allocated, 9.61 GB reserved |
| Whole-GPU peak | 13.1 GB, including ≈3 GB used by other Windows programs |
| Splats at step 2,000 | background 1.35 M, vehicles 47 k, deformable 43 k |
| Train PSNR | ≈20 dB |

Full 30,000-step run, same scene and settings:

| | |
|---|---|
| Training time | 1 h 13 min (0.146 s/step average; steps get slower as splats are added, ≈0.21 s/step mid-run) |
| Peak PyTorch memory | 4.6 GB allocated (drivestudio's `max mem`), reached by step 15,000 and flat after |
| Whole-GPU use | 4–10.5 GB during training, including other Windows programs |
| Splats | background peaked at 2.08 M at step 15,000; 1.17 M after pruning |
| Train PSNR | 23.3 dB at 10k, 25.3 at 15k, 26.0 at 25k, 26.8 at 30k |

**Verdict:** OmniRe with all 6 nuScenes cameras at 1/3 resolution fits in 16 GB with large headroom.

**Host RAM is the tighter limit.** The end-of-run video render (`do_evaluation`) holds every rendered frame of every
camera in memory. On a 31 GB host, with WSL allowed up to ~15.5 GB, that coincided with Windows running critically low
on memory and the run being stopped before the videos were written. The checkpoints were already saved. Re-render the
videos from `checkpoint_final.pth` with other programs closed.
