#!/bin/sh

if [ $1 ] && [ $1 = -d ]; then
    if [ ! $2 ]; then
        echo "No device specified!"
        exit 1;
    fi

    DEV="$2"
else
    DEV=$(cat loop)
fi

sudo dd if=mbr.img of=$DEV bs=512 count=1 &&
DIR=$(mktemp -d) &&
sudo mount $DEV $DIR &&
sudo cp -v boot.bin $DIR &&
sudo umount $DIR &&
rmdir $DIR

