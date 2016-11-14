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
; Assumes all entries are the same size
memadj:
  push ebp
  mov  ebp,esp
  sub  esp,8
  
  %define memadj_a (ebp - 4)
  %define memadj_b (ebp - 8)
  
  push ebx
  push edi
  push esi

  mov edx,[mmap]      ; Load size
  test edx,edx
  jz .return          ; The first entry has zero size, do nothing
  
  mov edi,(mmap + 4)  ; Load starting destination
  
  ; Sort by base address
.outer_loop:
  mov esi,edi         ; Load starting source
  mov ecx,-1          ; Load UINT_MAX in ecx
  
.inner_loop:
  mov eax,[esi + MMAP_BASE] ; Load current entry base address
  
  cmp eax,ecx     ; If current entry is not below current
  jnb .inner_next ; minimum, skip to the next one
  
  mov ecx,eax ; Else set the new minimum
  mov ebx,esi ; and store a pointer to current entry
  
.inner_next:
  add esi,edx ; Advance to the next entry
  add esi,4   ;
  
  cmp dword [esi + MMAP_SIZE],0 ;  Loop until the first empty entry
  jne .inner_loop               ;
  
  cmp ebx,edi     ; If ebx == edi do nothing
  je .outer_next  ;

  ; Else swap [ebx] and [edi]
  push esi
  
  mov [memadj_a],ebx
  mov [memadj_b],edi
  
  mov esi,[memadj_a]
  mov edi,mmap.tmp
  mov ecx,edx
  rep movsb
  
  mov esi,[memadj_b]
  mov edi,[memadj_a]
  mov ecx,edx
  rep movsb
  
  mov esi,mmap.tmp
  mov edi,[memadj_b]
  mov ecx,edx
  rep movsb
  
  pop esi
  mov edi,[memadj_b]

.outer_next:
  add edi,edx
  add edi,4
  
  cmp dword [edi + MMAP_SIZE],0 ; Loop until the first empty entry
  jne .outer_loop               ;

.return:
  pop esi
  pop edi
  pop edx

  add esp,8
  pop ebp
  ret  

section .data
align 8

mmap:                       ; mmap has space for 16 wide (24 bytes)
  times 16 * (24 + 4) db 0  ; entries and their associated sizes (4 bytes)
  dd 0                      ; A zero-terminator

.tmp:
  times 24 db 0             ; Swapping space for memadj




