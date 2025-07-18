#!/bin/bash

# *sigh*, some docker containers don't seem to have sbin in their PATH
export PATH=$PATH:/usr/sbin

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
BUILD_DIR="${SCRIPT_DIR}/work/root/"

# cleanup any previous build attempts
sudo umount -fl "${BUILD_DIR}" || true
sudo losetup -D /dev/loop0 || true
sudo rm -rf "${BUILD_DIR}" || true
sudo mkdir -p "${BUILD_DIR}"

# download a modern RaspiOS build
if [ ! -f raspios.img.xz ]
then
	wget -O raspios.img.xz "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2024-03-15/2024-03-15-raspios-bookworm-arm64-lite.img.xz"
	echo "58a3ec57402c86332e67789a6b8f149aeeb4e7bb0a16c9388a66ea6e07012e45 raspios.img.xz" | sha256sum --check --status
	if [ $? -ne 0 ]
	then
	    echo "downloaded raspios does not match checksum";
	    exit 1;
	fi
fi

rm -f raspios.img
xz -kd raspios.img.xz

# Repartition image
export LIBGUESTFS_BACKEND_SETTINGS=force_tcg
truncate -r raspios.img raspikiosk.img
truncate -s +1.5G raspikiosk.img

virt-resize --expand /dev/sda2 raspios.img raspikiosk.img
rm -f raspios.img

# Setup loop device for Raspberry Pi image (with partition scanning)
sudo losetup -P /dev/loop0 raspikiosk.img

# Mount partitions
sudo mount /dev/loop0p2 "${BUILD_DIR}"
sudo mount /dev/loop0p1 "${BUILD_DIR}/boot"

# Copy the (raspberry pi-specific) skeleton files
sudo rsync -a --no-owner --no-group "${SCRIPT_DIR}/raspberry_pi_skeleton/." "${BUILD_DIR}"
sudo rsync -a --no-owner --no-group "${SCRIPT_DIR}/kiosk_skeleton/." "${BUILD_DIR}/kiosk_skeleton"

# Make fstab read-only
sed -i 's/vfat    defaults/vfat    ro,defaults/g' "${BUILD_DIR}/etc/fstab"
sed -i 's/ext4    defaults/ext4    ro,defaults/g' "${BUILD_DIR}/etc/fstab"

# Include git repo version info
echo -n "AnotterKiosk Raspberry Pi version: " > "${BUILD_DIR}/version-info"
git describe --abbrev=4 --dirty --always --tags >> "${BUILD_DIR}/version-info"

# Mount system partitions (from the build host)
sudo mount proc -t proc -o nosuid,noexec,nodev "${BUILD_DIR}/proc/"
sudo mount sys -t sysfs -o nosuid,noexec,nodev,ro "${BUILD_DIR}/sys/"
sudo mount devpts -t devtmpfs -o mode=0755,nosuid "${BUILD_DIR}/dev/"

# Install everything.
sudo chroot "${BUILD_DIR}" /kiosk_skeleton/build.sh

sudo rm -r "${BUILD_DIR}/kiosk_skeleton"

cp "${BUILD_DIR}/version-info" version-info

sudo umount -fl "${BUILD_DIR}/proc"
sudo umount -fl "${BUILD_DIR}/sys"
sudo umount -fl "${BUILD_DIR}/dev"

sudo umount "${BUILD_DIR}/proc"
sudo umount "${BUILD_DIR}/sys"
sudo umount "${BUILD_DIR}/dev"

sudo umount "${BUILD_DIR}/boot"
sudo umount "${BUILD_DIR}"

sudo losetup -D /dev/loop0

tag=$(git describe --abbrev=4 --dirty --always --tags)
mv raspikiosk.img anotterkiosk-${tag}-arm64-raspberrypi.img
pigz -4 anotterkiosk-${tag}-arm64-raspberrypi.img