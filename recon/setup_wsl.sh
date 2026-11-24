#!/usr/bin/env bash
# Set up drivestudio (OmniRe) for an RTX 50-series GPU (sm_120) inside WSL2 Ubuntu 22.04. See recon/README.md.
#
# From Windows, in this order:
#   wsl -d Ubuntu-22.04 -u root -- bash <repo>/recon/setup_wsl.sh system    # CUDA 12.8 toolkit + build tools (root)
#   wsl -d Ubuntu-22.04 -- bash <repo>/recon/setup_wsl.sh python            # venv, torch, drivestudio, CUDA builds
# where <repo> is the WSL path of this repository, e.g. /mnt/c/Users/<you>/OneDrive/Documents/GitHub/RealtimeGaussianReconstruction
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVESTUDIO_DIR="$HOME/drivestudio"
DRIVESTUDIO_COMMIT=e59bda4fa681f829dbb1d65f0de582b0f633c450
VENV="$HOME/venvs/drivestudio"

export CUDA_HOME=/usr/local/cuda-12.8
export PATH="$CUDA_HOME/bin:$PATH"
export TORCH_CUDA_ARCH_LIST="12.0"
export MAX_JOBS="${MAX_JOBS:-6}"

system() {
  export DEBIAN_FRONTEND=noninteractive
  cd /tmp
  apt-get update -qq
  apt-get install -y -qq wget ca-certificates
  # NVIDIA's WSL-Ubuntu repo ships the toolkit without a Linux driver; WSL uses the Windows driver.
  wget -q https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
  dpkg -i cuda-keyring_1.1-1_all.deb
  apt-get update -qq
  apt-get install -y -qq cuda-toolkit-12-8 build-essential ninja-build git git-lfs \
    python3.10-venv python3.10-dev python3-pip libgl1 libglib2.0-0 libegl1 unzip
  "$CUDA_HOME/bin/nvcc" --version | tail -1
}

python_env() {
  [ -d "$DRIVESTUDIO_DIR" ] || git clone --recursive https://github.com/ziyc/drivestudio.git "$DRIVESTUDIO_DIR"
  git -C "$DRIVESTUDIO_DIR" checkout -q "$DRIVESTUDIO_COMMIT"
  git -C "$DRIVESTUDIO_DIR" submodule update --init --recursive -q

  [ -d "$VENV" ] || python3.10 -m venv "$VENV"
  # shellcheck disable=SC1091
  source "$VENV/bin/activate"
  pip install -q --upgrade pip setuptools wheel ninja
  pip install -q torch==2.7.1 torchvision==0.22.1 --index-url https://download.pytorch.org/whl/cu128
  # chumpy's setup.py imports pip, which pip's isolated build environment does not have.
  pip install -q --no-build-isolation chumpy
  pip install -q -r "$REPO_DIR/recon/requirements-sm120.txt"

  # Compiled against the torch above (no build isolation) for sm_120 only.
  pip install --no-build-isolation "git+https://github.com/nerfstudio-project/gsplat.git@v1.3.0"
  pip install --no-build-isolation "git+https://github.com/facebookresearch/pytorch3d.git@stable"
  pip install --no-build-isolation "git+https://github.com/NVlabs/nvdiffrast.git"
  pip install -q -e "$DRIVESTUDIO_DIR/third_party/smplx"

  python "$REPO_DIR/recon/smoke_test_gpu.py"
}

case "${1:-}" in
  system) system ;;
  python) python_env ;;
  *) echo "usage: $0 system|python" >&2; exit 2 ;;
esac
