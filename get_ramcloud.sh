#!/bin/bash

git clone https://github.com/PlatformLab/RAMCloud.git
cd RAMCloud
git submodule update --init --recursive
ln -s ../../hooks/pre-commit .git/hooks/pre-commit

# Generate localconfig.py for RAMCloud
let num_rcxx=$(geni-get manifest | grep -o "<node " | wc -l)-2
/local/repository/localconfigGen.py $num_rcxx > scripts/localconfig.py

# Generate private makefile configuration
mkdir private
cat >>private/MakefragPrivateTop <<EOL
DEBUG := no

CCACHE := yes
LINKER := gold
DEBUG_OPT := yes

GLIBCXX_USE_CXX11_ABI := yes

DPDK := yes
DPDK_DIR := dpdk
DPDK_SHARED := no
EOL

# Build DPDK libraries
hardware_type=$(geni-get manifest | grep -oP 'hardware_type="\K[^"]*' | head -1)
mlnx_dpdk=n
if [ "$hardware_type" = "m510" ] || [ "$hardware_type" = "xl170" ]; then
    mlnx_dpdk=y
fi
MLNX_DPDK=$mlnx_dpdk scripts/dpdkBuild.sh
