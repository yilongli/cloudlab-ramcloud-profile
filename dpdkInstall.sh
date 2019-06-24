#!/bin/bash

# Utility script that automates the process of fetching a stable dpdk release,
# configuring its compilation options, building the dpdk libraries, and
# installing shared libraries to /usr/local/lib.

# It seems easier to get static DPDK library to work based on our experience.
# For example, as of 04/2018, we haven't been able to get MLX4 driver to work
# with DPDK shared libraries on the CloudLab m510 cluster.
DPDK_OPTIONS+=" CONFIG_RTE_BUILD_SHARED_LIB=y"

# Download the latest stable release.
DPDK_VER="18.11.1"
DPDK_SRC="https://fast.dpdk.org/rel/dpdk-${DPDK_VER}.tar.xz"
DPDK_DIR="dpdk-stable-${DPDK_VER}"

# Create a temporary directory to download and compile the DPDK source code.
tmp_dir=$(mktemp -d -t dpdk-XXXXXXXXXX)
cd $tmp_dir
wget --no-clobber ${DPDK_SRC}
tar xvf dpdk-${DPDK_VER}.tar.xz
cd ${DPDK_VER}

# Build the libraries, assuming an x86_64 linux target, and a gcc-based
# toolchain. Compile position-indepedent code, which will be linked by
# RAMCloud code, and produce a unified object archive file.
TARGET=x86_64-native-linuxapp-gcc
NUM_JOBS=`grep -c '^processor' /proc/cpuinfo`
if [ "$NUM_JOBS" -gt 2 ]; then
    let NUM_JOBS=NUM_JOBS-2
fi

make config T=$TARGET O=$TARGET
cd $TARGET
sed -ri 's,(MLX._PMD=)n,\1y,' .config
make clean; make $DPDK_OPTIONS -j$NUM_JOBS install
