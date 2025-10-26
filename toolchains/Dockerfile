FROM ubuntu:22.04

ARG TOOLCHAIN_URL="https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2025.10.18/riscv32-elf-ubuntu-22.04-gcc.tar.xz"

ENV DEBIAN_FRONTEND=noninteractive

RUN set -e; \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        xz-utils \
        libmpc3 \
        libmpfr6 \
        libgmp10 \
        zlib1g \
        libexpat1 \
    \
    && echo "Downloading toolchain from ${TOOLCHAIN_URL}" \
    && wget -q "${TOOLCHAIN_URL}" -O /tmp/riscv-toolchain.tar.xz \
    \
    && echo "Extracting toolchain..." \
    && tar -xJf /tmp/riscv-toolchain.tar.xz -C /opt \
    \
    # 4. Clean up to reduce the final image size.
    && echo "Cleaning up..." \
    && rm /tmp/riscv-toolchain.tar.xz \
    && apt-get purge -y --auto-remove wget xz-utils ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/riscv/bin:${PATH}"

WORKDIR /work

# we don't need to create a user in the Dockerfile if we always use
# the --user flag in the wrapper script.
CMD ["/bin/bash"]
