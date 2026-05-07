# syntax=docker/dockerfile:1

ARG TARGET=runtime
ARG BASE_IMAGE=ubuntu:20.04
    
# Start with a clean Ubuntu 20.04 image and copy the Python 3.12 installation from the previous builder image
# and then add LLVM
FROM ${BASE_IMAGE} AS runtime
RUN mkdir -p /tmp/staging && mkdir -p /opt/python3.12
WORKDIR /tmp/staging
# Add the Python 3.12 install to this builder stage (build first with python-3.12-ubuntu20.04.Dockerfile)
COPY --from=python:3.12-ubuntu20.04 /python3.12 /opt/python3.12
# Copy the LLVM 20.1.7 install (build first with llvm-20.1.7-ubuntu20.04.Dockerfile)
COPY --from=llvm:20.1.7-ubuntu20.04 /llvm /opt/llvm
# Setup the virtual environment for building
ENV VIRTUAL_ENV=/opt/venv
RUN /opt/python3.12/bin/python3.12 -m venv ${VIRTUAL_ENV}
ENV PATH="$VIRTUAL_ENV/bin:/opt/llvm/bin:$PATH"
ENV LLVM_HOME=/opt/llvm CUDA_HOME=/usr/local/cuda-12.8

# Enable the CUDA repository and install the required libraries for building TensorFlow
RUN apt-get update && apt-get install -y curl && \
    curl -o cuda-keyring_1.1-1_all.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-libraries-dev-12-8 libcudnn9-dev-cuda-12 libnccl-dev ibverbs-utils \
         patchelf wget curl llvm build-essential git \ 
         cuda-nvvm-12-8 cuda-nvml-dev-12-8 cuda-nvrtc-dev-12-8 cuda-nvcc-12-8 libnccl2 \
         cuda-cupti-12-8 cuda-cupti-dev-12-8 libxml2-dev libssl-dev xxd nano && \
    apt clean -y

# Prepare to build and set any environmental flags that bazel might be difficult with
ENV CC_OPT_FLAGS="-Wno-gnu-offsetof-extensions -Wno-error -Wno-c23-extensions -Wno-macro-redefined" CPATH="${CUDA_HOME}/include:/usr/local/cuda-12.8/targets/x86_64-linux/include"

# Install Bazelisk (Bazel wrapper), using a local bazel file since the download doesn't work half the time
COPY bazel /usr/local/bin/bazel
RUN chmod +x /usr/local/bin/bazel && /usr/local/bin/bazel version

# Create a directory for TensorFlow work
RUN mkdir -p /workspace/tensorflow
WORKDIR /workspace/tensorflow