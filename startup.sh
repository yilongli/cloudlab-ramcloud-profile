#!/bin/bash

# Log output of this script to syslog.
# https://urbanautomaton.com/blog/2014/09/09/redirecting-bash-script-output-to-syslog/
exec 1> >(logger -s -t $(basename $0)) 2>&1

# Variables
HOSTNAME=$(hostname -f | cut -d"." -f1)
HW_TYPE=$(geni-get manifest | grep $HOSTNAME | grep -oP 'hardware_type="\K[^"]*')
MLNX_OFED_VER=4.5-1.0.1.0
if [ "$HW_TYPE" = "m510" ] || [ "$HW_TYPE" = "xl170" ] || [ "$HW_TYPE" = "r320" ]; then
    OS_VER="ubuntu`lsb_release -r | cut -d":" -f2 | xargs`"
    MLNX_OFED="MLNX_OFED_LINUX-$MLNX_OFED_VER-$OS_VER-x86_64"
fi
SHARED_HOME="/shome"
USERS="root `ls /users`"

# Test if startup service has run before.
# TODO: why?
if [ -f /local/startup_service_done ]; then
    exit 0
fi


# Install common utilities
apt-get update
apt-get --assume-yes install ccache mosh vim tmux pdsh tree axel

# NFS
apt-get --assume-yes install nfs-kernel-server nfs-common

# cpupower, hugepages, msr-tools (for rdmsr), i7z
kernel_release=`uname -r`
apt-get --assume-yes install linux-tools-common linux-tools-${kernel_release} \
        hugepages cpuset msr-tools i7z
apt-get -y install tuned

# Dependencies to build the Linux perf tool
apt-get --assume-yes install systemtap-sdt-dev libunwind-dev libaudit-dev \
        libgtk2.0-dev libperl-dev binutils-dev liblzma-dev libiberty-dev

# Install RAMCloud dependencies
apt-get --assume-yes install build-essential git-core doxygen libpcre3-dev \
        protobuf-compiler libprotobuf-dev libcrypto++-dev libevent-dev \
        libboost-all-dev libgtest-dev libzookeeper-mt-dev zookeeper \
        libssl-dev

# Downgrade to JDK 8.0 to make RAMCloud's java binding happy.
apt-get --assume-yes remove openjdk*
apt-get --assume-yes install openjdk-8-jdk

# Install crontab job to run the following script every time we reboot:
# https://superuser.com/questions/708149/how-to-use-reboot-in-etc-cron-d
echo "@reboot root /local/repository/boot-setup.sh" > /etc/cron.d/boot-setup

# Setup password-less ssh between nodes
for user in $USERS; do
    if [ "$user" = "root" ]; then
        ssh_dir=/root/.ssh
    else
        ssh_dir=/users/$user/.ssh
    fi
    pushd $ssh_dir
    /usr/bin/geni-get key > geni-key
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

# Change user login shell to Bash
for user in `ls /users`; do
    chsh -s `which bash` $user
done

# Fix "rcmd: socket: Permission denied" when using pdsh
echo ssh > /etc/pdsh/rcmd_default

hostname=`hostname --short`
if [ "$hostname" = "rcnfs" ]; then
    # Setup nfs server following instructions from the links below:
    #   https://vitux.com/install-nfs-server-and-client-on-ubuntu/
    #   https://linuxconfig.org/how-to-configure-a-nfs-file-server-on-ubuntu-18-04-bionic-beaver
    # In `cloudlab-profile.py`, we already asked for a temporary file system
    # mounted at /shome.
    chmod 777 $SHARED_HOME
    echo "$SHARED_HOME *(rw,sync,no_root_squash)" >> /etc/exports

    # Enable nfs server at boot time.
    # https://www.shellhacks.com/ubuntu-centos-enable-disable-service-autostart-linux/
    systemctl enable nfs-kernel-server
    systemctl restart nfs-kernel-server

    # Generate a list of machines in the cluster
    cd $SHARED_HOME
    > rc-hosts.txt
    let num_rcxx=$(geni-get manifest | grep -o "<node " | wc -l)-2
    for i in $(seq "$num_rcxx")
    do
        printf "rc%02d\n" $i >> rc-hosts.txt
    done
    printf "rcmaster\n" >> rc-hosts.txt
    printf "rcnfs\n" >> rc-hosts.txt

    # Download Mellanox OFED package
    if [ ! -z "$MLNX_OFED" ]; then
        axel -n 8 -q http://www.mellanox.com/downloads/ofed/MLNX_OFED-$MLNX_OFED_VER/$MLNX_OFED.tgz
        tar xzf $MLNX_OFED.tgz
    fi

    # Mark the startup service has finished
    > /local/startup_service_done
    logger -s "Startup service finished"
else
    # Enable hugepage support: http://dpdk.org/doc/guides/linux_gsg/sys_reqs.html
    # The changes will take effects after reboot. m510 is not a NUMA machine.
    # Reserve 1GB hugepages via kernel boot parameters
    kernel_boot_params="default_hugepagesz=1G hugepagesz=1G hugepages=8"

    # Update GRUB with our kernel boot parameters
    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$kernel_boot_params /" /etc/default/grub
    update-grub

    # Wait until rcnfs is properly set up
    while [ "$(ssh rcnfs "[ -f /local/startup_service_done ] && echo 1 || echo 0")" != "1" ]; do
        sleep 1
    done

    # NFS clients setup: use the publicly-routable IP addresses for both the server
    # and the clients to avoid interference with the experiment.
    rcnfs_ip=`ssh rcnfs "hostname -i"`
    mkdir $SHARED_HOME; mount -t nfs4 $rcnfs_ip:$SHARED_HOME $SHARED_HOME
    echo "$rcnfs_ip:$SHARED_HOME $SHARED_HOME nfs4 rw,sync,hard,intr,addr=`hostname -i` 0 0" >> /etc/fstab

    if [ ! -z "$MLNX_OFED" ]; then
        # Install Mellanox OFED (need reboot to work properly). Note: attempting to build
        # MLNX DPDK before installing MLNX OFED may result in compile-time errors.
        $SHARED_HOME/$MLNX_OFED/mlnxofedinstall --force --without-fw-update
    fi

    # Mark the startup service has finished
    > /local/startup_service_done
    logger -s "Startup service finished"

    # Reboot to let the configuration take effects
    reboot
fi

