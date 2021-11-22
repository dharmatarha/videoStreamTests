#!/bin/bash
#
# USAGE: ./hardverTest.sh LABNAME
#
# Tests for initial setup in the CommGame experiment.
#
# Inputs:
# LABNAME 	- str, "Mordor" or "Gondor"
#
# Main steps:
# (1) Checks IP address of current machine.
# (2) Checks if webcam and sound card are connected
# (3) Checks if the other control PC and the motion PC are reachable on LAN
# 


echo -e "\nInput arg LABNAME: "$1

# check for input args
if [[ $# -eq 0 ]] ; then
    echo "Input arg LABNAME is required (Mordor/Gondor)"
    exit 1
fi
if [[ $1 == "Mordor" ]] || [[ $1 == "Gondor" ]] ; then
    LABNAME=$1
else
    echo "Input arg LABNAME should be either Mordor or Gondor!"
fi

# hardcoded expected IP value for motion PC
MOTIONPC_IP="192.168.1.50"

# assign expected IPs on LAN based on LABNAME
if [[ $LABNAME == "Mordor" ]] ; then
    EXPECTED_IP="192.168.1.10"
    REMOTE_IP="192.168.1.20"
elif [[ $LABNAME == "Gondor" ]] ; then
    EXPECTED_IP="192.168.1.20"
    REMOTE_IP="192.168.1.10"
fi

# get the first IP address for "inet" in the "enp2s0" section   
echo -e "\nChecking IP address..."
REAL_IP=$(ip address | grep -A3 enp9s0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
# compare real ip to expected value
if [ $REAL_IP == $EXPECTED_IP ] ; then
    echo "IP address is "$REAL_IP", CORRECT"
else
    echo "IP address is "$REAL_IP", INCORRECT"
    exit 2
fi


# check for webcam
echo -e "\nChecking webcam..."
VIDEODEVICE=$(v4l2-ctl --list-devices | grep -A 1 "C925e" | grep '/dev/video.*')  # remains empty if webcam is not found
if [ -z $VIDEODEVICE ] ; then
    echo "Webcam not found!"
    exit 3
else
    echo -e "Webcam found at: \n "$VIDEODEVICE
    echo "Webcam is CORRECT"
fi

# check for sound card
echo -e "\nChecking sound card..."
SOUNDCARD=$(lsusb | grep "MAYA22 USB")  # remains empty if sound card is not found
if [[ -z $SOUNDCARD ]] ; then
    echo "MAYA22 sound card not found!"
    exit 4
else
    echo -e "MAYA22 sound card found at: \n"$SOUNDCARD
    echo "Sound card is CORRECT"
fi


# check for other PCs on LAN using ssh
echo -e "\nChecking network connections..."
echo "Trying to connect to REMOTE CONTROL PC..."
ssh -o ConnectTimeout=5 mordor@$REMOTE_IP echo "Connection to REMOTE CONTROL PC is open, CORRECT!"
echo -e "\nChecking network connections..."
echo "Trying to connect to MOTION CONTROL PC..."
ssh -o ConnectTimeout=5 mordor@$MOTIONPC_IP echo "Connection to MOTION CONTROL PC is open, CORRECT!"



exit 0


