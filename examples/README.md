# Compiling and Installing TensorFlow 2.19

This branch of TensorFlow includes modifications designed to enable the use of CUDA 12.8.1, this bringing TensorFlow support to the NVIDIA Blackwell platform.

We bypass the usual build process and instead modify `.tf_configure.bazelrc` directly inside of a container.

The environment where the TensorFlow wheels are used is based on Ubuntu 22.04 (or Ubuntu 24.04). To prevent any issues with `glibc` or other libraries, we use Ubuntu as the base image for Linux targets.

## Building for `linux_x86_64` or `linux_arm64` **with CUDA 12.8.1**

Ensure your container runtime of choice is installed and properly configured.

Building the Linux targets requires the following directory structure to be setup:

```
Work root
|
|-- Target Dockerfile
|-- Target .tf_configure.bazelrc
|-- `bazel` binary
|-- LLVM distribution
```

`bazel` can be downloaded using `bazelisk`, [see here](https://github.com/bazelbuild/bazelisk). Download `bazelisk` and rename it to `bazel`, placing it in the work root. I have experienced issues with downloading `bazelisk` inside the container and started sourcing from the work root to prevent download issues later on.

The LLVM version used for building with CUDA 12.8.1 support is LLVM 20.1.7. LLVM can be [downloaded here](https://github.com/llvm/llvm-project/releases)

An example, properly configured work root for `linux_x86_64` looks something like:

```
Work root
|
|-- r2.19.1.1-ubuntu22.04.Dockerfile
|-- tf_r2.19.1.1.brc
|-- bazel
|-- LLVM-20.1.7-Linux-X64.tar.xz
```

Since my target OS is Ubuntu 22.04 and Python 3.12 is not available by default, I build it first in a separate image and copy its contents to the TensorFlow builder image. Once Python 3.12 is built, it is installed to `/opt/python3.12` and a virtual environment is created in `/opt/venv`. Please modify the Python compilation to account for the number of CPUs on your build machine.

Examining `tf_r2.19.1.1.brc` we see the following line:
```
build:cuda --repo_env HERMETIC_CUDA_COMPUTE_CAPABILITIES="compute_90,compute_100,compute_101,compute_120,sm_90a,sm_100a,sm_101a,sm_120a"
```

For my use, I want those CUDA targets built with the proper PXT and blobs present in the final wheel. This **should** be adjusted to meet your needs.

Note that when changing CUDA targets, the following files **must be updated**:
1. `tensorflow/core/kernels/mlir_generated/build_defs.bzl`
2. `third_party/gpus/cuda/cuda_config.h.tpl`
3. `third_party/xla/tensorflow.bazelrc`
4. `third_party/xla/third_party/tsl/third_party/gpus/cuda/cuda_config.h.tpl`

Modify the Dockerfile to point to your own branch of TensorFlow (or modify locally) to ensure the changes are pulled properly.

With all the files in place, we are ready for compilation. In the work root:
```
podman build . -f r2.19.1.1-ubuntu22.04.Dockerfile -t tensorflow:r2.19.1.1-ubuntu22.04
```

The final instructions of the Dockerfile copy the wheels to blank image:
```
FROM scratch AS target
COPY --from=base /mnt/export /wheels
```

The above can be removed if desired, ensuring the build context is fully saved and wheels are accessible at `/mnt/export`.

Assuming the default config, with the image build complete, the image `tensorflow:r2.19.1.1-ubuntu22.04` has its wheels stored in `/wheels`.

### Note on `linux_arm64`

The build process is essentially the same. Minor changes are present in the Dockerfile and `.tf_configure.bazelrc` files, namely pointing to the correct repositories and ensuring the right LLVM is available.

A properly configured work root looks like:

```
Work root
|
|--r2.19.1.1-ubuntu22.04_arm64.Dockerfile
|-- tf_r2.19.1.1_arm64.brc
|-- bazel
|-- LLVM-20.1.7-Linux-ARM64.tar.xz
```

With all the files in place, we are ready for compilation. In the work root:
```
podman build . -f r2.19.1.1-ubuntu22.04_arm64.Dockerfile -t tensorflow:r2.19.1.1-ubuntu22.04
```

### Note on Python 3.10

Follow the above process, using `r2.19.1.1-ubuntu22.04-python3.10.Dockerfile` to build instead. All changes to the `.tf_configure.bazelrc` are already present in `tf_r2.19.1.1_py3.10.brc`.

## Building for `macos_arm64`

Unlike the Linux targets, the `macos_arm64` target does not use containers.

Ensure Xcode is installed and configured properly. LLVM must also be downloaded and extracted. Install the desired Python version and set up a virtual environment.

My setup might look something like:
```
python3.12 -m venv .venv
source .venv/bin/activate
```

Manually create `.tf_configure.bazelrc` based on the example template, ensuring the following lines are replaced;
```
build --action_env PYTHON_BIN_PATH="PATH TO PYTHON BINARY HERE"
build --action_env PYTHON_LIB_PATH="PATH TO VENV PACKAGES (venv/lib/python3.12/site-packages)"
build --python_path="PATH TO PYTHON BINARY AGAIN HERE"
```

Assuming this is done in my home directory (`/Users/sam`), it could look something like:
```
build --action_env PYTHON_BIN_PATH="/Users/sam/.venv/bin/python3"
build --action_env PYTHON_LIB_PATH="/Users/sam/.venv/lib/python3.12/site-packages"
build --python_path="/Users/sam/.venv/bin/python3"
```

This will of course need to be adjusted for your own installation.

With `bazel` set up, we prepare for compilation, setting the following environmental variables:
```
export PATH="/Users/sam/LLVM-20.1.7-macOS-ARM64/bin:$PATH"
export LLVM_HOME=/Users/sam/LLVM-20.1.7-macOS-ARM64/bin
export CC_OPT_FLAGS="-Wno-gnu-offsetof-extensions -Wno-error -Wno-c23-extensions -Wno-macro-redefined"
export HERMETIC_PYTHON_VERSION=3.12
```

Adjust the variables as needed to account for your path to LLVM and the Python version you're using.

With all the configuration complete, compile TensorFlow and build the wheel:
```
bazel build //tensorflow/tools/pip_package:wheel --repo_env=WHEEL_NAME=tensorflow --config=macos_arm64 \
    --copt=-Wno-gnu-offsetof-extensions --copt=-Wno-error --copt=-Wno-c23-extensions --verbose_failures \
    --copt=-Wno-macro-redefined
```

Wheels will be stored in: `bazel-bin/tensorflow/tools/pip_package/wheel_house`.

In my experience, to install the wheel with either `pip` or `uv`, its name will need to be changed.

Original name:
```
tensorflow-2.19.1.1-cp312-cp312-macosx_arm64.whl
```

New name:
```
tensorflow-2.19.1.1-cp312-cp312-macosx_15_0_arm64.whl
```