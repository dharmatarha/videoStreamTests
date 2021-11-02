#!/bin/bash
#
# USAGE: ./cleanUp.sh
#
# Main clean-up steps:
# (1) Cleans up lingering octave / psychtoolbox / gstreamer / sound processes 
# after a botched run of freeConv.sh or its bargaining game equivalent
# (2) Reloads the audio system via systemd
# (3) Resets USB connections to the sound card and webcam we rely on
#

# kill all target processes
pkill -i -9 "octave|gstreamer|matlab|gst|pulseaudio"

# reload audio
# pulseaudio -k && sudo alsa force-reload
systemctl --user restart pulseaudio

## reset all usb devices
#for port in $(lspci | grep USB | cut -d' ' -f1); do
#    echo -n "0000:${port}"| sudo tee /sys/bus/pci/drivers/xhci_hcd/unbind;
#    sleep 5;
#    echo -n "0000:${port}" | sudo tee /sys/bus/pci/drivers/xhci_hcd/bind;
#    sleep 5;
#done

# reset USB-connected webcam and sound card
usbreset "Logitech Webcam C925e"
usbreset "MAYA22 USB"
