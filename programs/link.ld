ENTRY(_start)

SECTIONS
{
  /* start execution at memory address 0 */
  . = 0x00000000;
  .text  : { *(.text) }

  /* Align to 2 pagesizes (half the memory for data, half the memory for program,
   * but not really because we have separate instruction and data memories). */
  . = ALIGN(0x2000);
  .data  : { *(.data) *(.sdata) }
  .bss   : { *(.bss) *(.sbss) }
}
