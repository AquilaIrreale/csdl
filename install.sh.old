umount "$1" >/dev/null
dd if=mbr.img of="$1" bs=512 count=1
mkdir -p /mnt/fddtmp
mount "$1" /mnt/fddtmp
cp -v boot.bin /mnt/fddtmp
echo Syncing...
sync
umount /mnt/fddtmp
rmdir /mnt/fddtmp


