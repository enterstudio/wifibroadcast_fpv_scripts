#!/bin/bash
# OSD

THIS_FOLDER=$( cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd ) # get path of this script
echo "THIS_FOLDER -> $THIS_FOLDER"


#if we detect the camera, we fall asleep
if hasCamera; then
  echo "osd.sh: Falling asleep because a camera has been detected"
  sleep 365d
fi

sleep 10

checkRoot

if [ -d "$SAVE_PATH" ]; then
  echo "Starting osd with recording"
  $WBC_PATH/rx -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH -p $PORT $NIC | tee "$SAVE_PATH/$(ls $SAVE_PATH | wc -l).telem" | $OSD_PATH/osd /opt/vc/src/hello_pi/hello_font/
else
  echo "Starting osd without recording"
  $WBC_PATH/rx -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH -p $PORT $NIC | $OSD_PATH/osd $FRSKY_OMX_OSD_PATH
fi

