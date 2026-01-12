# This file must be sourced before anything
export PROJ_DIR=$(pwd)
export BUILD_DIR=build
export DOCKER_TOOLCHAIN_IMAGE="riscv-toolchain"
export TOOLCHAIN_DIR="$PROJ_DIR/toolchains"
export PROGRAMS_DIR="$PROJ_DIR/programs"

eval "$(register-python-argcomplete orchestrator)"
