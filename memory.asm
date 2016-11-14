%define MMAP_SIZE  -4
%define MMAP_BASE   0
%define MMAP_LEN    8
%define MMAP_TYPE  16
%define MMAP_EXTRA 20

%define MMAP_BASE_HI (MMAP_BASE + 4)
%define MMAP_BASE_LO (MMAP_BASE)

%define MMAP_LEN_HI  (MMAP_LEN + 4)
%define MMAP_LEN_LO  (MMAP_LEN)

section .text
bits 16

; mmap_memprobe: detect memory layout
mmap_memprobe:
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

; mmap_adj: parse, adjust and simplify the memory map
; Assumes all entries are the same size
mmap_adj:
  push ebp
  mov  ebp,esp
  sub  esp,12
  
%define mmap_adj.a (ebp -  4)
%define mmap_adj.b (ebp -  8)
%define mmap_adj.s (ebp - 12)
  
  push ebx
  push edi
  push esi

  mov edx,[mmap]        ; Load size
  test edx,edx
  jz .return            ; The first entry has zero size, do nothing
  
  mov [mmap_adj.s],edx  ; Store size
  
  mov edi,(mmap + 4)    ; Load starting destination
  
  ; Sort by base address
.outer_loop:
  mov esi,edi     ; Load starting source
  mov ecx,-1      ; Load UINT_MAX in ecx and edx
  mov edx,-1      ;
  
.inner_loop:
  mov eax,[esi + MMAP_BASE_HI]  ; Load current entry base address
                                ; (higher half)
  cmp eax,edx
  ja .inner_next
  jb .save_cur
  
  mov eax,[esi + MMAP_BASE_LO]  ; Load current entry base address
                                ; (lower half)
  cmp eax,ecx
  jnb .inner_next

.save_cur:
  mov ecx,[esi + MMAP_BASE_LO] ; Else set the new minimum
  mov edx,[esi + MMAP_BASE_HI] ; Else set the new minimum
  mov ebx,esi                  ; and store a pointer to current entry
  
.inner_next:
  add esi,[mmap_adj.s] ; Advance to the next entry
  add esi,4             ;
  
  cmp dword [esi + MMAP_SIZE],0 ;  Loop until the first empty entry
  jne .inner_loop               ;
  
  cmp ebx,edi     ; If ebx == edi do nothing
  je .outer_next  ;

  ; Else swap [ebx] and [edi]
  push esi
  
  mov [mmap_adj.a],ebx
  mov [mmap_adj.b],edi
  
  mov esi,[mmap_adj.a]
  mov edi,mmap.tmp
  mov ecx,[mmap_adj.s]
  rep movsb
  
  mov esi,[mmap_adj.b]
  mov edi,[mmap_adj.a]
  mov ecx,[mmap_adj.s]
  rep movsb
  
  mov esi,mmap.tmp
  mov edi,[mmap_adj.b]
  mov ecx,[mmap_adj.s]
  rep movsb
  
  pop esi
  mov edi,[mmap_adj.b]

.outer_next:
  add edi,[mmap_adj.s]
  add edi,4
  
  cmp dword [edi + MMAP_SIZE],0 ; Loop until the first empty entry
  jne .outer_loop               ;

.return:
  pop esi
  pop edi
  pop edx

  add esp,12
  pop ebp
  ret

; print_mmap: print the memory map
mmap_print:
  push ebx
  mov ebx,(mmap + 4)
  
.loop_start:
  mov eax,[ebx + MMAP_SIZE]
  
  test eax,eax
  jz .return
  
  push eax

  push dword [ebx + MMAP_BASE_HI]
  push dword [ebx + MMAP_BASE_LO]
  push 8
  call putx
  add esp,12
  
  push ' '
  call putc
  add esp,4
  
  push dword [ebx + MMAP_LEN_HI]
  push dword [ebx + MMAP_LEN_LO]
  push 8
  call putx
  add esp,12
  
  push ' '
  call putc
  add esp,4
  
  push dword [ebx + MMAP_TYPE]
  push 4
  call putx
  add esp,8
  
  mov eax,[esp]
  cmp eax,20
  jbe .next
  
  push ' '
  call putc
  add esp,4
  
  push dword [ebx + MMAP_EXTRA]
  push 4
  call putx
  add esp,8
  
.next:
  push 0x0A
  call putc
  add esp,4
  
  pop eax
  lea ebx,[ebx + eax + 4]
  jmp .loop_start
  
.return:
  pop ebx
  ret

section .data
align 8

mmap:                       ; mmap has space for 16 wide (24 bytes)
  times 16 * (24 + 4) db 0  ; entries and their associated sizes (4 bytes)
  dd 0                      ; A zero-terminator

.tmp:
  times 24 db 0             ; Swapping space for mmap_adj




