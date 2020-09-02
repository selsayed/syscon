#!/bin/bash
###############################################################################
# Partition Details
###############################################################################

# EFI Partition
EFIPARTNUM="1"
EFIPARTSIZE="1G"

# Boot Drive Info
BOOTPARTNUM="2"
BOOTPARTSIZE="4G"

# Swap Drive Info
SWAPPARTNUM="3"
SWAPPARTSIZE="8G"

# Root Drive Info (Occupies the rest of the space)
ROOTPARTNUM="4"

###############################################################################
# Configuring Script Conditions
###############################################################################
# Print All Commands
set -x
# Do Not Expand Variables
set -v

# Exit on Any Command Failing
set -e
set -o pipefail

###############################################################################
# Parse Input Drive Name
###############################################################################
if [ "$#" -ne 3 ]; then
  echo "Script requires 3 argument."
  echo "1. Target Drive"
  echo "2. System Name"
  echo "3. Empty Directory to Temporarily Mount"
  exit 1
fi

# $1 -> The Target Installation Drive
TARGET=$1
# Target System Name
NAME=$2
# Temporary Directory To Mount Partitions if Needed
DISKMOUNT=$3

###############################################################################
# Fixing Variable Names
###############################################################################
ROOTPART=$TARGET
ROOTPART+="p"
ROOTPART+=$ROOTPARTNUM
BOOTPART=$TARGET
BOOTPART+="p"
BOOTPART+=$BOOTPARTNUM
EFIPART=$TARGET
EFIPART+="p"
EFIPART+=$EFIPARTNUM
SWAPPART=$TARGET
SWAPPART+="p"
SWAPPART+=$SWAPPARTNUM



###############################################################################
# Create Partitions
###############################################################################
# Warn that this will erase everything on the $TARGET
sgdisk -p  $TARGET
echo "THIS WILL ERASE ALL DATA ON $TARGET."
echo "Do you wish to continue? "
select yn in "Yes" "No"; do
  case $yn in
    Yes ) break;;
    No ) exit;;
  esac
done

# Create a GPT Partition Table on the Hard Drive
sgdisk -o $TARGET
# Create an EFI partition
sgdisk -n 1:2048:$EFIPARTSIZE -t 1:ef00 -g $TARGET
# Create Boot Partition
sgdisk -n 2:+0G:$BOOTPARTSIZE -t 2:8300 -g $TARGET
# Create Swap Partition
sgdisk -n 3:+0G:$SWAPPARTSIZE -t 3:8200 -g $TARGET
# Create Root Partition
sgdisk -n 4:+0G -t 4:8300 -g $TARGET

# Verify that the stage is correct
sgdisk -p $TARGET
echo "Is this okay? "
select yn in "Yes" "No"; do
  case $yn in
    Yes ) break;;
    No ) exit;;
  esac
done

echo "Using $ROOTPART as main installation device."
echo "Using $BOOTPART as main boot device."
echo "Using $EFIPART as main efi device."
echo "Is this okay? "
select yn in "Yes" "No"; do
  case $yn in
    Yes ) break;;
    No ) exit;;
  esac
done

# Create Filesystems on Local Volume
partprobe
mkfs.vfat $EFIPART
mkfs.ext4 $BOOTPART
mkfs.btrfs -f $ROOTPART
mkdir -p $DISKMOUNT
mount -t btrfs $ROOTPART $DISKMOUNT
btrfs subvolume create $DISKMOUNT/root
umount $DISKMOUNT


# Create Correct Mount Points
mkdir -p $DISKMOUNT
mount -t btrfs -o subvol=root  $ROOTPART $DISKMOUNT
mkdir -p $DISKMOUNT/boot
mount -t ext4 $BOOTPART $DISKMOUNT/boot
mkdir -p $DISKMOUNT/boot/efi
mount -t vfat $EFIPART $DISKMOUNT/boot/efi

# Swap
export ORIGINAL_SWAP=$(swapon --show=NAME --raw --noheadings)
mkswap $SWAPPART
swapon $SWAPPART

# Installing System
pacstrap $DISKMOUNT base

# generate genfstab
echo "Generating fstab..."
genfstab -U $DISKMOUNT >> $DISKMOUNT/etc/fstab
# Select Time Zone
echo "Selecting Time Zones...."
arch-chroot $DISKMOUNT ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# hwclock
echo "Setting clock to hardware clock..."
arch-chroot $DISKMOUNT hwclock --systohc

echo "Enable Locale...."
echo 'en_GB.UTF-8 UTF-8' >> $DISKMOUNT/etc/locale.gen

echo "Generating Locale.."
arch-chroot $DISKMOUNT locale-gen

echo "Setting Locale"
echo 'LANG=en_GB.UTF-8' >> $DISKMOUNT/etc/locale.conf

echo "Setting Hostname"
echo "$NAME" >> $DISKMOUNT/etc/hostname

echo "Install btrfs-progs"
arch-chroot $DISKMOUNT pacman -S btrfs-progs

echo "Generating initramfs...."
arch-chroot $DISKMOUNT pacman -S linux mkinitcpio --noconfirm
arch-chroot $DISKMOUNT mkinitcpio -p linux

echo "Installing bootloader"
arch-chroot $DISKMOUNT pacman -S grub efibootmgr  --noconfirm
arch-chroot $DISKMOUNT grub-install --target=x86_64-efi \
                                    --efi-directory \
                                    /boot/efi \
                                    --bootloader-id=$NAME
arch-chroot $DISKMOUNT grub-mkconfig -o /boot/grub/grub.cfg

echo "Installing basic utilities..."
arch-chroot $DISKMOUNT pacman -S vim netctl wpa_supplicant dialog dhclient sudo --noconfirm
arch-chroot $DISKMOUNT pacman -S git gnupg zsh --noconfirm
arch-chroot $DISKMOUNT pacman -S xorg sddm xf86-video-intel xf86-video-amdgpu firefox --noconfirm

echo "Set Root Password"
arch-chroot $DISKMOUNT passwd

echo "Umount Everything"
umount -R $DISKMOUNT

# Reenable Original Swap
swapoff $SWAPPART
swapon $ORIGINAL_SWAP
