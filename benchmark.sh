#!/bin/bash
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
if [ "$#" -ne 1 ]; then
  echo "Script requires 2 argument."
  echo "1. Target Block Device"
  exit 1
fi

TARGET=$1

BS=1M
COUNT=20480

###############################################################################
# Benchmark
###############################################################################

echo "Running Test 1"
dd if=/dev/zero of=$TARGET/tempfile \
				bs=$BS count=$COUNT \
				conv=fdatasync,notrunc status=progress
echo "Clearing Caches"
echo 3 > /proc/sys/vm/drop_caches

echo "Running Test 2"
dd if=$TARGET/tempfile of=/dev/null \
				bs=$BS count=$COUNT \
				status=progress
dd if=$TARGET/tempfile of=/dev/null \
				bs=$BS count=$COUNT \
				status=progress
dd if=$TARGET/tempfile of=/dev/null \
				bs=$BS count=$COUNT \
				status=progress
dd if=$TARGET/tempfile of=/dev/null \
				bs=$BS count=$COUNT \
				status=progress

