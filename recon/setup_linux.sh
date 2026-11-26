#!/usr/bin/env bash
# Set up drivestudio (OmniRe) on a rented Linux GPU box, e.g. Vast.ai, that other people's jobs may share. See recon/README.md.
# Everything goes into one folder ($ROOT): no apt, no system pip, no driver or /usr/local/cuda changes.
#   ROOT=/workspace/teslarender bash <repo>/recon/setup_linux.sh
# Afterwards, in every new shell:  source $ROOT/env.sh
# Needs: an NVIDIA driver for CUDA >= 12.8, uv, and conda/mamba (Vast's images ship /opt/miniforge3).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${ROOT:-/workspace/teslarender}"
CONDA="${CONDA:-/opt/miniforge3/bin/mamba}"
CAP="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1)" # 12.0 on RTX 50-series

mkdir -p "$ROOT/cache"
cat > "$ROOT/env.sh" <<EOF
export ROOT=$ROOT DRIVESTUDIO_DIR=$ROOT/drivestudio VENV=$ROOT/venv PYTHONPATH=$ROOT/drivestudio
# torch is cu128, so its extensions need a CUDA 12.8 nvcc, not the box's own CUDA_HOME.
export CUDA_HOME=$ROOT/cuda-12.8
export PATH=$ROOT/cuda-12.8/bin:\$PATH
export CPATH=$ROOT/cuda-12.8/targets/x86_64-linux/include
export LIBRARY_PATH=$ROOT/cuda-12.8/targets/x86_64-linux/lib:$ROOT/cuda-12.8/lib
export TORCH_CUDA_ARCH_LIST=$CAP
# Caches stay in \$ROOT too, so nothing lands in the shared home folder.
export XDG_CACHE_HOME=$ROOT/cache HF_HOME=$ROOT/cache/hf PIP_CACHE_DIR=$ROOT/cache/pip UV_CACHE_DIR=$ROOT/cache/uv
export CONDA_PKGS_DIRS=$ROOT/cache/conda UV_PYTHON_INSTALL_DIR=$ROOT/python UV_PYTHON_BIN_DIR=$ROOT/python/bin
export TORCH_EXTENSIONS_DIR=$ROOT/cache/torch_extensions
if [ -f $ROOT/venv/bin/activate ]; then source $ROOT/venv/bin/activate; fi
EOF
# shellcheck disable=SC1091
source "$ROOT/env.sh"

uv python install 3.10 # drivestudio pins numpy 1.23.1, which has no wheels for newer Pythons
[ -x "$CUDA_HOME/bin/nvcc" ] || "$CONDA" create -y -q -p "$CUDA_HOME" -c conda-forge cuda-toolkit cuda-version=12.8
"$CUDA_HOME/bin/nvcc" --version | tail -1

PYTHON="$(uv python find 3.10)" MAX_JOBS="${MAX_JOBS:-16}" bash "$REPO_DIR/recon/setup_wsl.sh" python
