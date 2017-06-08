#!/usr/bin/env bash

set -eo pipefail

usage()
{
  cat << EOF
usage: $0 [options]

Flash a Kubernetes node SD card image.

OPTIONS:
  -h    Show this message
  -n    Set hostname for this SD image (master will generate a master image, otherwise nodes)
EOF
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

while getopts ":n:" opt; do
  case $opt in
    n)  IMAGE_HOSTNAME=$OPTARG ;;
  esac
done

if [[ -z "${IMAGE_HOSTNAME// }" ]]; then
  echo "Hostname not set"
  usage
fi

pushd build > /dev/null

if [ ! -f raspbian_lite_latest.zip ]; then
  curl -L https://downloads.raspberrypi.org/raspbian_lite_latest -o raspbian_lite_latest.zip
fi

if [ ! -f *-raspbian-*-lite.img ]; then
  unzip raspbian_lite_latest.zip
fi

image=`ls *-raspbian-*-lite.img`
echo "Using $image"
df -h

read -p "Which device should the image be written to: "
device="${REPLY}"
[[ ${device} != /dev/* ]] && device="/dev/${device}"
[[ ${device} == /dev/mmcblk*p* ]] && device=`echo ${device} | sed -r 's/\/dev\/mmcblk([[:digit:]]+)p([[:digit:]]+)/\/dev\/mmcblk\1/'`
[[ ${device} == /dev/sd* ]] && device=`echo ${device} | sed -r 's/\/dev\/sd([[:alpha:]]+)([[:digit:]]+)/\/dev\/sd\1/'`

echo "Writing image to $device with hostname $IMAGE_HOSTNAME"
read -rp "Is this correct? " conf
case $conf in
  [Yy]* ) ;;
  [Nn]* ) exit;;
  * ) echo "Please answer yes or no."
    exit 1;;
esac

if hdparm -r "${device}" | grep -q off; then
    writable=1
else
    echo "${device} is read only, aborting"
fi

for partition in $(df | grep "${device}" | cut -d " " -f1)
do
  sudo umount $partition
done

image_size=`ls -lh $image | cut -d " " -f 5`

echo "Flashing $image_size..."
sudo dd status=progress bs=4M if=$image of=$device

popd > /dev/null
exit 0