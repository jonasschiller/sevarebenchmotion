#!/bin/bash
# shellcheck disable=SC1091,2154

#
# Script is run locally on experiment server.
#

# exit on error
set -e
# log every command
set -x

#Get motion directory
REPO_DIR=$(pos_get_variable repo_dir --from-global)
#Get sevarebench directory
REPO2_DIR=$(pos_get_variable repo2_dir --from-global)
#Set up measurement and define what to measure and output format
timerf="%M (Maximum resident set size in kbytes)\n%e (Elapsed wall clock time in seconds)\n%P (Percent of CPU this job got)"
#Get player id
player=$1
# test types to simulate changing environments like cpu frequency or network latency
read -r -a types <<< "$2"
network="$3"
partysize=$4
experiment=$5
number_of_bits=$6
integer_size=$7
# default to etype 1 if unset
etype=${etype:-1}

cd "$REPO_DIR"/build/bin

####
#  environment manipulation section start
####
# shellcheck source=../host_scripts/manipulate.sh
source "$REPO2_DIR"/host_scripts/manipulate.sh

case " ${types[*]} " in
    *" CPUS "*)
        limitCPUs;;&
    *" RAM "*)
        limitRAM;;&
    *" QUOTAS "*)
        setQuota;;&
    *" FREQS "*)
        setFrequency;;&
    *" BANDWIDTHS "*)
        # check whether to manipulate a combination
        case " ${types[*]} " in
            *" LATENCIES "*)
                setLatencyBandwidth;;
            *" PACKETDROPS "*) # a.k.a. packet loss
                setBandwidthPacketdrop;;
            *)
                limitBandwidth;;
        esac;;
    *" LATENCIES "*)
        if [[ " ${types[*]} " == *" PACKETDROPS "* ]]; then
            setPacketdropLatency
        else
            setLatency
        fi;;
    *" PACKETDROPS "*)
        setPacketdrop;;
esac

####
#  environment manipulation section stop
####



log=testresultsFirstRun
touch "$log"

success=true
skip=false    
pos_sync --timeout 300

#Build a String of the IP Adresses of the parties
ips=""
for i in $(seq 2 $((partysize+1))); do
    ips+="$((i-2)),10.10.$network.$i,2300$i "
done

# run the SMC protocol
$skip ||
    /bin/time -f "$timerf" ./"$experiment" --my-id $player --parties $ips &> "$log" || success=false

pos_upload  "$log"

#abort if no success
$success

pos_sync



####
#  environment manipulation reset section start
####

case " ${types[*]} " in

    *" FREQS "*)
        resetFrequency;;&
    *" RAM "*)
        unlimitRAM;;&
    *" BANDWIDTHS "*|*" LATENCIES "*|*" PACKETDROPS "*)
    	resetTrafficControl;;&
    *" CPUS "*)
        unlimitCPUs
esac

####
#  environment manipulation reset section stop
####


pos_sync

echo "experiment successful"  >> measurementlog

pos_upload measurementlog