#!/bin/sh

LOOP=$(cat loop)

sudo dd if=mbr.img of=$LOOP bs=512 count=1 &&
DIR=$(mktemp -d) &&
sudo mount $LOOP $DIR &&
sudo cp -v boot.bin $DIR &&
sudo umount $DIR &&
rmdir $DIR

