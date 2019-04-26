#!/bin/bash
/local/repository/get_ramcloud.sh
cd RAMCloud
git remote add yilongl https://github.com/yilongli/RAMCloud.git
git fetch yilongl millisort
git checkout -t yilongl/millisort

git clone --recursive https://github.com/PlatformLab/arachne-all.git
cd arachne-all
./buildAll.sh
cd ..

