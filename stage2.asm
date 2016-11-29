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

org 0xBE00
bits 16

section .text
  ; Prepare a temporary stack
  mov word sp,stack_top
  
  ; Detect memory
  call mmap_memprobe

  ; Prepare to enter protected mode
  cli               ; Clear interrupts
  
  in  byte al,0x92  ; Enable A20 line (fast A20)
  or  byte al,0x02  ;
  and byte al,~0x01 ;
  out byte 0x92,al  ;
  
  in  byte al,0x70  ; Disable NMI
  or  byte al,0x80  ;
  out byte 0x70,al  ;

  lgdt [gdt_p]      ; Load GDT

  ; Enable protected mode
  mov dword eax,cr0
  or  dword eax,0x01
  mov dword cr0,eax

  ; Clear prefetch queue and load 32 bit code segment
  jmp 0x08:load_segments

bits 32

load_segments:
  ; Load segment selectors
  mov word ax,0x10
  mov word ds,ax
  mov word es,ax
  mov word fs,ax
  mov word gs,ax
  mov word ss,ax
  
  ; Reset the stack
  mov dword esp,stack_top
  
  ; Init VGA
  call vga_init
  
  ; Print raw mmap
  push raw_mmap
  call puts
  add esp,4
  
  call mmap_print
  push dword 0x0A
  call putc
  add  esp,4
  
  ; Adjust memory map
  call mmap_adj
  
  ; Print adjusted mmap
  push adj_mmap
  call puts
  add esp,4
  
  call mmap_print
  push dword 0x0A
  call putc
  add  esp,4

.hang:
  hlt
  jmp .hang

%include "memory.asm"
%include "vga.asm"
%include "cmos.asm"
%include "fdc.asm"

section .data align=4
; GDT
align 8
gdt_0:
; The GDT pointer is packed inside the unused first entry
gdt_p:
  dw gdt_end - gdt_0 -1 ; Size of GDT subtracted by 1
  dd gdt_0
  align 8
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

raw_mmap:
  db "BIOS memory map:", 0x0A, 0

adj_mmap:
  db "Adjusted memory map:", 0x0A, 0

section .stack align=4
stack_bottom:
  times 1024 db 0
stack_top:


