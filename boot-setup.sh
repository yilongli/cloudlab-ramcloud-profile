#!/bin/bash

# Configurations that need to be (re)done after each reboot

# https://urbanautomaton.com/blog/2014/09/09/redirecting-bash-script-output-to-syslog/
exec 1> >(logger -s -t $(basename $0)) 2>&1

# Disabled hyperthreading by forcing cores 8..15 offline
NUM_CPUS=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
for N in $(seq $((NUM_CPUS/2)) $((NUM_CPUS-1))); do
    echo 0 > /sys/devices/system/cpu/cpu$N/online
done
echo "boot-setup.sh: disabled hyper-threading"

# Disable CPU frequency scaling
cpupower frequency-set -g performance
echo "boot-setup.sh: changed CPU governor to performance"

# Setup password-less ssh between nodes
USERS="root `ls /users`"
for user in $USERS; do
    if [ "$user" = "root" ]; then
        ssh_dir=/root/.ssh
    else
        ssh_dir=/users/$user/.ssh
    fi
    pushd $ssh_dir
    cp geni-key id_rsa
    chmod 600 id_rsa
    chown $user: id_rsa
    ssh-keygen -y -f id_rsa > id_rsa.pub
    cp id_rsa.pub authorized_keys2
    chmod 644 authorized_keys2
    cat >>config <<EOL
    Host *
         StrictHostKeyChecking no
EOL
    chmod 644 config
    popd
done
echo "boot-setup.sh: setup passwordless ssh between nodes"
