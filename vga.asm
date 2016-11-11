section .data
align 4
vga:
.cr:
  db 0

.cc:
  db 0

%define VGA_BASE      0xB8000
%define VGA_NROWS     25
%define VGA_NCOLS     80
%define VGA_SIZE      (VGA_NROWS * VGA_NCOLS)
%define VGA_DEF_COL   0x07
%define VGA_IO_MISC_W 0x3C2
%define VGA_IO_MISC_R 0x3CC
%define VGA_IO_COMM   0x3D4
%define VGA_IO_DATA   0x3D5
%define VGA_COMM_CH   0x0E 
%define VGA_COMM_CL   0x0F
%define VGA_MISC_IOAS 0x01

section .text
; vga_init: vga init routine
vga_init:
  ; Init the CRT controller addersses
  mov dx,VGA_IO_MISC_R
  in  al,dx
  
  or  al,VGA_MISC_IOAS
  
  mov dx,VGA_IO_MISC_W
  out dx,al

  ret

; com_fb_p: compute framebuffer pointer
com_fb_p:
  ; Compute the offset
  mov al,VGA_NCOLS
  mul byte [vga.cr]
  mov dl,[vga.cc]
  xor dh,dh
  add ax,dx
  movzx eax,ax
  shl eax,1               ; Characters are two bytes wide
  
  ; Add the framebuffer base pointer
  add eax,VGA_BASE
  
  ; Return
  ret

; vga_scroll: scroll the screen if needed
vga_scroll:
  mov byte cl,[vga.cr]    ; Load current row
  movzx ecx,cl            ; Extend it
  sub ecx,VGA_NROWS       ; Subtract number of columns
  js .ret_0               ; If the result is negative, no need to scroll
  inc ecx                 ; Increase the result to get the number of rows
                          ; to scroll (just in case there's more than one)
  mov eax,VGA_NCOLS       ; Load number of columns
  mul ecx                 ; Compute NCOLS * rows_to_scroll
  shl eax,1               ; Characters are two bytes wide
  add eax,VGA_BASE        ; Compute first source index
  
  push edi
  push esi
  
  mov edi,VGA_BASE
  mov esi,eax
  
  ; Compute how many words to move and put it in ecx
  mov eax,VGA_NROWS       ; We have to shift NROWS rows
  sub eax,ecx             ; minus the rows to scroll
  mov edx,VGA_NCOLS
  mul edx                 ; Multiply by NCOLS
  mov edx,eax
  mov ecx,eax             ; Now edx and ecx hold the number of words to shift
  
  rep movsw               ; Shift the buffer by ecx words
  
  ; Compute how many words to wipe
  mov ecx,VGA_SIZE
  sub ecx,edx
  
  mov al,' '                ; Set filler byte to blank space
  mov ah,VGA_DEF_COL        ; Set filler color to light grey on black
  
  rep stosw
  
  mov byte [vga.cr],24

  pop esi
  pop edi
  
.ret_1:
  mov eax,1                 ; Return 1 (screen has been scrolled)
  ret

.ret_0:
  xor eax,eax
  ret

; upd_curs: update cursor position
upd_curs:
  ; Calculate cursor's linear position (dx = cr * NCOLS + cc)
  mov al,[vga.cr]
  mov dl,VGA_NCOLS
  mul dl
  movzx dx,[vga.cc]
  add ax,dx
  
  push eax

  ; Select destination register
  mov dx,VGA_IO_COMM
  mov al,VGA_COMM_CL
  out dx,al
  
  ; Send low byte
  mov dx,VGA_IO_DATA
  mov al,[esp]
  out dx,al
  
  ; Select destination register
  mov dx,VGA_IO_COMM
  mov al,VGA_COMM_CH
  out dx,al
  
  ; Send high byte
  mov dx,VGA_IO_DATA
  mov al,[esp+1]
  out dx,al
  
  add esp,4

  ret

; puts: write a string onscreen
puts:
  mov esi,[4 + esp]     ; Move argument #1 in edi

  call com_fb_p
  mov edi,eax           ; Load starting destination address in edi
  
.loop_start:
  mov dl,[esi]          ; Load a char
  test dl,dl
  jz .loop_end          ; If char is NUL, quit

  ; Handle special characters  
  cmp dl,0x0A           ; If char is LF, handle accordingly
  jne .not_LF
  mov byte [vga.cc],0
  inc byte [vga.cr]

  call vga_scroll

  call com_fb_p
  mov edi,eax           ; Recompute destination address

  jmp .loop_next
.not_LF:

  ; TODO: add other special characters

  ; We are handling a regular character, place it in the framebuffer
  mov dh,VGA_DEF_COL
  mov [edi],dx
  add edi,2             ; Characters in buffer are two bytes long

  inc byte [vga.cc]     ; Increase column

.loop_next:
  inc esi               ; Next character
  
  cmp byte [vga.cc],VGA_NCOLS
  jl .loop_start        ; If current column exceedes limit do a LF

  mov byte [vga.cc],0
  inc byte [vga.cr]

  call vga_scroll       ; Scroll the screen if needed

  test eax,eax
  jz .loop_start        ; If the screen has been scrolled
  
  call com_fb_p
  mov edi,eax           ; Recompute destination address

  jmp .loop_start
.loop_end:

  call upd_curs
  ret


