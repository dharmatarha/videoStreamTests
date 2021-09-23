#!/bin/bash

# positional argments should be "pairNo" (int) and "labName" (str, Gondor pr Mordor)

echo "Input arg pairNo: "$1
echo "Input arg labName: "$2

# go to relevant dir
cd ~/ComMGame/videoStreamTests/

# add relevant dir to path
PATH=~/CommGame/videoStreamTests:$PATH

# start Gstreamer webcam feed


# start audio channel
AUDIOLOG=$1"_"$2"_audioChannelLog.txt" 
gnome-terminal --window -- bash -ic "audioScript $1 $2 2>&1 | tee $AUDIOLOG; exec bash" &

# start video channel
VIDEOLOG=$1"_"$2"_videoChannelLog.txt" 
gnome-terminal --window -- bash -ic "audioScript $1 $2 2>&1 | tee $VIDEOLOG; exec bash"
