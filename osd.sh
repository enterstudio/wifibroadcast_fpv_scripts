#!/bin/bash
# OSD

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

sleep 10

if [ -d "$SAVE_PATH" ]; then
  echo "Starting osd with recording"
  FILE_NAME="$SAVE_PATH/$(date +"%Y%m%d")-$(ls $SAVE_PATH | wc -l).telem"
  $WBC_PATH/rx -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH -p $PORT $NIC | tee "$FILE_NAME" | $OSD_PATH/osd "/opt/vc/src/hello_pi/hello_font/"
else
  echo "Starting osd without recording (create $SAVE_PATH to enable recordings)"
  $WBC_PATH/rx -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH -p $PORT $NIC | $OSD_PATH/osd "/opt/vc/src/hello_pi/hello_font/"
fi

