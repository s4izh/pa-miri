ENTRY(_start)

SECTIONS
{
  /* start execution at memory address 0 */
  . = 0x00000000;

  /* place the code section (.text) at the current address */
  .text :
  {
    *(.text)
  }
}
