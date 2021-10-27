#!/bin/bash
#
# USAGE: ./freeConv_d404.sh "pairNo" "labName"
# positional argments should be "pairNo" (int) and "labName" (str, Luca or Adam)

echo "Input arg pairNo: "$1
echo "Input arg labName: "$2

# set IP of remote PC based on lab names
if [ "$2" == "Luca" ]; then
  REMOTEIP="10.160.12.111"
elif [ "$2" == "Adam" ]; then
  REMOTEIP="10.160.12.108"
fi

# go to relevant dir
cd ~/videoStreamTests/

# add relevant dir to path
PATH=~/videoStreamTests:$PATH

# query for video device number corresponding to the webcam we intend to use
VIDEODEVICE=$(v4l2-ctl --list-devices | grep -A 1 "C925e" | grep '/dev/video.*')

# start Gstreamer webcam feed
GSTCOMMAND="gst-launch-1.0 -v v4l2src device="$VIDEODEVICE" ! image/jpeg,width=1920,height=1080,framerate=30/1 ! jpegdec ! queue ! videoconvert ! rtpvrawpay ! udpsink host="$REMOTEIP" port=19009 sync=false" 
STREAMLOG=$1"_"$2"_camStreamLog.txt"
gnome-terminal --window -- bash -ic "$GSTCOMMAND 2>&1 | tee $STREAMLOG; exec bash" &

# sleep between starting sub processes
sleep 5s

# start audio channel
AUDIOLOG=$1"_"$2"_audioChannelLog.txt" 
gnome-terminal --window -- bash -ic "audioScript_d404 $1 $2 2>&1 | tee $AUDIOLOG; exec bash" &

sleep 5s

# start video channel
VIDEOLOG=$1"_"$2"_videoChannelLog.txt" 
gnome-terminal --window -- bash -ic "videoScript_d404 $1 $2 2>&1 | tee $VIDEOLOG; exec bash"
