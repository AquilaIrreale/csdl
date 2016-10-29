.equ LEN,16 # DEBUG
.equ KERNEL,0x100000 # Kernel code gets loaded at 1M

.section .data
### GDT ###

# Flags
.equ RW   ,0x02
.equ DC   ,0x04 # Direction/conforming bit
.equ EXEC ,0x08
.equ RING0,0x00
.equ RING1,0x20
.equ RING2,0x40
.equ RING3,0x60
.equ ACCESS_BASEMASK,0x90

.equ PAGE_GRAN,0x80
.equ SIZE_32  ,0x40

# Control panel
.equ BASE  ,0
.equ LIMIT ,0xFFFFF
.equ ACCESS,(ACCESS_BASEMASK | RING0 | RW)
.equ FLAGS ,(PAGE_GRAN | SIZE_32)

# Implementation
gdt_0:
  .ascii "FOOF"
  .skip 8
gdt_1:
  .word LIMIT & 0xFFFF        # Limit  0-15
  .word BASE  & 0xFFFF        # Base   0-15
  .byte (BASE >> 16) & 0xFF   # Base  16-23
  .byte ACCESS | EXEC         # Access
  .byte (LIMIT >> 16) | FLAGS # Limit 16-19 (low nibble) & flags (high nibble)
  .byte BASE >> 24            # Base  24-31
gdt_2:
  .word LIMIT & 0xFFFF        # Limit  0-15
  .word BASE  & 0xFFFF        # Base   0-15
  .byte (BASE >> 16) & 0xFF   # Base  16-23
  .byte ACCESS                # Access
  .byte (LIMIT >> 16) | FLAGS # Limit 16-19 (low nibble) & flags (high nibble)
  .byte BASE >> 24            # Base  24-31
gdt_end:

# Pointer structure
gdt_p:
  .word gdt_end - gdt_0 -1 # Size of GDT subtracted by 1
  .long gdt_0

### GDT END ###

# DEBUG:
str:
  .ascii "STAGE2... START!"
str2:
  .ascii "ALL RIGHT!"

.section .text
.code16
.global start
start:
  # Print a success message
  movb $0x13,%ah
  movb $0x01,%al
  movb $0x00,%bh
  movb $0x07,%bl
  movw $LEN ,%cx # String length
  movb $0x00,%dh
  movb $0x00,%dl
  movw $str ,%bp
  int  $0x10

  # Prepare to enter protected mode
  cli             # Clear interrupts
  
  inb  $0x70,%al  # Disable NMI
  orb  $0x80,%al  #
  outb %al,$0x70  #

  inb  $ 0x92,%al # Enable A20 line (fast A20 method)
  orb  $ 0x02,%al #
  andb $~0x01,%al #
  outb %al,$0x92  #

  lgdt gdt_0      # Load GDT

  # Enable protected mode
  movl %cr0,%eax
  orl $0x01,%eax
  movl %eax,%cr0

  # Clear prefetch instruction queue
  jmp .Lpiq_clear
  nop
  nop
  nop
  nop
  nop
  nop
.Lpiq_clear:

.code32 # Switch to 32 bit x86

  # Load segment selectors
  movw $0x10,%ax
  movw %ax,%ds
  movw %ax,%es
  movw %ax,%fs
  movw %ax,%gs
  movw %ax,%ss

  ljmp $0x08,$.Lload_cs
.Lload_cs:

  # Print a success message
  #movb $0x13,%ah
  #movb $0x01,%al
  #movb $0x00,%bh
  #movb $0x07,%bl
  #movw $10  ,%cx # String length
  #movb $0x01,%dh
  #movb $0x00,%dl
  #movw $str2,%bp
  #int  $0x10

.Lhang:
  hlt
  jmp .Lhang


