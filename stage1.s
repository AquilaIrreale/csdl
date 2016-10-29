.equ MBR ,0x7C00
.equ FAT1,0x7E00
.equ FAT2,0x9000
.equ ROOT,0xA200
.equ STG2,0xBE00

.equ NAME,  0x00
.equ EXT ,  0x08
.equ FLC ,  0x1A
.equ FS  ,  0x1C

.section .magic
  .word 0xAA55

.section .os
  .ascii "CIMA    "

.section .bpb
  .word     0x0200 # Bytes per sector
  .byte       0x01 # Sectors per cluster
  .word     0x0001 # Reserved sectors
  .byte       0x02 # Number of FATs
  .word     0x00E0 # Number of possible root entries
  .word     0x0B40 # Number of sectors (<32MB)
  .byte       0xF0 # Media descriptor
  .word     0x0009 # Sectors per FAT
  .word     0x0012 # Sectors per cylinder
  .word     0x0002 # Number of heads
  .long 0x00000000 # Hidden sectors
  .long 0x00000000 # Number of sectors (>32MB)

.section .bpbe
  .byte       0x00     # Drive number
  .byte       0x01     # Reserved (?)
  .byte       0x29     # Extended boot sig.
  .long 0x2E561EF6     # Volume serial number
  .ascii "CSD LOADER " # Volume label
  .ascii "FAT12   "    # File system type

.section .data
errstring:
  .ascii "ERROR CODE #0"
stage2filename:
  .ascii "BOOT    BIN" # I.e. boot.bin

.macro ERR n
  addb $\n,errstring+12
  jmp .Lerror
.endm

.section .jumpcode
.code16
.global start
start:
  jmp stage1

.section .text
.code16
stage1:
  cli
  # Set up code segment
  jmp $0x00,$seg_setup

seg_setup:
  # Set up data segments
  xorw %ax,%ax
  movw %ax,%ds
  movw %ax,%ss
  movw %ax,%es
  movw %ax,%fs
  movw %ax,%gs
  
  # Set video mode
  #xorb %ah,%ah # %ah is already zeroed
  movb $0x02,%al
  int  $0x10

  # Reset disk drives
  xorb %ah,%ah
  xorb %dl,%dl # Drive 0x00 = A:
  int  $0x13

  # Read blocks from 1 through 32, thrice (FATs and root directory)
  movw $0x03,%si

.Lread_fat:
  movb $0x02,%ah
  movb $0x20,%al   # Read 32 sectors
  xorb %ch,%ch     # Start at cylinder 0
  movb $0x02,%cl   # Start at sector 2 (sectors start from 1)
  xorb %dh,%dh     # Start at head 0
  xorb %dl,%dl     # Select drive A:
  movw $0x7E00,%bx # Write right past MBR
  int  $0x13
  decw %si
  jnz  .Lread_fat

  # Check for errors etc (CF)
  jc .Lerror0

  # Search root directory for BOOT.BIN
  xorw %ax,%ax             # %ax is our counter (%cx is needed elsewhere)
  movw $(ROOT+NAME),%bx    # %dx points current name entry

.Lnameloop:
  cmpb $0xE5,(%bx)
  je   .Lnameloop_next     # Empty entry
  cmpb $0x00,(%bx)
  je   .Lerror1            # No more files

  movw %bx,%si             # Load current name
  movw $stage2filename,%di # Load reference string

  # Test for filename match
  movw $0x0B,%cx           # Filename is 11 bytes long
  repe cmpsb               # Compare strings
  jcxz .Lloadstage2        # If strings equal jump to loader
                           # Else next iteration
.Lnameloop_next:
  incw %ax
  cmpw $0xE0,%ax           # Root dir contains up to 224 (E0h) entries
  je   .Lerror2
  addw $0x20,%bx           # Entries are 32 bytes long
  jmp  .Lnameloop

.Lloadstage2:
  # %bx contains boot.bin's file entry
  movw FLC(%bx),%ax        # Load first logical cluster
  movw $STG2,%bx           # Load destination pointer

.Lstage2loop:
  # Load cluster
  movw %ax,%si             # Store logical cluster for later use
  addw $0x1F,%ax           # Convert to LBA sector number
  movb $0x24,%dl
  divb %dl                 # Divide LBA by 36
  movb %al,%ch             # C = LBA / 36
  movzbw %ah,%ax           # Load LBA mod 36 in %ax
  movb $0x12,%dl
  divb %dl                 # Divide %ax by 18
  movb %al,%dh             # H = (LBA mod 36) / 18
  movb %ah,%cl
  incb %cl                 # S = (LBA mod 36) mod 18 +1
  xorb %dl,%dl             # Select drive A:
  movb $0x01,%al           # Read one sector
  movb $0x02,%ah
  int  $0x13               # Call BIOS

  # Advance destination pointer
  addw $0x200,%bx

  # Load FAT entry
  movw %si,%ax             # Retrieve logical cluster (LC)
  movw $3,%cx
  mulw %cx                 # Multiply by 3
  shrw %ax                 # Divide by 2
  xchg %ax,%bp             # Now %bp holds the FAT entry offset
  movw FAT1(%bp),%ax       # Load FAT entry

  jc .Lodd                 # CF, set by shrw, indicates if the entry was odd

  # LC even
  andw $0x0FFF,%ax
  jmp  .Lvalue_check

.Lodd:
  # LC odd
  shrw $4,%ax
  
.Lvalue_check:
  # Check FAT entry value
  testw %ax,%ax
  jz .Lerror3
  cmpw $0xFF0,%ax
  jl .Lstage2loop
  cmpw $0xFF8,%ax
  jl .Lerror4

  jmp STG2

/* DEBUG SECTION */

.Lerror0:
  ERR 0

.Lerror1:
  ERR 1

.Lerror2:
  ERR 2

.Lerror3:
  ERR 3

.Lerror4:
  ERR 4

.Lerror:
  # Print error
  movb $0x13,%ah
  movb $0x01,%al
  movb $0x00,%bh
  movb $0x07,%bl
  movw $13  ,%cx # String length
  movb $0x00,%dh
  movb $0x00,%dl
  movw $errstring,%bp
  int $0x10

.Lhang:
  hlt
  jmp .Lhang

/* END OF DEBUG SECTION */


