#!/bin/bash

# Global setup-script running locally on experiment server. 
# Initializing the experiment server

# exit on error
set -e             
# log every command
set -x                         

echo "Test" >> librarybuildlog
REPO=$(pos_get_variable repo --from-global)     
REPO_DIR=$(pos_get_variable repo_dir --from-global)
REPO2=$(pos_get_variable repo2 --from-global)
REPO2_DIR=$(pos_get_variable repo2_dir --from-global)

cd "$REPO_DIR"/build
# determine the number of jobs for compiling via available ram and cpu cores
maxcoresram=$(($(grep "MemTotal" /proc/meminfo | awk '{print $2}')/(1024*2500)))
maxcorescpu=$(($(nproc --all)-1))
# take the minimum of the two options
maxjobs=$(( maxcoresram < maxcorescpu ? maxcoresram : maxcorescpu ))
make -j "$maxjobs" all
make install


echo "global setup successful " >> librarybuildlog
pos_upload librarybuildlog