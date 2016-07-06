#!/bin/bash

# Camera image settings
WIDTH=1280
HEIGHT=720
FPS=48
BITRATE=4000000
KEYFRAMERATE=48


# Transmission and recording settings
NIC="wlan0"
CHANNEL2G="13"
CHANNEL5G="149"
NICS=`ls /sys/class/net | grep wlan`
SAVE_PATH="$HOME/video"

WBC_PATH="$THIS_FOLDER/../wifibroadcast"
OSD_PATH="$THIS_FOLDER/../wifibroadcast_osd"


##################################
#change these only if you know what you are doing (and remember to change them on both sides)
BLOCK_SIZE=8
FECS=4
PACKET_LENGTH=1024
PORT=0
##################################

## Common Utility functions ##

function hasCamera() {
  vcgencmd get_camera | grep -q detected=1;
}

function checkRoot() {
  # Make sure only root can run our script
  if [[ $EUID -ne 0 ]]; then
     echo "This script must be run as root" 1>&2
     exit 1
  fi
}

function prepare_nic {
  DRIVER=`cat /sys/class/net/$1/device/uevent | grep DRIVER | sed 's/DRIVER=//'`

  case $DRIVER in
    ath9k_htc)
      echo "Setting $1 to channel $CHANNEL2G"
      ifconfig $1 down
      iw dev $1 set monitor otherbss fcsfail
      ifconfig $1 up
      iwconfig $1 channel $CHANNEL2G
    ;;
    rt2800usb)
      echo "Setting $1 to channel $CHANNEL5G"
      ifconfig $1 down
      iw dev $1 set monitor otherbss fcsfail
      ifconfig $1 up
      iw reg set BO
      iwconfig $1 rate 24M
      iwconfig $1 channel $CHANNEL5G
    ;;
    *) echo "ERROR: Unknown wifi driver on $1: $DRIVER" && exit
    ;;
  esac
}

