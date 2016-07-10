#!/bin/bash

# Camera image settings
WIDTH=1280
HEIGHT=720
FPS=48
BITRATE=4000000
KEYFRAMERATE=24


# Transmission and recording settings
CHANNEL2G="13"
CHANNEL5G="149"
SAVE_PATH="/data/video"

WBC_PATH="$THIS_FOLDER/../wifibroadcast"
OSD_PATH="$THIS_FOLDER/../osd"

DISPLAY_PROGRAM="/opt/vc/src/hello_pi/hello_video/hello_video.bin"

##################################
#change these only if you know what you are doing (and remember to change them on both sides)
BLOCK_SIZE=8
FECS=4
PACKET_LENGTH=1024
PORT=0
TELEM_PORT=1
##################################
