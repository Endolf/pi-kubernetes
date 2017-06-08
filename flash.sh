#!/usr/bin/env bash

set -eo pipefail

usage()
{
  cat << EOF
usage: $0 [options]

Flash a Kubernetes node SD card image.

OPTIONS:
  -h    Show this message
  -d    Device to flash the image to.
  -n    Set hostname for this SD image (master will generate a master image, otherwise nodes)
  -k    Sets the file that contains the RSA public key. This will also disable password access and enable ssh server
  -s    Sets the wireless SSID
  -p    Sets the wireless PSK
EOF
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

while getopts ":n:d:k:s:p:" opt; do
  case $opt in
    n) IMAGE_HOSTNAME=$OPTARG ;;
    d) device=$OPTARG ;;
    k) ssh_pub_key_file=$OPTARG ;;
    s) SSID=$OPTARG ;;
    p) PSK=$OPTARG ;;
  esac
done

if [[ -z "${IMAGE_HOSTNAME// }" ]]; then
  echo "Hostname not set"
  usage
fi

if [[ ! -z "${ssh_pub_key_file// }" ]]; then
    if [ ! -f $ssh_pub_key_file ]; then
        echo $ssh_pub_key_file "does not exist. Aborting"
        exit 1;
    fi
fi

if ( [[ ! -z "${SSID// }" ]] || [[ ! -z "${PSK// }" ]] ) && ( [[ -z "${SSID// }" ]] || [[ -z "${PSK// }" ]] ); then
    echo "Either both the SSID and PSK must be specified, or neither"
    exit 1;
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
  sudo umount $partition
done

image_size=`ls -lh $image | cut -d " " -f 5`

echo "Flashing $image_size..."
sudo dd status=progress bs=4M if=$image of=$device

udevadm settle

sudo hdparm -z $device

if [[ ${device} == /dev/mmcblk* ]]; then
  boot_partition="${device}p1"
  root_partition="${device}p2"
else
  boot_partition="${device}1"
  root_partition="${device}2"
fi

FS_TYPE=$(sudo blkid -o value -s TYPE "${boot_partition}" || echo vfat)
echo "Mounting $boot_partition"
sudo mount -t ${FS_TYPE} "${boot_partition}" boot
FS_TYPE=$(sudo blkid -o value -s TYPE "${root_partition}" || echo vfat)
echo "Mounting $root_partition"
sudo mount -t ${FS_TYPE} "${root_partition}" root

grep -q gpu_mem boot/config.txt &&
    sudo sed -ri 's/^gpu_mem=.*$/gpu_mem=16/' boot/config.txt || echo -e "\n# Set GPU memory\ngpu_mem=16" | sudo tee -a boot/config.txt

echo $IMAGE_HOSTNAME | sudo tee root/etc/hostname
sudo sed -ri 's/^127.0.1.1.*$/127.0.1.1\t'${IMAGE_HOSTNAME}'/' root/etc/hosts

if [[ ! -z "${ssh_pub_key_file// }" ]]; then
    if [ -f $ssh_pub_key_file ]; then
        echo "Setting up ssh server and keys"
        sudo sed -ri 's/^ChallengeResponseAuthentication .*$/ChallengeResponseAuthentication no/' root/etc/ssh/sshd_config
        sudo sed -ri 's/^#?PasswordAuthentication .*$/PasswordAuthentication no/' root/etc/ssh/sshd_config
        sudo sed -ri 's/^UsePAM .*$/UsePAM no/' root/etc/ssh/sshd_config
        sudo sed -ri 's/^PermitRootLogin .*$/PermitRootLogin no/' root/etc/ssh/sshd_config
        sudo mkdir -p root/home/pi/.ssh
        sudo cp $ssh_pub_key_file root/home/pi/.ssh/authorized_keys
        sudo chmod 600 root/home/pi/.ssh/authorized_keys
        sudo chown -R 1000:1000 root/home/pi/.ssh/
        sudo touch boot/ssh
    else
        echo $ssh_pub_key_file "does not exist. Aborting"
        exit 1;
    fi
fi

if [ ! -z "${SSID}" ] && [ ! -z "${PSK}" ]; then
    echo "Setting SSID and PSK"
    ssid_line=( $(sudo grep -n 'ssid="${SSID}"' root/etc/wpa_supplicant/wpa_supplicant.conf || true | cut -d ":" -f1) )
    for (( idx=${#ssid_line[@]}-1 ; idx>=0 ; idx-- )) ; do
        echo "Found SSID on line ${ssid_line[idx]}, need to delete lines $((${ssid_line[idx]}-1)) thru $((${ssid_line[idx]}+2))"
        sudo sed -ie $((${ssid_line[idx]}-1))','$((${ssid_line[idx]}+2))'d' root/etc/wpa_supplicant/wpa_supplicant.conf
    done
    wpa_passphrase "${SSID}" "${PSK}" | grep -v "#psk" | sudo tee -a root/etc/wpa_supplicant/wpa_supplicant.conf
fi

grep -q cgroup_enable=cpuset boot/cmdline.txt || sudo sed -i '1s/^/cgroup_enable=cpuset /' boot/cmdline.txt

sudo cp -a ../install-kubernetes.sh root/usr/local/bin/
sudo cp -a ../setup-kubernetes-master.sh root/usr/local/bin/

sudo chown 0:50 root/usr/local/bin/*.sh

sync

for partition in $(df | grep "${device}" | cut -d " " -f1)
do
  echo "Unmounting $partition"
  sudo umount $partition
done

popd > /dev/null
echo "Done"

exit 0