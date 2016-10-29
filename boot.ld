OUTPUT_FORMAT(binary)
ENTRY(start)

SECTIONS {
    .text 0xBE00 : {
        FILL(0)
        *(.text)
        . = ALIGN(4);
        *(.data)
    }
}


