#!/bin/bash

# Utility script that automates the process of fetching a stable dpdk release,
# configuring its compilation options, building the dpdk libraries, and
# installing shared libraries to /usr/local/lib.

# It seems easier to get static DPDK library to work based on our experience.
# For example, as of 04/2018, we haven't been able to get MLX4 driver to work
# with DPDK shared libraries on the CloudLab m510 cluster.
#
# ===Update 06/2019===
# I have finally figured out why DPDK shared library won't work: a "secret"
# "-d" option must be passed to EAL initialization specifiying the .so files
# when using DPDK shared library. This option is documented here:
# https://doc.dpdk.org/guides/linux_gsg/linux_eal_parameters.html#common-eal-parameters
# You have to include the specific PMD/mempool implementation/etc. used [1,2],
# which is very cumbersome. Honestly, I don't think it's worth the effort.
# Static library is preferred for better performance anyway.
#
#  [1] http://mails.dpdk.org/archives/dev/2018-March/093441.html
#  [2] https://mails.dpdk.org/archives/users/2017-June/002032.html
DPDK_OPTIONS+=" CONFIG_RTE_BUILD_SHARED_LIB=n"

# Download the latest stable release.
DPDK_VER="18.11.2"
DPDK_SRC="https://fast.dpdk.org/rel/dpdk-${DPDK_VER}.tar.xz"

# Create a temporary directory to download and compile the DPDK source code.
tmp_dir=$(mktemp -d -t dpdk-XXXXXXXXXX)
cd $tmp_dir
wget --no-clobber ${DPDK_SRC}
tar xvf dpdk-${DPDK_VER}.tar.xz
cd dpdk*${DPDK_VER}

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
make clean; make $DPDK_OPTIONS -j$NUM_JOBS
#make clean; make $DPDK_OPTIONS EXTRA_CFLAGS="-g -ggdb" -j$NUM_JOBS
sudo make install; sudo ldconfig
