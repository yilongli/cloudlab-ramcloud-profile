#!/bin/bash

git clone https://github.com/PlatformLab/RAMCloud.git
cd RAMCloud
git submodule update --init --recursive
ln -s ../../hooks/pre-commit .git/hooks/pre-commit

# Generate localconfig.py for RAMCloud
let num_rcxx=$(geni-get manifest | grep -o "<node " | wc -l)-1
/local/repository/localconfigGen.py $num_rcxx > scripts/localconfig.py

# Generate private makefile configuration
mkdir private
cat >>private/MakefragPrivateTop <<EOL
DEBUG := no
CCACHE := yes

C_STANDARD := c14
CXX_STANDARD := c++14

DPDK := no
DPDK_DIR := dpdk
DPDK_SHARED := no
EOL

# TODO: remove this when dpdkBuild.sh is merged into ramcloud master
cp /local/repository/dpdkBuild.sh scripts/

# Build DPDK libraries
hardware_type=$(geni-get manifest | grep -oP 'hardware_type="\K[^"]*' | head -1)
if [ "$hardware_type" = "m510" ] || [ "$hardware_type" = "xl170" ]; then
    scripts/dpdkBuild.sh
fi
