# Shell environment for neurad-studio (SplatAD) on a box set up with recon/setup_linux.sh. Use a fresh shell, not one
# that sourced $ROOT/env.sh (its PYTHONPATH points at drivestudio, whose top-level folders shadow other packages):
#   ROOT=/workspace/teslarender source recon/splatad_env.sh
# It reuses that setup's private CUDA 12.8 toolkit. The conda toolkit keeps its headers under targets/, and
# neurad-studio's scripts/setup-env.sh overwrites CPATH, so the headers go in CPLUS_INCLUDE_PATH / C_INCLUDE_PATH.
ROOT="${ROOT:-/workspace/teslarender}"
NEURAD_DIR="${NEURAD_DIR:-$ROOT/other/neurad-studio}"
export CUDA_HOME=$ROOT/cuda-12.8
export CPLUS_INCLUDE_PATH=$CUDA_HOME/targets/x86_64-linux/include C_INCLUDE_PATH=$CUDA_HOME/targets/x86_64-linux/include
export LIBRARY_PATH=$CUDA_HOME/targets/x86_64-linux/lib:$CUDA_HOME/targets/x86_64-linux/lib/stubs:$CUDA_HOME/lib
export UV_CACHE_DIR=$ROOT/cache/uv XDG_CACHE_HOME=$ROOT/cache HF_HOME=$ROOT/cache/hf PIP_CACHE_DIR=$ROOT/cache/pip
export TORCH_HOME=$ROOT/cache/torch MAX_JOBS=16
if [ -f "$NEURAD_DIR/.venv/activate-neurad" ]; then source "$NEURAD_DIR/.venv/activate-neurad"; fi
