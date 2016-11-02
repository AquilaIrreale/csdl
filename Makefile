all: mbr.img boot.bin

mbr.img: stage1.asm
	nasm -f bin -o mbr.img stage1.asm

boot.bin: stage2.asm
	nasm -f bin -o boot.bin stage2.asm

dump: mbr.dump boot.dump

mbr.dump: mbr.img
	objdump -D -b binary -mi386 -Maddr16,data16 --adjust-vma=0x7C00 mbr.img > mbr.dump

boot.dump: boot.bin
	objdump -D -b binary -mi386 -Maddr16,data16 --adjust-vma=0xBE00 boot.bin > boot.dump


