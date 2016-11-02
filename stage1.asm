%define MBR  0x7C00
%define FAT1 0x7E00
%define FAT2 0x9000
%define ROOT 0xA200
%define STG2 0xBE00

%define NAME   0x00
%define EXT    0x08
%define FLC    0x1A
%define FS     0x1C

%macro ERR 1
  add byte [errstring+12],$1
  jmp error
%endmacro

ORG 0x7C00
BITS 16

section .text
; Jump ;
  jmp stage1

; OS string ;
  times 0x0003-($-$$) db 0

  db "CIMA    "

; BPB ;
  times 0x000B-($-$$) db 0

  dw     0x0200 ; Bytes per sector
  db       0x01 ; Sectors per cluster
  dw     0x0001 ; Reserved sectors
  db       0x02 ; Number of FATs
  dw     0x00E0 ; Number of possible root entries
  dw     0x0B40 ; Number of sectors (<32MB)
  db       0xF0 ; Media descriptor
  dw     0x0009 ; Sectors per FAT
  dw     0x0012 ; Sectors per cylinder
  dw     0x0002 ; Number of heads
  dd 0x00000000 ; Hidden sectors
  dd 0x00000000 ; Number of sectors (>32MB)

; BPBE ;
  times 0x0024-($-$$) db 0

  db       0x00     ; Drive number
  db       0x01     ; Reserved (?)
  db       0x29     ; Extended boot sig.
  dd 0x2E561EF6     ; Volume serial number
  db "CSD LOADER "  ; Volume label
  db "FAT12   "     ; File system type

; Text ;
  times 0x003E-($-$$) db 0

stage1:
  cli
  ; Set up code segment
  jmp 0x00:seg_setup

seg_setup:
  ; Set up data segments
  xor word ax,ax
  mov word ds,ax
  mov word ss,ax
  mov word es,ax
  mov word fs,ax
  mov word gs,ax
  
  ; Set video mode
  ;xor byte ah,ah ; ah is already zeroed
  mov byte al,0x02
  int 0x10

  ; Reset disk drives
  xor byte ah,ah
  xor byte dl,dl ; Drive 0x00 = A:
  int 0x13

  ; Read blocks from 1 through 32, thrice (FATs and root directory)
  mov word si,0x03

read_fat:
  mov byte ah,0x02
  mov byte al,0x20   ; Read 32 sectors
  xor byte ch,ch     ; Start at cylinder 0
  mov byte cl,0x02   ; Start at sector 2 (sectors start from 1)
  xor byte dh,dh     ; Start at head 0
  xor byte dl,dl     ; Select drive A:
  mov word bx,0x7E00 ; Write right past MBR
  int 0x13
  dec word si
  jnz read_fat

  ; Check for errors etc (CF)
  jc error0

  ; Search root directory for BOOT.BIN
  xor word ax,ax             ; ax is our counter (cx is needed elsewhere)
  mov word bx,ROOT+NAME      ; bx points current name entry

nameloop:
  cmp byte [bx],0xE5
  je nameloop_next           ; Empty entry

  cmp byte [bx],0x00
  je error1                  ; No more files

  mov word si,bx             ; Load current name
  mov word di,stage2filename ; Load reference string

  ; Test for filename match
  mov word cx,0x0B           ; Filename is 11 bytes long
  repe cmpsb                 ; Compare strings
  jcxz loadstage2            ; If strings are qual jump to loader
                             ; Else continue
nameloop_next:
  inc word ax
  cmp word ax,0xE0           ; Root dir contains up to 224 (E0h) entries
  je error2
  add word bx,0x20           ; Entries are 32 bytes long
  jmp nameloop

loadstage2:
  ; bx contains boot.bin's file entry
  mov word ax,[FLC+bx]       ; Load first logical cluster
  mov word bx,STG2           ; Load destination pointer

stage2loop:
  ; Load cluster
  mov word si,ax             ; Store logical cluster for later use
  add word ax,0x1F           ; Convert toBA sector number
  mov byte dl,0x24
  div byte dl                ; DivideBA by 36
  mov byte ch,al             ; C =BA / 36
  movzx ax,ah                ; Load LBA mod 36 in ax
  mov byte dl,0x12
  div byte dl                ; Divide ax by 18
  mov byte dh,al             ; H = BA mod 36) / 18
  mov byte cl,ah
  inc byte cl                ; S = BA mod 36) mod 18 +1
  xor byte dl,dl             ; Select drive A:
  mov byte al,0x01           ; Read one sector
  mov byte ah,0x02
  int 0x13                   ; Call BIOS

  ; Advance destination pointer
  add word bx,0x200

  ; Load FAT entry
  mov word ax,si        ; Retrieve logical cluster C)
  mov word cx,3
  mul word cx           ; Multiply by 3
  shr word ax,1         ; Divide by 2
  xchg ax,bp            ; Now bp holds the FAT entry offset
  mov word ax,[FAT1+bp] ; Load FAT entry

  jc odd                ; CF, set by shrw, indicates if the entry was odd

  ; LC even
  and word ax,0x0FFF
  jmp value_check

odd:
  ; LC odd
  shr word ax,0x0004
  
value_check:
  ; Check FAT entry value
  test word ax,ax
  jz error3
  cmp word ax,0xFF0
  jl stage2loop
  cmp word ax,0xFF8
  jl error4

  jmp STG2

; DEBUG SECTION ;

error0:
  ERR 0

error1:
  ERR 1

error2:
  ERR 2

error3:
  ERR 3

error4:
  ERR 4

error:
  ; Print error
  mov byte ah,0x13
  mov byte al,0x01
  mov byte bh,0x00
  mov byte bl,0x07
  mov word cx,13   ; String length
  mov byte dh,0x00
  mov byte dl,0x00
  mov word bp,errstring
  int 0x10

hang:
  hlt
  jmp hang

; END OF DEBUG SECTION ;

; Data ;
errstring:
  db "ERROR CODE #0"
stage2filename:
  db "BOOT    BIN" ; I.e. boot.bin

; Magic number ;
  times 0x01FE-($-$$) db 0

  dw 0xAA55


