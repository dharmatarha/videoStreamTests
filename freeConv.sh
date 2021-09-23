#!/bin/bash
#
# USAGE: ./freeConv.sh "pairNo" "labName"
# positional argments should be "pairNo" (int) and "labName" (str, Gondor pr Mordor)

echo "Input arg pairNo: "$1
echo "Input arg labName: "$2

# go to relevant dir
cd ~/CommGame/videoStreamTests/

# add relevant dir to path
PATH=~/CommGame/videoStreamTests:$PATH

# start Gstreamer webcam feed
# command depends on lab name
if [ "$2" == "Mordor" ]; then
  gstCommand="gst-launch-1.0 -v v4l2src device=/dev/video0 ! image/jpeg,width=1920,height=1080,framerate=30/1 ! jpegdec ! queue ! videoconvert ! rtpvrawpay ! udpsink host=192.168.1.60 port=19009 sync=false"
elif [ "$2" == "Gondor" ]; then
   gstCommand="gst-launch-1.0 -v v4l2src device=/dev/video0 ! image/jpeg,width=1920,height=1080,framerate=30/1 ! jpegdec ! queue ! videoconvert ! rtpvrawpay ! udpsink host=192.168.1.1 port=19009 sync=false" 
fi
   
STREAMLOG=$1"_"$2"_camStreamLog.txt"
gnome-terminal --window -- bash -ic "$gstCommand 2>&1 | tee $STREAMLOG; exec bash" &

# start audio channel
AUDIOLOG=$1"_"$2"_audioChannelLog.txt" 
gnome-terminal --window -- bash -ic "audioScript $1 $2 2>&1 | tee $AUDIOLOG; exec bash" &

# start video channel
VIDEOLOG=$1"_"$2"_videoChannelLog.txt" 
gnome-terminal --window -- bash -ic "videoScript $1 $2 2>&1 | tee $VIDEOLOG; exec bash"
