#!/usr/bin/env bash
# Optional setup for Module 4's local GRPO training track. The default workshop
# environment deliberately does not install these packages or require a GPU.
set -euo pipefail

if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "Module 4 local GRPO training requires an NVIDIA GPU and driver."
    echo "Use the default hosted-API path on CPU instead."
    exit 1
fi

if ! nvidia-smi >/dev/null 2>&1; then
    echo "An NVIDIA GPU was detected but is not usable by this environment."
    exit 1
fi

# The CPU-first Workbench image does not contain a CUDA compiler. Install the
# toolkit only for this opt-in path so CUDA is never downloaded for CPU users.
if ! command -v nvcc >/dev/null 2>&1; then
    architecture=$(uname -m)
    case "$architecture" in
        x86_64)
            cuda_url="https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_570.86.10_linux.run"
            ;;
        aarch64|arm64)
            cuda_url="https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_570.86.10_linux_sbsa.run"
            ;;
        *)
            echo "Unsupported architecture for the CUDA training toolkit: $architecture"
            exit 1
            ;;
    esac

    installer=$(mktemp /tmp/cuda-toolkit.XXXXXX.run)
    curl -fL "$cuda_url" -o "$installer"
    sudo sh "$installer" --toolkit --silent --override
    rm -f "$installer"
fi

export CUDA_HOME=/usr/local/cuda-12.8
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export CC=gcc
export CXX=g++

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root/code/4-agent-customization"

uv sync --extra training

# PyPI publishes a CPU-only Torch wheel for aarch64. Replace it only in this
# GPU environment with the matching CUDA wheel.
if [ "$architecture" = "aarch64" ] || [ "$architecture" = "arm64" ]; then
    uv pip install --python .venv/bin/python --reinstall \
        --index-url https://download.pytorch.org/whl/cu128 \
        --extra-index-url https://pypi.org/simple \
        torch==2.10.0
fi

uv pip install --python .venv/bin/python --no-build-isolation \
    "causal-conv1d @ git+https://github.com/Dao-AILab/causal-conv1d.git@v1.5.2" \
    "mamba-ssm @ git+https://github.com/state-spaces/mamba.git@v2.2.5"

# mamba-ssm 2.2.5 imports a Transformers symbol removed by Transformers 5.x.
mamba_generation=$(uv run python -c "import importlib.util; spec = importlib.util.find_spec('mamba_ssm'); print(spec.submodule_search_locations[0] + '/utils/generation.py')" 2>/dev/null || true)
if [ -n "$mamba_generation" ] && [ -f "$mamba_generation" ]; then
    sed -i 's/from transformers.generation import GreedySearchDecoderOnlyOutput, SampleDecoderOnlyOutput, TextStreamer/from transformers.generation import GenerateDecoderOnlyOutput as GreedySearchDecoderOnlyOutput, GenerateDecoderOnlyOutput as SampleDecoderOnlyOutput, TextStreamer/' "$mamba_generation"
fi

# Some optional TRL integrations can leave stale package metadata behind. Only
# disable integrations that genuinely fail to import, matching the old GPU
# setup without bringing this workaround into the CPU environment.
trl_import_utils=$(uv run python -c "import importlib.util; print(importlib.util.find_spec('trl.import_utils').origin)" 2>/dev/null || true)
if [ -n "$trl_import_utils" ] && [ -f "$trl_import_utils" ]; then
    while IFS= read -r package; do
        if ! uv run python -c "import $package" >/dev/null 2>&1; then
            sed -i "s/_${package}_available = _is_package_available(\"${package}\")/_${package}_available = False  # disabled: import failed/" "$trl_import_utils"
        fi
    done < <(grep -oP '_\w+_available = _is_package_available\("\K[^"]+' "$trl_import_utils")
fi

echo "Module 4 GPU training dependencies are ready."
