#!/bin/bash

THIS_FOLDER=$( cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd ) # get path of this script
source "$THIS_FOLDER/settings.sh"
  
function vtx() {
  echo "Starting tx for $NIC"
  raspivid -ih -t 0 -w "$WIDTH" -h "$HEIGHT" -fps "$FPS" -b "$BITRATE" -n -g "$KEYFRAMERATE" -pf high -o - | $WBC_PATH/tx -p "$PORT" -b "$BLOCK_SIZE" -r "$FECS" -f "$PACKET_LENGTH" "$NIC"

  echo "finished with exit code $?"
  ls /sys/class/net | grep -q eth || echo "should shut down!?"

  killall raspivid
  killall tx
}
  
function vrx() {
  if [ -d "$SAVE_PATH" ]; then
    echo "Starting with recording"
    FILE_NAME="$SAVE_PATH/$(date +"%Y%m%d")-$(ls $SAVE_PATH | wc -l).rawvid"
    $WBC_PATH/rx -p $PORT -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH $NICS | tee "$FILE_NAME" | $DISPLAY_PROGRAM
  else
    echo "Starting without recording"
    $WBC_PATH/rx -p $PORT -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH $NICS | $DISPLAY_PROGRAM
  fi
  echo "finished with exit code $?"
  ls /sys/class/net | grep -q eth || echo "should shut down!?"
}
  
function osd() {
  if [ -d "$SAVE_PATH" ]; then
    echo "Starting osd with recording"
    FILE_NAME="$SAVE_PATH/$(date +"%Y%m%d")-$(ls $SAVE_PATH | wc -l).telem"
    $WBC_PATH/rx -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH -p $PORT $NIC | tee "$FILE_NAME" | $OSD_PATH/osd "/opt/vc/src/hello_pi/hello_font/"
  else
    echo "Starting osd without recording (create $SAVE_PATH to enable recordings)"
    $WBC_PATH/rx -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH -p $PORT $NIC | $OSD_PATH/osd "/opt/vc/src/hello_pi/hello_font/"
  fi
}

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

function keyboardConnected() {
  for dev in /sys/bus/usb/devices/*-*:*
  do
    if [ -f $dev/bInterfaceClass ]
    then
      if [[ "$(cat $dev/bInterfaceClass)" == "03" && "$(cat $dev/bInterfaceProtocol)" == "01" ]]
      then
        echo "Keyboard detected: $dev"
        return 1;
      fi
    fi
  done
  echo "keyboard missing"
  return 0;
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

## only execute this if this script is directly called
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
  if [[ "$1" = "rx" ]]; then
    vrx
  elif [[ "$1" = "tx" ]]; then
    vtx
  elif [[ "$1" = "osd" ]]; then
    osd
  else
    screen -list | grep -q wbcast && { echo "wbcast screen already running!" >&2; exit 0; }
    echo "starting wifi-broadcast!"

    PARENT="$(ps -o comm= $PPID)"
    echo "parent is $PARENT, keyboardConnected = $(keyboardConnected)"
    if [[ "$PARENT" -ne "bash" ]] && keyboardConnected; then
      echo "$0: Keyboard detected, preventing launch!"
      sleep 10
      exit 0
    fi

    checkRoot

    #prepare NICS
    for NIC in $NICS; do
      prepare_nic $NIC
    done

    if hasCamera; then
      ## transmitter ##
      echo "starting transmitter $0"
      screen -AdmS "wbc" $0 tx
    else
      ## receiver ##
      echo "starting receiver $0"
      screen -AdmS wbcast $0 tx
      screen -S wbcast -X zombie qr #enable zombie mode to keep window open after failure
      screen -S wbcast -X screen $0 osd
    fi
    echo "connect with 'screen -r' to view started jobs"
  fi
fi
