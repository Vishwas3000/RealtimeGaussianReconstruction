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

## Setup on a rented Linux GPU box (e.g. Vast.ai)

```
git clone https://github.com/Vishwas3000/RealtimeGaussianReconstruction.git /workspace/teslarender/repo
ROOT=/workspace/teslarender bash /workspace/teslarender/repo/recon/setup_linux.sh
source /workspace/teslarender/env.sh      # in every new shell; ~/drivestudio below is then $DRIVESTUDIO_DIR
```

- Same pinned stack as WSL. Everything goes in `$ROOT`: Python 3.10 from uv, a CUDA 12.8 toolkit from conda-forge,
  the venv, drivestudio and all caches. Nothing is installed system-wide, because other people's jobs may share the box.
- A box's own CUDA 13.x can't compile extensions for torch cu128 (major versions must match); `env.sh` puts the
  12.8 toolkit first. `TORCH_CUDA_ARCH_LIST` is read from `nvidia-smi`.
- On Vast, `/workspace` is deleted with the instance unless it is a mounted volume. Copy results off first.
- Data there: nuScenes-mini downloads without a login (licence CC BY-NC-SA 4.0):
  ```
  mkdir -p $ROOT/data/nuscenes/raw $DRIVESTUDIO_DIR/data && ln -sfn $ROOT/data/nuscenes $DRIVESTUDIO_DIR/data/nuscenes
  cd $ROOT/data/nuscenes && curl -fsSL -o v1.0-mini.tgz https://www.nuscenes.org/data/v1.0-mini.tgz \
    && tar -xzf v1.0-mini.tgz -C raw && rm v1.0-mini.tgz && cd $DRIVESTUDIO_DIR
  ```
  Then run the `preprocess.py` and `extract_sky_masks.py` lines from "Data" below, with `<repo>` = `$ROOT/repo`.

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

## SplatAD (neurad-studio), for comparison (D-016)

On the rented box after `setup_linux.sh`, in a fresh shell (not after `env.sh`):

```
export ROOT=/workspace/teslarender
git clone https://github.com/georghess/neurad-studio.git $ROOT/other/neurad-studio     # run at commit 0d14d8e
source $ROOT/repo/recon/splatad_env.sh
cd $ROOT/other/neurad-studio && bash scripts/setup-env.sh && source $ROOT/repo/recon/splatad_env.sh
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
ns-train splatad --output-dir $ROOT/work_dirs/splatad --experiment-name scene0061_front --timestamp run --vis tensorboard \
  --pipeline.datamanager.camera-res-scale-factor 0.5 \
  nuscenes-data --data $ROOT/data/nuscenes/raw --version v1.0-mini --sequence 0061 --cameras FRONT --train-split-fraction 0.9
R=$ROOT/work_dirs/splatad/scene0061_front/splatad/run
ns-eval --load-config $R/config.yml --data-root-path $ROOT/data/nuscenes/raw --output-path $R/eval.json
ns-render dataset --load-config $R/config.yml --data $ROOT/data/nuscenes/raw --pose-source test \
  --rendered-output-names rgb gt-rgb --output-path $R/renders/held_out
```

- `ns-eval` needs `--data-root-path`. It overwrites the saved dataset path with it even when unset, a neurad-studio bug
  (`nerfstudio/scripts/eval.py` line 70).
- `ns-render dataset --shift 2 0 0` moves the camera 2 m to its right, i.e. a lane change. `ns-render interpolate
  --shift` uses world axes instead.
- Scene-0061, front camera: held-out PSNR 30.2 against OmniRe's 23.3, but on different held-out frames. Numbers and
  caveats: [research/13](../research/13-models-beyond-omnire.md).

## View in a browser

```
python <repo>/recon/export_splat.py ~/work_dirs/<project>/<run_name>/checkpoint_final.pth scene.splat
```

Drag `scene.splat` into [SuperSplat](https://superspl.at/editor) or [antimatter15's viewer](https://antimatter15.com/splat/).
- The file holds the static street plus the cars where they were at frame 0, rotated to y-up.
- Left out, because the 32-byte `.splat` format has no room for them: people, the sky, and colour that changes with
  viewing angle.
- Scene-0061 front camera: 1.21 M splats, 38.7 MB. Rendering the decoded file matches the full-precision splats at
  64.7 dB PSNR.

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

## Measured on a rented RTX 5090 (32 GB, shared with other jobs)

Scene-0061 (`000`), **front camera only** (`dataset=nuscenes/1cams`, 800×450), the same OmniRe config, D-012's step M1:

| | 2,000-step smoke run | 30,000-step run, every 10th frame held out |
|---|---|---|
| Training time | 71 s (0.036 s/step) | 28 min 11 s (0.056 s/step) |
| Peak PyTorch memory | 4.33 GB allocated | 7.19 GB allocated |
| PSNR | train 26.6 dB | train 33.7 dB; all 191 frames 32.7 dB; **19 held-out frames 23.3 dB** |

The 10 dB gap between training and held-out frames is the baseline later monocular steps have to close (D-012).
