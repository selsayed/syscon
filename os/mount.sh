#!/bin/bash
###############################################################################
# Partition Details
###############################################################################

# EFI Partition
EFIPARTNUM="1"
# Boot Drive Info
BOOTPARTNUM="2"
# Swap Drive Info
SWAPPARTNUM="3"
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
if [ "$#" -ne 2 ]; then
  echo "Script requires 2 argument."
  echo "1. Target Drive"
  echo "2. Empty Directory to Temporarily Mount"
  exit 1
fi

# $1 -> The Target Installation Drive
TARGET=$1
# Temporary Directory To Mount Partitions if Needed
DISKMOUNT=$2

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

# Create Correct Mount Points
mount -t btrfs -o subvol=root  $ROOTPART $DISKMOUNT
mount -t ext4 $BOOTPART $DISKMOUNT/boot
mount -t vfat $EFIPART $DISKMOUNT/boot/efi
