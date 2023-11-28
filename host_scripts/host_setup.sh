#!/bin/bash

# Global setup-script running locally on experiment server. 
# Initializing the experiment server

# exit on error
set -e             
# log every command
set -x                         

REPO=$(pos_get_variable repo --from-global)     
REPO_DIR=$(pos_get_variable repo_dir --from-global)
REPO2=$(pos_get_variable repo2 --from-global)
REPO2_DIR=$(pos_get_variable repo2_dir --from-global)

# check WAN connection, waiting helps in most cases
checkConnection() {
    address=$1
    i=0
    maxtry=5
    success=false
    while [ $i -lt $maxtry ] && ! $success; do
        success=true
        echo "____ping $1 try $i" >> pinglog_external
        ping -q -c 2 "$address" >> pinglog_external || success=false
        ((++i))
        sleep 2s
    done
    $success
}


checkConnection "mirror.lrz.de"
echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean false' | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y automake build-essential cmake git libboost-dev libboost-thread-dev \
    libntl-dev libsodium-dev libssl-dev libtool m4 texinfo yasm linux-cpupower \
    python3-pip time parted libomp-dev htop wget gnupg software-properties-common \
    lsb-release 
pip3 install -U numpy
checkConnection "github.com"
echo 'deb http://deb.debian.org/debian testing main' > /etc/apt/sources.list.d/testing.list
#bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"
apt update -y
apt install -y gcc-12 g++-12
git clone "$REPO" "$REPO_DIR"
git clone "$REPO2" "$REPO2_DIR"

# load custom htop config
mkdir -p .config/htop
cp "$REPO2_DIR"/helpers/htoprc ~/.config/htop/
cd "$REPO_DIR"
mkdir build
cd build
cmake .. -DMOTION_BUILD_EXE=On
# determine the number of jobs for compiling via available ram and cpu cores
maxcoresram=$(($(grep "MemTotal" /proc/meminfo | awk '{print $2}')/(1024*2500)))
maxcorescpu=$(($(nproc --all)-1))
# take the minimum of the two options
maxjobs=$(( maxcoresram < maxcorescpu ? maxcoresram : maxcorescpu ))
make -j "$maxjobs" all
make install
cd /root
chmod 777 /root/sevarebenchmotion /root/MOTION -R
echo "global setup successful"
