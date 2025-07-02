build --action_env PYTHON_BIN_PATH="/opt/python3.12/bin/python3.12"
build --action_env PYTHON_LIB_PATH="/opt/venv/lib/python3.12/site-packages"
build --python_path="/opt/python3.12/bin/python3.12"
build --action_env TF_PYTHON_VERSION="3.12"
build --action_env TF_NEED_TENSORRT=0
build:tensorrt --repo_env TF_NEED_TENSORRT=0
build:cuda --repo_env TF_CUDA_COMPUTE_CAPABILITIES="compute_89,compute_90,compute_100,compute_120"
build:cuda --repo_env TF_CUDA_PATHS="/usr/local/cuda-12.8"
build:cuda --repo_env CUDNN_INSTALL_PATH="/usr/include/x86_64-linux-gnu,/usr/lib/x86_64-linux-gnu"
build --action_env LD_LIBRARY_PATH="/usr/local/cuda/lib64"
build --config=cuda_clang
build --action_env CLANG_CUDA_COMPILER_PATH="/tmp/staging/LLVM-20.1.7-Linux-X64/bin/clang"
build --action_env CPP_PATH="/tmp/staging/LLVM-20.1.7-Linux-X64/bin/clang++"
build --action_env GCC_PATH="/tmp/staging/LLVM-20.1.7-Linux-X64/bin/clang"
build --action_env CLANG_CUDA_COMPILER_PATH="/tmp/staging/LLVM-20.1.7-Linux-X64/bin/clang"
build:nvcc_clang --config=cuda
build:nvcc_clang --action_env=TF_CUDA_CLANG="0"
build:nvcc_clang --action_env=TF_NVCC_CLANG="1"
build:nvcc_clang --@local_config_cuda//:cuda_compiler=nvcc
build:opt --copt=-Wno-sign-compare
build:opt --host_copt=-Wno-sign-compare
test --test_size_filters=small,medium
test --test_env=LD_LIBRARY_PATH
test:v1 --test_tag_filters=-benchmark-test,-no_oss,-oss_excluded,-no_gpu,-oss_serial
test:v1 --build_tag_filters=-benchmark-test,-no_oss,-oss_excluded,-no_gpu
test:v2 --test_tag_filters=-benchmark-test,-no_oss,-oss_excluded,-no_gpu,-oss_serial,-v1only
test:v2 --build_tag_filters=-benchmark-test,-no_oss,-oss_excluded,-no_gpu,-v1only