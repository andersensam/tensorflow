# syntax=docker/dockerfile:1

ARG TARGET=base
ARG BASE_IMAGE=ubuntu:22.04

FROM ${BASE_IMAGE} AS python
# Build Python 3.12
RUN mkdir -p /tmp/staging
WORKDIR /tmp/staging
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
        libnss3-dev libssl-dev libreadline-dev libffi-dev pkg-config wget \
        libbz2-dev liblzma-dev libsqlite3-dev uuid-dev libgdbm-compat-dev \
        tk-dev libnsl-dev curl gnupg && \
    apt clean -y && \
    curl -o Python-3.12.11.tgz https://www.python.org/ftp/python/3.12.11/Python-3.12.11.tgz && \
    tar -xvf Python-3.12.11.tgz && \
    ./Python-3.12.11/configure --enable-optimizations --with-ensurepip=install --prefix=/opt/python3.12 && \
    make all -j22 && \
    make altinstall -j22 && \
    apt-get remove -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
        libnss3-dev libssl-dev libreadline-dev libffi-dev pkg-config wget \
        libbz2-dev liblzma-dev libsqlite3-dev uuid-dev libgdbm-compat-dev \
        tk-dev libnsl-dev curl gnupg && \
    apt-get autoremove -y && \
    apt clean -y && \
    rm -rf ./*

# Start with a clean Ubuntu 22.04 image and copy the Python 3.12 installation from the previous builder image
FROM ${BASE_IMAGE} AS base
RUN mkdir -p /tmp/staging && mkdir -p /opt/python3.12
WORKDIR /tmp/staging
# Add the Python 3.12 install to this builder stage
COPY --from=python /opt/python3.12 /opt/python3.12
# Extract LLVM
ADD LLVM-20.1.7-Linux-X64.tar.xz /tmp/staging/

# Setup the virtual environment for building
ENV VIRTUAL_ENV=/opt/venv
RUN /opt/python3.12/bin/python3.12 -m venv ${VIRTUAL_ENV}
ENV PATH="$VIRTUAL_ENV/bin:/tmp/staging/LLVM-20.1.7-Linux-X64/bin:$PATH"
ENV LLVM_HOME=/tmp/staging/LLVM-20.1.7-Linux-X64

# Enable the CUDA repository and install the required libraries for building TensorFlow
RUN apt-get update && apt-get install -y patchelf wget curl llvm build-essential git && \
    apt clean -y

# Prepare to build and set any environmental flags that bazel might be difficult with
ENV CC_OPT_FLAGS="-Wno-gnu-offsetof-extensions -Wno-error -Wno-c23-extensions -Wno-macro-redefined"

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
COPY tf_r2.19.1.1.brc .tf_configure.bazelrc
RUN RUN --mount=type=cache,target=/root/.cache/bazel,id=bazel-cache \
    bazel build //tensorflow/tools/pip_package:wheel --repo_env=WHEEL_NAME=tensorflow_cpu --config=tpu --config=avx_linux \
        --copt=-Wno-gnu-offsetof-extensions --copt=-Wno-error --copt=-Wno-c23-extensions --verbose_failures \
        --copt=-Wno-macro-redefined

# Export the wheels
RUN cp /workspace/tensorflow/bazel-bin/tensorflow/tools/pip_package/wheel_house/*.whl /workspace && \
    mkdir -p /mnt/export && cp -rf /workspace/*.whl /mnt/export

FROM scratch AS target
COPY --from=base /mnt/export /wheels