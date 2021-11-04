#!/bin/bash
#
# USAGE: ./freeConv.sh PAIRNO LABNAME
# positional argments should be PAIRNO (int) and LABNAME (str, Gondor or Mordor)
#
# Script to start all elements of the free conversation task
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
    if [[ -z "$MKDIR_RETVAL" ]] ; then
        echo -e "\nCreated results directory for pair "$PAIRNO
    else
        echo -e "\nFailed to create results directory at "$RESULTDIR"!"
        exit 4
    fi
fi     
    

# set IP of remote PC based on lab names
if [ "$LABNAME" == "Mordor" ]; then
  REMOTEIP="192.168.1.20"
elif [ "$LABNAME" == "Gondor" ]; then
  REMOTEIP="192.168.1.10"
fi

# go to relevant dir
cd ~/CommGame/videoStreamTests/

# add relevant dir to path
PATH=~/CommGame/videoStreamTests:$PATH

# query for video device number corresponding to the webcam we intend to use
VIDEODEVICE=$(v4l2-ctl --list-devices | grep -A 1 "C925e" | grep '/dev/video.*')

# start Gstreamer webcam feed
GSTCOMMAND="gst-launch-1.0 -v v4l2src device="$VIDEODEVICE" ! image/jpeg,width=1920,height=1080,framerate=30/1 ! jpegdec ! queue ! videoconvert ! rtpvrawpay ! udpsink host="$REMOTEIP" port=19009 sync=false" 
STREAMLOG=$RESULTDIR"/pair"$PAIRNO"_"$LABNAME"_freeConv_camStreamLog.txt"
gnome-terminal --window -- bash -ic "$GSTCOMMAND 2>&1 | tee $STREAMLOG; exec bash" &

# sleep between starting sub processes
sleep 5s

# start audio channel
AUDIOLOG=$RESULTDIR"/pair"$PAIRNO"_"$LABNAME"_freeConv_audioChannelLog.txt" 
gnome-terminal --window -- bash -ic "audioScript $PAIRNO $LABNAME 2>&1 | tee $AUDIOLOG; exec bash" &

sleep 5s

# start video channel
VIDEOLOG=$RESULTDIR"/pair"$PAIRNO"_"$LABNAME"_freeConv_videoChannelLog.txt" 
gnome-terminal --window -- bash -ic "videoScript $PAIRNO $LABNAME 2>&1 | tee $VIDEOLOG; exec bash"


