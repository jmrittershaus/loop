void _c_kernel_main(void)
{
   //Wir geben ein Zeichen aus.
   //Dazu schreiben wir an eine bestimmte Adresse im Speicher.
   unsigned short *video_buffer = (unsigned short *)0xB8000;
   *video_buffer = 'A' | 0x7;
   for(;;);
}