OUTPUT_FORMAT(binary)
ENTRY(start)

SECTIONS {
    .text 0x7C00 : {
        FILL(0)
        *(.jumpcode)
        . = 0x0003;
        *(.os)
        . = 0x000B;
        *(.bpb)
        . = 0x0024;
        *(.bpbe)
        . = 0x003E;
        *(.text)
        . = ALIGN(4);
        *(.data)
        . = 0x01FE;
        *(.magic)
    }
}


