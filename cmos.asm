section .text
bits 32

nmi_disable:
  mov byte al,0x80
  mov byte [nmi_bit],al
  out byte 0x70,al
  ret
  
nmi_enable:
  xor byte al,al
  mov byte [nmi_bit],al
  out byte 0x70,al
  ret

%define cmos_reg esp+4
cmos_read:
  mov byte al,[cmos_reg]
  mov byte ah,[nmi_bit]
  or  byte al,ah
  out byte 0x70,al
  in  byte al,0x71
  movzx eax,al
  ret
  
section .data
nmi_bit:
  db 0


