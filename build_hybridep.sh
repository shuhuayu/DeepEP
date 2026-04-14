#!/bin/bash
# create a conda env, activate it, install pytorch, and run 'bash build_hybridep.sh'
# build_hybridep.sh - Build script for DeepEP with conda CUDA packages
# we need to install some cuda binaries from nvidia

set -e  # Exit on error

# Ensure conda environment is activated
if [ -z "$CONDA_PREFIX" ]; then
    echo "Error: No conda environment activated."
    exit 1
fi

PYTHON_VERSION="python$(python -c 'import sys;print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
NVIDIA_PKG_PATH="$CONDA_PREFIX/lib/$PYTHON_VERSION/site-packages/nvidia"

echo "Using conda prefix: $CONDA_PREFIX"
echo "Python version: $PYTHON_VERSION"
echo "Nvidia packages path: $NVIDIA_PKG_PATH"

# Install required packages
pip install ninja
conda install -c nvidia cuda-toolkit=12.8
conda install -c nvidia cuda-nvtx
pip install nvidia-cuda-cccl-cu12 \
            nvidia-cuda-runtime-cu12 \
            nvidia-cuda-nvcc-cu12 \
            nvidia-cuda-cupti-cu12 \
            nvidia-cuda-nvrtc-cu12 \
            nvidia-cublas-cu12 \
            nvidia-cusparse-cu12 \
            nvidia-cusolver-cu12 \
            nvidia-cufft-cu12 \
            nvidia-curand-cu12 \
            nvidia-cudnn-cu12 \
            nvidia-nccl-cu12 \
            nvidia-nvshmem-cu12 \
            nvidia-nvjitlink-cu12 \
            nvidia-nvtx-cu12

# Create necessary symlinks
echo "Creating library symlinks..."

CUDART_SO="$NVIDIA_PKG_PATH/cuda_runtime/lib/libcudart.so"
CUDART_SO_12="$NVIDIA_PKG_PATH/cuda_runtime/lib/libcudart.so.12"
if [ -f "$CUDART_SO_12" ] && [ ! -e "$CUDART_SO" ]; then
    ln -sf "$CUDART_SO_12" "$CUDART_SO"
    echo "  Created libcudart.so symlink"
fi

NVSHMEM_SO="$NVIDIA_PKG_PATH/nvshmem/lib/libnvshmem_host.so"
NVSHMEM_SO_3="$NVIDIA_PKG_PATH/nvshmem/lib/libnvshmem_host.so.3"
if [ -f "$NVSHMEM_SO_3" ] && [ ! -e "$NVSHMEM_SO" ]; then
    ln -sf "$NVSHMEM_SO_3" "$NVSHMEM_SO"
    echo "  Created libnvshmem_host.so symlink"
fi

# Set environment variables

# copy rdma core headers
# Determine architecture
DEVGPU_ARCH=$(uname -m)
export RDMA_CORE_HOME=$HOME/rdma-core
export CUDA_HOME=$CONDA_PREFIX
export PATH=/usr/local/cuda/bin:$PATH
export NVSHMEM_DIR="$NVIDIA_PKG_PATH/nvshmem"
NVTX_INCLUDE="$NVIDIA_PKG_PATH/nvtx/include"
export CPATH=$HOME/rdma-core/include:$CONDA_PREFIX/targets/sbsa-linux/include:$NVTX_INCLUDE:/usr/include:$CPATH # important to include headers

echo "Building DeepEP..."
echo "  CUDA_HOME: $CUDA_HOME"
echo "  NVSHMEM_DIR: $NVSHMEM_DIR"


# use lower level system gcc
unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
unset CMAKE_PREFIX_PATH
unset CONDA_BUILD_SYSROOT
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export CUDAHOSTCXX=/usr/bin/g++
export TORCH_CUDA_ARCH_LIST="10.0"

python setup.py install

echo "Build complete!"
