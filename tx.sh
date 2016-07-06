#!/bin/bash
# tx script

THIS_FOLDER=$( cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd ) # get path of this script
echo "THIS_FOLDER -> $THIS_FOLDER"

source "$THIS_FOLDER/settings.sh"

#if we detect no camera, we fall asleep
if ! hasCamera; then
  echo "tx.sh: Falling asleep because no camera has been detected"
  sleep 365d
fi

checkRoot

#wait a bit. this helps automatic starting
sleep 2

prepare_nic $NIC

echo "Starting tx for $NIC"
raspivid -ih -t 0 -w $WIDTH -h $HEIGHT -fps $FPS -b $BITRATE -n -g $KEYFRAMERATE -pf high -o - | $WBC_PATH/tx -p $PORT -b $BLOCK_SIZE -r $FECS -f $PACKET_LENGTH $NIC > /dev/null

killall raspivid
killall tx
