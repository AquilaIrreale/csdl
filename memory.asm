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

; Function (cdecl)
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

; Function (cdecl)
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

  mov eax,[mmap]            ; Load first entry size
  test eax,eax
  jz .return                ; If first entry has size zero, do nothing
  
  mov eax,[mmap + eax + 4]  ; Load second entry size
  test eax,eax
  jz .return                ; If second entry has zero size, again do nothing
  
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
  add esi,[mmap_adj.s]  ; Advance to the next entry
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
  mov edi, mmap.tmp
  mov ecx,[mmap_adj.s]
  rep movsb
  
  mov esi,[mmap_adj.b]
  mov edi,[mmap_adj.a]
  mov ecx,[mmap_adj.s]
  rep movsb
  
  mov esi, mmap.tmp
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

  ; Clip or join overlapping and adjacent areas
  mov eax,[mmap_adj.n]  ; Copy n in c
  mov [mmap_adj.c],eax  ;
  
  mov esi,(mmap + 4)    ; esi is the first entry
  mov edi,esi
  add edi,[mmap_adj.s]  ; edi is the second one
  add edi,4
  
.clip_loop:
  dec dword [mmap_adj.c]
  
  ; Compute esi.base + esi.length in edx:eax
  mov eax,[esi + MMAP_BASE_LO]
  mov edx,[esi + MMAP_BASE_HI]
  
  add eax,[esi + MMAP_LEN_LO]
  adc edx,[esi + MMAP_LEN_HI]
  
  ; If (esi.base + esi.length) < edi.base there's nothing to do
  cmp edx,[edi + MMAP_BASE_HI]
  jb .clip_next
  ja .choose
  
  ; If msdwords are equal, check lsdwords
  cmp eax,[edi + MMAP_BASE_LO]
  jb .clip_next

  ; Choose to join or clip, and which way
.choose:
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
  call mmap_rmost

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

; Function (nonstd)
; mmap_rmost
; Find the rightmost limit
; For internal use only
;
; Parameters:
;   esi = first entry
;   edi = second entry
;
; Return:
;   eax = rightmost limit (lsdword)
;   edx = rightmost limit (msdword)
;   CF  = 0 for first entry, 1 for second entry
mmap_rmost:
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
  ja  .second
  jb  .first
  
  cmp eax,[mmap_adj.lo]
  jae .second
  
  ; If the highest value is the first, load it back to edx:eax
  ; then clear the CF
.first:
  mov eax,[mmap_adj.lo]
  mov edx,[mmap_adj.hi]
  clc
  ret

  ; If the highest value is already in edx:eax, just set the CF
.second:
  stc
  ret

; Function (nonstd)
; mmap_grow
; Grow the mmap
; Arguments:
;   edi = reference entry (new space is made after this entry)
;   eax = entries after reference
; Return:
;   none
mmap_grow:
  push esi
  push edi

  mov edx,[edi + MMAP_SIZE] ; Load entry size
  add edx,4
  mul edx                   ; eax = n_entries * entry_size
  mov ecx,eax

  add eax,edi ; eax points to the last entry
  mov edx,[edi + MMAP_SIZE]
  add eax,edx
  dec eax
  mov esi,eax ; esi points to the last byte of the last entry
  
  lea eax,[eax + edx + 4]
  mov edi,eax ; edi points one whole entry after esi
  
  std
  rep movsb ; Move all entries past reference one step forward
  
  pop edi
  push edi
  
  lea edi,[edi + edx + 4]   ; edi points to the new entry
  mov [edi + MMAP_SIZE],edx ; Set new entry size
  
  mov ecx,edx
  xor eax,eax
  cld
  rep stosb ; Zero out new entry content
  
  pop edi
  pop esi
  
  ret

; Function (cdecl)
; mmap_print: print the memory map
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
align 4

;mmap:                       ; mmap has space for 32 wide (24 bytes)
;  times 32 * (24 + 4) db 0  ; entries and their associated sizes (4 bytes)
;  dd 0                      ; A zero-terminator

; Debug
mmap:
  dd 20
  dq 0x0000000000000000
  dq 0x0000000000010000
  dd 1

  dd 20
.entry1:
  dq 0x00000000000FFFFF
  dq 0x0000000000000002
  dd 1

  dd 20
  dq 0x000000000F000000
  dq 0x0000000001000000
  dd 3

  times (24 * 13) db 0
  dd 0

.tmp:
  align 4
  times 24 db 0             ; Swapping space for mmap_adj




