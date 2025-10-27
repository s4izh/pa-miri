ENTRY(_start)

SECTIONS
{
  . = 0x00001000;
  .text : { *(.text) }

  . = 0x00002000;
  .text._trap_handler : { *(.text._trap_handler) }

  . = 0x00003000;
  .data : { *(.data) *(.sdata) }
  .bss  : { *(.bss) *(.sbss) }
}
