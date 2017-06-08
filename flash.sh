#!/usr/bin/env bash

set -eox pipefail

usage()
{
  cat << EOF
usage: $0 [options]

Flash a Kubernetes node SD card image.

OPTIONS:
  -h    Show this message
  -d    Device to flash the image to.
  -n    Set hostname for this SD image (master will generate a master image, otherwise nodes)
EOF
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

while getopts ":n:d:" opt; do
  case $opt in
    n) IMAGE_HOSTNAME=$OPTARG ;;
    d) device=$OPTARG ;;
  esac
done

if [[ -z "${IMAGE_HOSTNAME// }" ]]; then
  echo "Hostname not set"
  usage
fi

pushd build > /dev/null

mkdir -p boot
mkdir -p root

if [ ! -f raspbian_lite_latest.zip ]; then
  curl -L https://downloads.raspberrypi.org/raspbian_lite_latest -o raspbian_lite_latest.zip
fi

if [ ! -f *-raspbian-*-lite.img ]; then
  unzip raspbian_lite_latest.zip
fi

image=`ls *-raspbian-*-lite.img`
echo "Using $image"
df -h

if [[ -z "${device// }" ]]; then
    read -p "Which device should the image be written to: "
    device="${REPLY}"
fi

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
  echo "Unmounting $partition"
#  sudo umount $partition
done

image_size=`ls -lh $image | cut -d " " -f 5`

echo "Flashing $image_size..."
#sudo dd status=progress bs=4M if=$image of=$device

udevadm settle

#sudo hdparm -z $device

if [[ ${device} == /dev/mmcblk* ]]; then
  boot_partition="${device}p1"
  root_partition="${device}p2"
else
  boot_partition="${device}1"
  root_partition="${device}2"
fi

FS_TYPE=$(sudo blkid -o value -s TYPE "${boot_partition}" || echo vfat)
echo "Mounting $boot_partition"
#sudo mount -t ${FS_TYPE} "${boot_partition}" boot
FS_TYPE=$(sudo blkid -o value -s TYPE "${root_partition}" || echo vfat)
echo "Mounting $root_partition"
#sudo mount -t ${FS_TYPE} "${root_partition}" root

grep -q gpu_mem boot/config.txt &&
    sudo sed -ri 's/^gpu_mem=.*$/gpu_mem=16/' boot/config.txt || echo -e "\n# Set GPU memory\ngpu_mem=16" | sudo tee --append boot/config.txt

for partition in $(df | grep "${device}" | cut -d " " -f1)
do
  echo "Unmounting $partition"
  #sudo umount $partition
done

popd > /dev/null
echo "Done"

exit 0