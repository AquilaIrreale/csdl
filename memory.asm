%define MMAP_SIZE -4
%define MMAP_BASE  0
%define MMAP_LEN   8
%define MMAP_TYPE 16
%define MMAP_ETYP 20

section .text
bits 16

; memprobe: detect memory layout
memprobe:
  push bp
  mov  bp,sp

  push bx
  push di
  
  ; Prepare bios parameters
  mov di,mmap+4       ; Destination address
  xor ebx,ebx         ; Entry index
  mov edx,0x534D4150  ; Magic number
  mov eax,0xE820      ; Function number
  mov ecx,24          ; Entry width
  
.loop_start:
  int 0x15
  
  jc .loop_end    ; If CF is set, the entry is not valid
                  ; and there are no more to store
  
  mov edx,0x534D4150  ; Some BIOSes trash edx
  cmp eax,edx
  jne .loop_end   ; If eax != edx function 0xE820 is not supported
  
  test cl,cl
  jz .skip        ; If the entry has size zero, don't store it
  
  mov [di + MMAP_SIZE],cl ; Store entry size
  
  xor ch,ch ; Advance the pointer
  add di,cx ;
  add di,4  ;

.skip:
  mov eax,0xE820  ; Restore BIOS parameters
  mov ecx,24      ;
  
  test ebx,ebx
  jnz .loop_start ; If ebx != 0, there may still be entries to store
  
.loop_end:
  pop di
  pop bx

  pop bp
  ret

bits 32

; memadj: parse, adjust and simplify the memory map
memadj:
  push ebp
  mov  ebp,esp



  pop ebp
  ret  

section .data
align 8

mmap:                       ; mmap has space for 16 wide (24 bytes)
  times 16 * (24 + 4) db 0  ; entries and their associated sizes (4 bytes)




