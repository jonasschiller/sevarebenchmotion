#!/bin/bash

# Global setup-script running locally on experiment server. 
# Initializing the experiment server

# exit on error
set -e             
# log every command
set -x                         

REPO=$(pos_get_variable repo --from-global)
REPO_COMMIT=$(pos_get_variable repo_commit --from-global)       
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
apt update
apt install -y automake build-essential cmake git libboost-dev libboost-thread-dev \
    libntl-dev libsodium-dev libssl-dev libtool m4 python3 texinfo yasm linux-cpupower \
    python3-pip time parted libomp-dev htop
pip3 install -U numpy
checkConnection "github.com"
echo 'deb http://deb.debian.org/debian testing main' > /etc/apt/sources.list.d/testing.list
echo 'deb http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-17 main' > /etc/apt/sources.list
echo 'deb-src http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-17 main' > /etc/apt/sources.list
apt update -y
apt install -y gcc-12 g++-12
apt install -y clang-16 clang++-16
git clone "$REPO" "$REPO_DIR"
git clone "$REPO2" "$REPO2_DIR"

# load custom htop config
mkdir -p .config/htop
cp "$REPO2_DIR"/helpers/htoprc ~/.config/htop/

cd "$REPO_DIR"
cd cmake
sed -i 's/boost_1_76_0.tar.bz2/boost_1_83_0.tar.bz2/g' BuildBoostLocally.cmake
sed -i 's/f0397ba6e982c4450f27bf32a2a83292aba035b827a5623a14636ea583318c41/6478edfe2f3305127cffe8caf73ea0176c53769f4bf1585be237eb30798c3b8e/g' BuildBoostLocally.cmake
cd ..
mkdir build
cd build
cmake ..
make -j 4

echo "global setup successful "