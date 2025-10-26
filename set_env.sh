# This file must be sourced before anything
export PROJ_DIR=$(pwd)
export DOCKER_TOOLCHAIN_IMAGE="riscv-toolchain"
export TOOLCHAIN_DIR="$PROJ_DIR/toolchains"

eval "$(register-python-argcomplete orchestrator)"
