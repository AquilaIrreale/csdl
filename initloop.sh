#!/bin/sh

LOOP=$(sudo losetup --find --show dummyfd.img)
echo "$LOOP" > loop

sudo chown root:wheel "$LOOP"
sudo chmod g+rw "$LOOP"


