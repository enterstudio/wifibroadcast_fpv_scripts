#!/bin/bash
# rx script

THIS_FOLDER=$( cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd ) # get path of this script
source "$THIS_FOLDER/settings.sh"

PARENT="$(ps -o comm= $PPID)"
echo "parent is $PARENT, keyboardConnected = $(keyboardConnected)"
if [[ "$PARENT" -ne "bash" ]] && keyboardConnected; then
  echo "$0: Keyboard detected, preventing launch!"
  sleep 365d
fi

#if we detect the camera, we fall asleep
if hasCamera; then
  echo "$0: Falling asleep because a camera has been detected"
  sleep 365d
fi

checkRoot

#wait a bit until the wifi cards are ready
sleep 2

DISPLAY_PROGRAM="/opt/vc/src/hello_pi/hello_video/hello_video.bin"

#prepare NICS
for NIC in $NICS; do
  prepare_nic $NIC
done

if [ -d "$SAVE_PATH" ]; then
  echo "Starting with recording"
  FILE_NAME="$SAVE_PATH/$(date +"%Y%m%d")-$(ls $SAVE_PATH | wc -l).rawvid"
  $WBC_PATH/rx -p $PORT -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH $NICS | tee "$FILE_NAME" | $DISPLAY_PROGRAM
else
  echo "Starting without recording"
  $WBC_PATH/rx -p $PORT -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH $NICS | $DISPLAY_PROGRAM
fi

