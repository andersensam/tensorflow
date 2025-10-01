# syntax=docker/dockerfile:1

ARG TARGET=base
ARG BASE_IMAGE=ubuntu:22.04

FROM ${BASE_IMAGE} AS base
RUN mkdir -p /tmp/staging
WORKDIR /tmp/staging
# Install python3.10
RUN apt-get update && apt-get upgrade -y && apt-get install -y python3.10-venv python3.10-dev \
    && apt clean -y
# Extract LLVM
ADD LLVM-20.1.7-Linux-X64.tar.xz /tmp/staging/

# Setup the virtual environment for building
ENV VIRTUAL_ENV=/opt/venv
RUN python3.10 -m venv ${VIRTUAL_ENV}
ENV PATH="$VIRTUAL_ENV/bin:/tmp/staging/LLVM-20.1.7-Linux-X64/bin:$PATH"
ENV LLVM_HOME=/tmp/staging/LLVM-20.1.7-Linux-X64 CUDA_HOME=/usr/local/cuda-12.8

# Enable the CUDA repository and install the required libraries
RUN apt-get update && apt-get install -y curl && \
    curl -o cuda-keyring_1.1-1_all.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt-get update && apt-get install -y cuda-libraries-dev-12-8 libcudnn9-dev-cuda-12 libnccl-dev ibverbs-utils \
         patchelf wget curl llvm build-essential git \ 
         cuda-nvvm-12-8 cuda-nvml-dev-12-8 cuda-nvrtc-dev-12-8 cuda-nvcc-12-8 libnccl2 \
         cuda-cupti-12-8 cuda-cupti-dev-12-8 && \
    apt clean -y

# Prepare to build
ENV CC_OPT_FLAGS="-Wno-gnu-offsetof-extensions -Wno-error -Wno-c23-extensions -Wno-macro-redefined" CPATH="${CUDA_HOME}/include:/usr/local/cuda-12.8/targets/x86_64-linux/include"

# Install Bazelisk (Bazel wrapper), using a local bazel file since the download doesn't work half the time
COPY bazel /usr/local/bin/bazel
RUN chmod +x /usr/local/bin/bazel && /usr/local/bin/bazel version

# Clone TensorFlow
RUN mkdir -p /workspace/tensorflow
WORKDIR /workspace/tensorflow
RUN git init /workspace/tensorflow && git config --global --add safe.directory /workspace/tensorflow && \
    git remote add origin https://github.com/andersensam/tensorflow && \
    git -c protocol.version=2 fetch --no-tags --prune --no-recurse-submodules --depth=1 origin && \
    git checkout r2.19

# Copy the CUDA config into the image
COPY tf_r2.19.1.1_py3.10.brc .tf_configure.bazelrc
RUN bazel build //tensorflow/tools/pip_package:wheel --repo_env=WHEEL_NAME=tensorflow --config=cuda --config=cuda_wheel --config=avx_linux \
    --copt=-Wno-gnu-offsetof-extensions --copt=-Wno-error --copt=-Wno-c23-extensions --verbose_failures \
    --copt=-Wno-macro-redefined

# Export the CUDA wheels
RUN cp /workspace/tensorflow/bazel-bin/tensorflow/tools/pip_package/wheel_house/*.whl /workspace && \
    mkdir -p /mnt/export && cp -rf /workspace/*.whl /mnt/export

FROM scratch AS target
COPY --from=base /mnt/export /wheels