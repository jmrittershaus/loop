; sector.asm
;
; writes a boot sector out to the floppy disk in the A: drive
;
; The input file is assumed to be a binary file with the relevant code
; at offset 7C00h relative to the beginning of the file.  This is because
; when the sector loader transfers control to the boot sector, it's at
; address 0:7C00h.  Rather than clutter up the boot loader source with
; a bunch of ugly offsets, we simply use an ORG 7C00h instead and let
; the linker insert a bunch of empty space which this program skips over.
;
; Style Note:
;   There aren't any hardwired numbers in this code.  That is to say,
;   equates and macros are used to render gibberish like this:
;     mov ax,4c00h
;     int 33
;
;   into somewhat self-documenting code like this:
;     DosInt DOS_TERMINATE, 0
;
;   This is done to make the code more readable, and comprehensible, and
;   to aid in maintenance by not littering mysterious constants throughout
;   the code.  Please be kind to animals (specifically your fellow
;   programmers) and use this practice in your own code.
;
;

STACKSIZE        = 200h         ; this is how much stack we'll allocate

SECTORSIZE       = 200h         ; size of the boot sector on a floppy

CMD_LINE_LEN     = 80h          ; offset of the command line length (one byte)
                                ; relative to the beginning of the PSP.

CMD_LINE         = 81h          ; the offset relative to the beginning of the
                                ; PSP that is the start of the command line
                                ; arguments.


DOS_OPEN_HANDLE  = 03dh         ; open file
 READ_ONLY_DENY_NONE = 020h     ;  file open mode
DOS_MOVE_HANDLE  = 042h         ; move file pointer
 WHENCE_BEGIN    = 0            ;  move pointer relative to beginning
 WHENCE_CURRENT  = 1            ;  move pointer relative to current location
 WHENCE_EOF      = 2            ;  move pointer relative to end of file
DOS_READ_HANDLE  = 03fh         ; read from an open file handle
DOS_CLOSE_HANDLE = 03eh         ; close an open file handle
DOS_WRITE_HANDLE = 040h         ; write to open file
DOS_TERMINATE    = 04ch         ; terminate and exit

DOS_INT         = 021h

; various named character constants
NUL     = 0
CR      = 13
LF      = 10
SPACE   = ' '

GenericInt macro function, subfunction
        ifb <subfunction>
                mov     ah,function
        else
                mov     ax,(function SHL 8) OR (subfunction AND 0ffh)
        endif
endm

DosInt  macro function, subfunction
        GenericInt <function>,<subfunction>
        int     DOS_INT
endm

BDISK_WRITE_SECTOR      = 03h

BDISK_INT       = 013h

; constants unique to this program

FILE_OFFS_LO    = 7C00h         ;
FILE_OFFS_HI    = 0000h         ;

BOOT_DRIVE      = 0             ; we'll be writing to drive A:
BOOT_HEAD       = 0             ; head 0 is the boot head
BOOT_CYLSECT    = 0001h         ; a word value with the following format
                                ; bits 15-8     low bits of cylinder
                                ; bits 7-6      high two bits of cylinder
                                ; bits 5-0      sector
NUM_SECTORS     = 1             ; number of sector to write to disk

        model small
        .386
        .stack  STACKSIZE
        .code
;**********************************************************************
; program code start
;**********************************************************************
Start:
; parse the command line args
        mov     cl,byte ptr [DGROUP:CMD_LINE_LEN]  ; read the length byte
        ; NOTE that the command line length isn't really part of the
        ; DGROUP group, but DS currently points to the PSP, and if we
        ; omit the DGROUP override, the assembler thinks we're trying
        ; to load a constant instead of the contents of the memory loc.
        ; In other words, it's ugly but it has a purpose.
        or      cl,cl                   ; check for zero
        jz      Usage                   ; no command line args
        mov     si,CMD_LINE             ;
        mov     al,' '                  ;
        repe    cmpsb                   ; burn off leading spaces
        mov     dx,si                   ; save that starting point
        repne   cmpsb                   ; scan for next space (if any)
        cmp     byte ptr [si],SPACE     ; if it's > space char,
        ja      skip                    ; skip the nul termination
        mov     byte ptr [si],NUL       ; terminate with a NUL char
skip:
; first, open the file
        DosInt  DOS_OPEN_HANDLE, READ_ONLY_DENY_NONE
        mov     si,seg DGROUP           ;
        mov     ds,si                   ;
        mov     es,si                   ; point 'em all over there
        mov     si,offset err_fopen     ; can't open input file
        jc      ErrorExit
; the file's open, so move the file pointer to offset 7C00h
        mov     bx,ax                   ; fetch the file handle
        mov     cx,FILE_OFFS_HI
        mov     dx,FILE_OFFS_LO
        DosInt  DOS_MOVE_HANDLE, WHENCE_BEGIN
        mov     si,offset err_fmove     ;
        jc      ErrorExit               ;
; read the data
        mov     cx,SECTORSIZE           ; max number of bytes to read
        mov     dx,offset buffer        ; point ds:dx to buffer
        DosInt  DOS_READ_HANDLE         ;
        mov     si,offset err_fread     ;
        jc      ErrorExit               ;
; close the file
        DosInt  DOS_CLOSE_HANDLE        ; close this file

; now write it out to the floppy disk's boot sector
        mov     bx,offset buffer        ;
        mov     cx,BOOT_CYLSECT         ;
        mov     dx,(BOOT_HEAD SHL 8) OR (BOOT_DRIVE)
        GenericInt BDISK_WRITE_SECTOR, NUM_SECTORS
        int     BDISK_INT
        mov     si,offset err_write     ;
        jc      ErrorExit               ;
        mov     si,offset msg_ok        ;
ErrorExit:
        mov     cx,[si]                 ;
        inc     si                      ;
        inc     si                      ;
        mov     dx,si                   ;
        mov     bx,1                    ; write to stdout
        DosInt  DOS_WRITE_HANDLE        ; write to that file
        DosInt  DOS_TERMINATE, 0

Usage:
        mov     si,seg DGROUP           ;
        mov     ds,si                   ; load correct data segment
        mov     si,offset use_msg
        jmp     ErrorExit               ;


;**********************************************************************
; program data starts
;**********************************************************************
        .data
msgstruc macro msglabel, msgstring
        local alpha
msglabel dw      (alpha - $) - 2
         db      msgstring
alpha = $
endm

msgstruc err_fopen ,<"ERROR: couldn't open input file",CR,LF>
msgstruc err_fmove ,<"ERROR: unable to move file pointer",CR,LF>
msgstruc err_fread ,<"ERROR: couldn't read from input file",CR,LF>
msgstruc err_write ,<"ERROR: unable to write to floppy disk",CR,LF>
msgstruc msg_ok    ,<"Boot sector was successfully written to floppy",CR,LF>
msgstruc use_msg   ,<"Usage:  SECTOR infile.bin",CR,LF>

buffer  db      SECTORSIZE dup (?)    ; sector buffer
        end Start
