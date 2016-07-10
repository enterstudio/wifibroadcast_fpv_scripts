#!/bin/bash

THIS_FOLDER=$( cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd ) # get path of this script
source "$THIS_FOLDER/settings.sh"

function eecho() { echo "$@" >&2; }

function logFilePath() {
  echo "$SAVE_PATH/$(date +"%Y%m%d-%H%M%S")-$(ls "$SAVE_PATH/$(date +%Y%m%d)-*" | wc -l).rawvid"
}

function waitWlanUnplug() {
  #argument 1: network card to watch
  while true; do
    if ! ls /sys/class/net | grep -q "${1:-wlan}"; then
      if ! ls /sys/class/net | grep -q eth; then
        return
      fi
    fi
    sleep 10
  done
}

function startTransmit() {
  hasCamera || { eecho "no camera!"; exit 1; }
  while true; do
    NICS="$(getInterfaces)";
    if [[ $(echo $NICS | wc -l) -ne 1 ]]; then ##no/too many interfaces!
      echo "interfaces missing $NICS != 1";
      sleep 6;
      continue;
    fi
    
    {
      sleep 10;
      echo "now monitoring for wlan disconnects"
      waitWlanUnplug "$NICS";
      echo "Network adapter $NICS unplugged! Shutting down!"
      killall raspivid &>/dev/null
      killall tx &>/dev/null
      poweroff;
    } &

    if [ -d "$SAVE_PATH" ]; then
      local FILE_NAME="$(logFilePath)"
      echo "Starting with recording to $FILE_NAME"
      raspivid -ih -t 0 -w "$WIDTH" -h "$HEIGHT" -fps "$FPS" -b "$BITRATE" -n -g "$KEYFRAMERATE" -pf high -o - |
        tee "$FILE_NAME" | $WBC_PATH/tx -p "$PORT" -b "$BLOCK_SIZE" -r "$FECS" -f "$PACKET_LENGTH" "$NICS"
    else
      echo "Starting without recording"
      raspivid -ih -t 0 -w "$WIDTH" -h "$HEIGHT" -fps "$FPS" -b "$BITRATE" -n -g "$KEYFRAMERATE" -pf high -o - |
        $WBC_PATH/tx -p "$PORT" -b "$BLOCK_SIZE" -r "$FECS" -f "$PACKET_LENGTH" "$NICS"
    fi

    echo "finished with exit code $?"
    killall raspivid &>/dev/null
    killall tx &>/dev/null
    sleep 5
  done
  sleep 2
}

function startReceive() {
  while true; do
    NICS="$(getInterfaces)";
    if [[ -z $NICS ]]; then ##no interfaces!
      echo "$NICS != 1";
      sleep 1;
      continue;
    fi
    
    {
      sleep 10;
      echo "now monitoring for wlan disconnects"
      waitWlanUnplug "$NICS";
      echo "Network adapter $NICS unplugged! Shutting down!"
      killall $(basename $DISPLAY_PROGRAM) &>/dev/null
      killall rx &>/dev/null
      sleep 5
      poweroff;
    } &

    if [ -d "$SAVE_PATH" ]; then
      local FILE_NAME="$(logFilePath)"
      echo "Starting with recording to $FILE_NAME"
      $WBC_PATH/rx -p $PORT -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH $NICS | tee "$FILE_NAME" | $DISPLAY_PROGRAM
    else
      echo "Starting without recording"
      $WBC_PATH/rx -p $PORT -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH $NICS | $DISPLAY_PROGRAM
    fi
    echo "finished with exit code $?"
  done
}

function startOSD() {
  if [ -d "$SAVE_PATH" ]; then
    echo "Starting osd with recording"
    FILE_NAME="$SAVE_PATH/$(date +"%Y%m%d")-$(ls $SAVE_PATH | wc -l).telem"
    $WBC_PATH/rx -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH -p $PORT $NIC | tee "$FILE_NAME" |
      $OSD_PATH/osd "/opt/vc/src/hello_pi/hello_font/"
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
  # Make sure only root can run this
  [[ $EUID -ne 0 ]] && { eecho "This script must be run as root"; return 1; } || return 0;
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

function getInterfaces() {
  local NICS="$(ls /sys/class/net | grep wlan)";
  local -a RET
  if [[ -z $NICS ]]; then ##no interfaces!
    # eecho "no interfaces ($NICS)";
    return 1;
  else
    local NIC
    for NIC in $NICS; do
      ##avoid re-preparing the nic
      if ifconfig $NIC | grep -q "encap:UNSPEC"; then
        eecho "already setup $NIC"
        RET+="$NIC"
      else
        prepareNic "$NIC" && RET+=$NIC || eecho "error $NIC";
      fi
    done
  fi
  echo "${RET}"
}

function prepareNic() {
  local DRIVER=$(cat "/sys/class/net/$1/device/uevent" | grep DRIVER | sed 's/DRIVER=//')

  checkRoot || return 1;
  case $DRIVER in
    ath9k_htc)
      eecho "Setting $1 to channel $CHANNEL2G"
      ifconfig $1 down
      iw dev $1 set monitor otherbss fcsfail
      ifconfig $1 up
      iwconfig $1 channel $CHANNEL2G
    ;;
    rt2800usb)
      eecho "Setting $1 to channel $CHANNEL5G"
      ifconfig $1 down
      iw dev $1 set monitor otherbss fcsfail
      ifconfig $1 up
      iw reg set BO
      iwconfig $1 rate 24M
      iwconfig $1 channel $CHANNEL5G
    ;;
    *) { eecho "ERROR: Unknown wifi driver on $1: $DRIVER" && return 1; }
    ;;
  esac
  eecho "successfully setup $1 (with driver $DRIVER)"
  return 0;
}

## only execute this if this script is directly called
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
  if [[ "$1" = "rx" ]]; then    startReceive
  elif [[ "$1" = "tx" ]]; then  startTransmit
  elif [[ "$1" = "osd" ]]; then startOSD
  else
    screen -list | grep -q wbcast && { eecho "wbcast screen already running!"; exit 0; }
    echo "starting wifi-broadcast!"

    PARENT="$(ps -o comm= $PPID)"
    echo "parent is $PARENT, keyboardConnected = $(keyboardConnected)"
    if [[ "$PARENT" -ne "bash" ]] && keyboardConnected; then
      echo "$0: Keyboard detected, preventing launch!"
      sleep 10
      exit 0
    fi

    checkRoot || exit 1

    if hasCamera; then
      ## transmitter ##
      echo "starting transmitter $0"
      # screen -AdmS wbcast bash
      # screen -S wbcast -X zombie qr #enable zombie mode to keep window open after failure
      # screen -S wbcast -X screen $0 tx
      startTransmit
    else
      ## receiver ##
      echo "starting receiver $0"
      startReceive
      # screen -dmS wbcast $0 rx
      # screen -S wbcast -X zombie qr #enable zombie mode to keep window open after failure
      # screen -S wbcast -X screen $0 osd
    fi
    # echo "connect with 'screen -r' to view started jobs $(screen -ls)"
  fi
fi
