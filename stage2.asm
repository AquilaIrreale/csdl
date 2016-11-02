%define LEN 16 ; DEBUG
%define KERN 0x100000 ; Kernel code gets loaded at 1M

; GDT flags
%define RW    0x02
%define DC    0x04 ; Direction/conforming bit
%define EXEC  0x08
%define RING0 0x00
%define RING1 0x20
%define RING2 0x40
%define RING3 0x60
%define ACCESS_BASEMASK 0x90

%define PAGE_GRAN 0x80
%define SIZE_32   0x40

; GDT config
%define BASE   0
%define LIMIT  0xFFFFF
%define ACCESS (ACCESS_BASEMASK | RING0 | RW)
%define FLAGS  (PAGE_GRAN | SIZE_32)

ORG 0xBE00
BITS 16

section .text
  ; Print a success message
  mov byte ah,0x13
  mov byte al,0x01
  mov byte bh,0x00
  mov byte bl,0x07
  mov word cx,LEN  ; String length
  mov byte dh,0x00
  mov byte dl,0x00
  mov word bp,str1
  int 0x10

  ; Prepare to enter protected mode
  cli               ; Clear interrupts
  
  in  byte al,0x70  ; Disable NMI
  or  byte al,0x80  ;
  out byte 0x70,al  ;

  in  byte al,0x92  ; Enable A20 line (fast A20)
  or  byte al,0x02  ;
  and byte al,~0x01 ;
  out byte 0x92,al  ;

  lgdt [gdt_p]      ; Load GDT

  ; Enable protected mode
  mov dword eax,cr0
  or  dword eax,0x01
  mov dword cr0,eax

  ; Clear prefetch instruction queue and load 32 bit code segment
  jmp 0x08:load_segments

BITS 32

load_segments:
  ; Load segment selectors
  mov word ax,0x10
  mov word ds,ax
  mov word es,ax
  mov word fs,ax
  mov word gs,ax
  mov word ss,ax

  ; Print a success message
  ;mov byte ah,0x13
  ;mov byte al,0x01
  ;mov byte bh,0x00
  ;mov byte bl,0x07
  ;mov word cx,10   # String length
  ;mov byte dh,0x01
  ;mov byte dl,0x00
  ;mov word bp,str2
  ;int 0x10

hang:
  hlt
  jmp hang

section .data align=4

; GDT
gdt_0:
  ;db "FOOF"
  times 8 db 0
gdt_1:
  dw LIMIT & 0xFFFF        ; Limit  0-15
  dw BASE  & 0xFFFF        ; Base   0-15
  db (BASE >> 16) & 0xFF   ; Base  16-23
  db ACCESS | EXEC         ; Access
  db (LIMIT >> 16) | FLAGS ; Limit 16-19 (low nibble) & flags (high nibble)
  db BASE >> 24            ; Base  24-31
gdt_2:
  dw LIMIT & 0xFFFF        ; Limit  0-15
  dw BASE  & 0xFFFF        ; Base   0-15
  db (BASE >> 16) & 0xFF   ; Base  16-23
  db ACCESS                ; Access
  db (LIMIT >> 16) | FLAGS ; Limit 16-19 (low nibble) & flags (high nibble)
  db BASE >> 24            ; Base  24-31
gdt_end:

; GDT pointer
gdt_p:
  dw gdt_end - gdt_0 -1 ; Size of GDT subtracted by 1
  dd gdt_0

; DEBUG
str1:
  db "STAGE2... START!"
str2:
  db "ALL RIGHT!"


