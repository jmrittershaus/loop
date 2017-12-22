[BITS 32]
 
[GLOBAL start]
start:
    mov esp, _sys_stack ; ##1
    jmp c_kernel_entry
 
 
; In den C-Kernel wechseln
c_kernel_entry:
    [EXTERN _c_kernel_main]
    call _c_kernel_main
    hlt
 
; Unser Stack
SECTION .bss
    resb 8192
_sys_stack: 
 
; Hier ist der Multibootheader. Wird gebraucht, um mit GRUB zu booten
SECTION .multiboot_data
ALIGN 4
multiboot_header:
    dd 0x1BADB002     ; Magic Nummer
    dd 0x0            ; Flags
    dd (-0x1BADB002)  ; Prüfsumme