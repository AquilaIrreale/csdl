all: mbr.img boot.bin

mbr.img: stage1.o mbr.ld
	i686-elf-ld -T mbr.ld -o mbr.img stage1.o

stage1.o: stage1.s
	i686-elf-as -o stage1.o stage1.s

boot.bin: stage2.o boot.ld
	i686-elf-ld -T boot.ld -o boot.bin stage2.o

stage2.o: stage2.s
	i686-elf-as -o stage2.o stage2.s

dump: mbr.dump boot.dump

mbr.dump: mbr.img
	objdump -D -b binary -mi386 -Maddr16,data16 --adjust-vma=0x7C00 mbr.img > mbr.dump

boot.dump: boot.bin
	objdump -D -b binary -mi386 -Maddr16,data16 --adjust-vma=0xBE00 boot.bin > boot.dump


