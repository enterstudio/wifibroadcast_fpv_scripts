#!/bin/bash

## fancy color output shortcuts ##
[ -t 0 ] && hash tput 2>/dev/null && COLOR_SHELL=true || COLOR_SHELL=false
function endcolor() { [ "$COLOR_SHELL" = true ] && echo "$(tput sgr 0)" || echo "$@"; }
function echo_gr()  { [ "$COLOR_SHELL" = true ] && echo "$(tput setaf 0)$(tput setab 2) $@ $(endcolor)" || echo "$@"; }
function echo_bl()  { [ "$COLOR_SHELL" = true ] && echo "$(tput setaf 7)$(tput setab 4) $@ $(endcolor)" || echo "$@"; }
function echo_rd()  { [ "$COLOR_SHELL" = true ] && echo "$(tput setaf 7)$(tput setab 1) $@ $(endcolor)" || echo "$@"; }
function echo_or()  { [ "$COLOR_SHELL" = true ] && echo "$(tput setaf 0)$(tput setab 3) $@ $(endcolor)" || echo "$@"; }
function echo_ma()  { [ "$COLOR_SHELL" = true ] && echo "$(tput setaf 7)$(tput setab 5) $@ $(endcolor)" || echo "$@"; }

function eecho() { echo_rd "$@" >&2; }
function exiterr() { eecho "$@"; exit 1; }

## Make sure only root can run this
[[ $EUID -ne 0 ]] && exiterr "This script must be run as root";

## ensure we've been given a device to use
DEVICE="$1"
[ -z "$DEVICE" ] && exiterr "argument required: root device to clone to (ex: /dev/sda)"

## ensure we've got the root device, not a partition
DEVICE_TYPE="$(lsblk --output TYPE --nodeps --noheadings $DEVICE)" || exiterr "error getting device type"
[ "disk" != "$DEVICE_TYPE" ] && exiterr "given device ($DEVICE_TYPE) is not a root file device (run lsblk to see topology)"

## get the device mounted to / (rather onerous to do so)
ROOT_FS="$(for d in $(find /dev -type b); do [ "$(mountpoint -d /)" = "$(mountpoint -x $d)" ] && echo $d && break; done)" &&
## get that partition's root device
ROOT_DEVICE="/dev/$(lsblk --output PKNAME --nodeps --noheadings $ROOT_FS)" || exit 1;

## check if we need to format the destination disc
if [[ "$(lsblk --output FSTYPE,LABEL --list $DEVICE)" != "$(lsblk --output FSTYPE,LABEL --list $ROOT_DEVICE)" ]]; then
  echo_or "need to format filesystem!! now it is:"
  lsblk "$DEVICE"
  #TODO format filesystem!
fi

echo_bl "starting backup of $ROOT_DEVICE to $DEVICE"
## get an ordered list of partitions to iderate over, source and destination
SRC_PARTITIONS=($(lsblk --output NAME --noheadings --list $ROOT_DEVICE | tail -n +2)) &&
DEST_PARTITIONS=($(lsblk --output NAME --noheadings --list $DEVICE | tail -n +2)) || exit 1;
for i in "${!SRC_PARTITIONS[@]}"; do
  srcdevice="${SRC_PARTITIONS[$i]}"
  destdevice="${DEST_PARTITIONS[$i]}"
  if [ -z "$(lsblk --output FSTYPE --noheadings --nodeps --list /dev/$destdevice)" ]; then
    echo "skipping logical partition $destdevice"
    continue;
  fi
  DEST_MOUNT="$(lsblk --output MOUNTPOINT --noheadings --nodeps --list /dev/$destdevice)" || exit 1
  if [ -z "$DEST_MOUNT" ]; then
    echo "mounting /dev/$destdevice to /media/$destdevice"
    mkdir -p "/media/$destdevice" &&
    mount "/dev/$destdevice" "/media/$destdevice" || exit 1
    DEST_MOUNT="/media/$destdevice"
    WAS_MOUNTED=true;
  fi
  SRC_MOUNT="$(lsblk --output MOUNTPOINT --noheadings --nodeps --list /dev/$srcdevice)" || exit 1

  echo_ma "rsyncing $destdevice; from $SRC_MOUNT -> $DEST_MOUNT"
  
  EXCLUDE=()
  if [ -e "$SRC_MOUNT/proc" ]; then
    EXCLUDE+=("/dev/*" "/proc/*" "/sys/*" "/tmp/*" "/run/*" "/mnt/*" "/media/*" "/lost+found")
    EXCLUDE+=("/etc/ssh/ssh_host_*" "/etc/hostname")
  fi
  #TODO exclude other mount points

  set -x #echo on
  rsync -aAXv -xx ${EXCLUDE[@]/#/--exclude=} "$SRC_MOUNT/" "$DEST_MOUNT" || exiterr "rsync to $DEST_MOUNT failed";
  set +x #echo off

  [ "true" = "$WAS_MOUNTED" ] && { echo_ma "unmounting $destdevice"; umount "$DEST_MOUNT" || exit 1; }
done







