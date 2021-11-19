#!/bin/bash
#
# USAGE: ./audioCopy.sh PAIRNO LABNAME
# positional argments should be PAIRNO (int) and LABNAME (str, Gondor or Mordor)
#
# Script to copy parts of recorded audio from remote to local control PC.
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

# other lab name and IP
if [[ $LABNAME == "Mordor" ]] ; then
    OTHERLAB="Gondor"
    REMOTE_IP="192.168.1.20"
else
    OTHERLAB="Mordor"
    REMOTE_IP="192.168.1.10"
fi

# expected location of target audio
RESULTDIR="/home/mordor/CommGame/pair"$PAIRNO"/"
TARGETWAV=$RESULTDIR"pair"$PAIRNO"_"$OTHERLAB"_freeConv_audio.wav"
TARGETMAT=$RESULTDIR"pair"$PAIRNO"_"$OTHERLAB"_freeConv_audio.mat"

# copy
scp -i ~/.ssh/id_rsa.pub "mordor@"$REMOTE_IP":"$TARGETWAV $RESULTDIR 
scp -i ~/.ssh/id_rsa.pub "mordor@"$REMOTE_IP":"$TARGETMAT $RESULTDIR
