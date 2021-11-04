#!/bin/bash
#
# USAGE: ./timingTest.sh PAIRNO LABNAME
#
# Script testing the system clock drift and network transmission time across local and remote machines.
#
# Uses SSH to run a simple python3 function on both ends, estimates timings from its output.
#
# Inputs:
# PAIRNO 	- int, 1:99
# LABNAME 	- str, "Mordor" or "Gondor"
#
# 


echo -e "\nInput arg PAIRNO: "$1
echo "Input arg LABNAME: "$2

# check for input args
if [[ $# -ne 2 ]] ; then
    echo "Input args PAIRNO and LABNAME are required!"
    exit 1
fi
if (( $1 > 0 && $1 < 100)) ; then
    PAIRNO=$1
else
    echo "Input arg PAIRNO should be integer between 1 and 99!"
    exit 2
fi    
if [[ $2 == "Mordor" ]] || [[ $2 == "Gondor" ]] ; then
    LABNAME=$2
else
    echo "Input arg LABNAME should be either Mordor or Gondor!"
    exit 3
fi

# check for result dir for pair
RESULTDIR="/home/mordor/CommGame/pair"$PAIRNO
if [[ -d "$RESULTDIR" ]] ; then
    echo -e "\nResult folder for pair "$PAIRNO" already exists."
else
    MKDIR_RETVAL=$(mkdir $RESULTDIR)
    echo $MKDIR_RETVAL
    if [[ -z "$MKDIR_RETVAL" ]]; then
        echo -e "\nCreated results directory for pair "$PAIRNO
    else
        echo -e "\nFailed to create results directory at "$RESULTDIR"!"
        exit 4
    fi
fi     

# hardcoded expected IP value for motion PC
MOTIONPC_IP="192.168.1.30"

# assign expected IPs on LAN based on LABNAME
if [[ $LABNAME == "Mordor" ]] ; then
    LOCAL_IP="192.168.1.10"
    REMOTE_IP="192.168.1.20"
    OTHERLAB="Gondor"
elif [[ $LABNAME == "Gondor" ]] ; then
    LOCAL_IP="192.168.1.20"
    REMOTE_IP="192.168.1.10"
    OTHERLAB="Mordor"
fi


# get current time for filenames, down to minutes
CURRENT_TIME=$(date +%m_%d_%H_%M)
REMOTE_TIMINGFILE=$RESULTDIR"/remoteTiming_"$OTHERLAB"_"$CURRENT_TIME".txt"
LOCAL_TIMINGFILE=$RESULTDIR"/localTiming_"$LABNAME"_"$CURRENT_TIME".txt"

# run ssh and local versions of timing tests
echo -e "\nRunning the timing functions...\n"
ssh "mordor@"$REMOTE_IP "python3 ~/CommGame/videoStreamTests/syncTestUDP.py -i "$LOCAL_IP > $REMOTE_TIMINGFILE &
python3 ~/CommGame/videoStreamTests/syncTestUDP.py -i $REMOTE_IP > $LOCAL_TIMINGFILE
wait
echo -e "\nRELEVANT OUTPUT FROM REMOTE ("$REMOTE_TIMINGFILE")"
tail -4 $REMOTE_TIMINGFILE | head -2
echo -e "\nRELEVANT OUTPUT FROM LOCAL ("$LOCAL_TIMINGFILE")"
tail -4 $LOCAL_TIMINGFILE | head -2


# calculate transmission time and clock drift
# extract first the two median values reported
REMOTE_TIME=$(tail -3 $REMOTE_TIMINGFILE | head -1 | bc -l )
LOCAL_TIME=$(tail -3 $LOCAL_TIMINGFILE | head -1 | bc -l )
TRANSMISSION_TIME=$(echo "scale=8; ("$REMOTE_TIME" + "$LOCAL_TIME")/2*1000" | bc -l)
CLOCK_DRIFT=$(echo "scale=8; ("$LOCAL_TIME" - "$REMOTE_TIME")/2*1000" | bc -l)
echo -e "\nTransmission time was "$TRANSMISSION_TIME" ms"
echo -e "\nClock drift was "$CLOCK_DRIFT" ms (positive value means local clock ahead of remote)"
if [[ $(echo $TRANSMISSION_TIME"<5" | bc) ]] && [[ $(echo $CLOCK_DRIFT"<5" | bc) ]] ; then
    echo -e "\nThese numbers are OK!"
else
    echo -e "\nAt least one of these numbers is NOT OK! Make a note!"
fi

exit 0


