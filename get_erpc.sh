#!/bin/bash

# Note: only written for xl170 with MLNX OFED installed as
# "--dpdk --upstream-libs"

git clone git@github.com:yilongli/eRPC.git
cd eRPC

# Build eRPC for basic testing
# TODO: eRPC build system is kinda awkward
#   1) using CMake but not out-of-source building
#   2) -DPERF=ON can't work with unit-testing?
#   3) How to control whether to output static or shared library?
#   4) Profile-guided opt enabled by default? who is gonna use that? huh?
#   5) LTO enabled by default? how/when is it applied?
cmake . -DPERF=OFF -DTRANSPORT=dpdk
make -j
scripts/run-tests-dpdk.sh

# Build hello-world?
# cmake . -DPERF=ON -DPGO=none -DLTO=OFF -DTRANSPORT=dpdk

# Build other more interesting example apps?
