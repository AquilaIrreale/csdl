#!/bin/sh

LOOP=$(cat loop)

if [ $1 = -d ]; then
    DEBUG='-S -s'
else
    DEBUG=''
fi

sudo qemu-system-i386 -fda $LOOP $DEBUG


