#!/bin/bash
#
# USAGE: ./cleanUp.sh
#
# Main clean-up steps:
# (1) Cleans up lingering octave / psychtoolbox / gstreamer processes 
# after a botched run of freeConv.sh or its bargaining game equivalent
# (2) Reloads the audio system via systemd
#

# kill all target processes
pkill -i -9 "octave|gstreamer|matlab"

# reload audio
# ? pulseaudio -k && sudo alsa force-reload ?
systemctl --user restart pulseaudio

