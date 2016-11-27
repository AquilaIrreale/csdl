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
  ; TODO: remove ret
  ret
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
  sub  esp,20
  
%define mmap_adj.a (ebp -  4)
%define mmap_adj.b (ebp -  8)
%define mmap_adj.lo mmap_adj.a
%define mmap_adj.hi mmap_adj.b
%define mmap_adj.s (ebp - 12)
%define mmap_adj.n (ebp - 16)
%define mmap_adj.c (ebp - 20)
  
  push ebx
  push edi
  push esi
  
  cld

  mov eax,[mmap]            ; Load size
  test eax,eax
  jz .return                ; The first entry has zero size, do nothing
  
  ; TODO: test if the second one is the terminator
  
  mov [mmap_adj.s],eax      ; Store size
  mov dword [mmap_adj.n],0  ; Init elements count
  
  mov edi,(mmap + 4)        ; Load starting destination
  
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
  
  inc dword [mmap_adj.n]
  cmp dword [edi + MMAP_SIZE],0 ; Loop until the first empty entry
  jne .outer_loop

  ; Clip or joint overlapping and adjacent areas
  mov eax,[mmap_adj.n]  ; Copy n in c
  mov [mmap_adj.c],eax  ;
  
  mov esi,(mmap + 4)    ; esi is the first entry
  mov edi,esi
  add edi,[mmap_adj.s]  ; edi is the second one
  add edi,4
  
.clip_loop:
  dec dword [mmap_adj.c]
  
  ; TODO: rewrite using cmp
  ; Compute esi.base + esi.length in edx:eax
  mov eax,[esi + MMAP_BASE_LO]
  mov edx,[esi + MMAP_BASE_HI]
  
  add eax,[esi + MMAP_LEN_LO]
  adc edx,[esi + MMAP_LEN_HI]
  
  ; If (esi.base + esi.length) < edi.base there's nothing to do
  cmp edx,[edi + MMAP_BASE_HI]
  jb .clip_next
  
  cmp eax,[edi * MMAP_BASE_LO]
  jb .clip_next

  ; Choose to join or clip, and which way
  mov eax,[mmap_adj.s]  ; First, find out how many dwords wide the type
  sub eax,16            ; and extra fields are, by loading the structure's
  shr eax,2             ; size in bytes, then subtracting 16 (the width of
  mov ecx,eax           ; the first two elements in bytes), then dividing
                        ; by 4 to convert to dwords
  push esi
  push edi
  
  add esi,MMAP_TYPE
  add edi,MMAP_TYPE
  
  repe cmpsd  ; Compare the entries from the type on
  
  pop edi
  pop esi
  
  ja .clip_second   ; The entry with the lowest type number gets clipped
  jb .clip_first    ;
  
  ; If all type fields were equal, join the entries
  ; Find the rightmost limit (likely the second)
  ; Compute the first limit
  mov eax,[esi + MMAP_BASE_LO]
  mov edx,[esi + MMAP_BASE_HI]
  
  add eax,[esi + MMAP_LEN_LO]
  adc edx,[esi + MMAP_LEN_HI]
  
  mov [mmap_adj.lo],eax
  mov [mmap_adj.hi],edx

  ; Compute the second limit
  mov eax,[edi + MMAP_BASE_LO]
  mov edx,[edi + MMAP_BASE_HI]
  
  add eax,[edi + MMAP_LEN_LO]
  adc edx,[edi + MMAP_LEN_HI]
  
  ; Compare
  cmp edx,[mmap_adj.hi]
  ja  .edit_entry
  
  cmp eax,[mmap_adj.lo]
  jae .edit_entry
  
  ; If the highest value is in memory, load it back to edx:eax
  mov eax,[mmap_adj.lo]
  mov eax,[mmap_adj.hi]

  ; Now recompute the correct length and store it to the first entry  
.edit_entry:
  sub eax,[esi + MMAP_BASE_LO]
  sbb edx,[esi + MMAP_BASE_HI]
  
  mov [esi + MMAP_LEN_LO],eax
  mov [esi + MMAP_LEN_HI],edx
  
  ; Then delete the second entry
  push esi
  push edi
  
  xchg esi,edi
  add esi,[mmap_adj.s]
  add edi,[mmap_adj.s]
  
  mov eax,[mmap_adj.c]
  mul dword [mmap_adj.s]
  mov ecx,eax
  
  rep movsb
  
  pop edi
  pop esi
  
  jmp .clip_next_noinc
  
  ; Clip the first entry
  .clip_first:
  ; TODO
  
  ; Clip the second entry
  .clip_second:
  ; TODO

.clip_next:
  mov esi,edi               ; Increment both pointers
  add edi,[mmap_adj.s]      ;
  add edi,4                 ;

.clip_next_noinc:
  mov eax,[edi + MMAP_SIZE] ; Loop until the second pointer
  test eax,eax              ; points to the terminator entry
  jnz .clip_loop            ;

.return:
  pop esi
  pop edi
  pop edx

  add esp,20
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

;mmap:                       ; mmap has space for 32 wide (24 bytes)
;  times 32 * (24 + 4) db 0  ; entries and their associated sizes (4 bytes)
;  dd 0                      ; A zero-terminator

; Debug
mmap:
  dd 20
  dq 0x0F000000
  dq 0x01000000
  dd 3
  
  dd 20
  dq 0x00000000
  dq 0x00010000
  dd 1
  
  dd 20
  dq 0x00000FE0
  dq 0x00000100
  dd 1
  
  dd 0
  dq 0
  dq 0
  dd 0

.tmp:
  times 24 db 0             ; Swapping space for mmap_adj




