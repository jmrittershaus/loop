kbd             equ     16h             ;keyboard irq
msdos           equ     21h             ;MSDOS irq

reset           equ     0dh             ;disk reset
dfopen          equ     0fh             ;open disk file
dfclose         equ     10h             ;close disk file
searchf         equ     11h             ;search first
searchn         equ     12h             ;search next
seqread         equ     14h             ;sequential disk read
seqwrite        equ     15h             ;     "       "  write
setdta          equ     1ah             ;set disk transfer area address
createf         equ     3ch             ;create file with handle
openf           equ     3dh             ;open file with handle
closef          equ     3eh             ;close file with handle
readf           equ     3fh             ;read from file with handle
writef          equ     40h             ;write to file with handle
setfp           equ     42h             ;set file pointer
allocmem        equ     48h             ;allocate memory
freemem         equ     49h             ;free memory
changebs        equ     4ah             ;change block size
findfirst       equ     4eh             ;find first file
exit            equ     4c00h           ;msdos exit

[BITS 16]                               ;NASM stuff
[ORG 0x100]

s1:
        mov     ax,cs                   ;get code segment
        mov     ds,ax                   ;use it now
        mov     [comseg],ds             ;save it there        

        mov     si,0080h                ;DOS command line page 0
        lodsb                           ;load size of command line
        cmp     al,0                    ;anything on command line ?
        jbe     usage                   ;noo, show usage
        cbw                             ;extend AL to AX
        xchg    bx,ax                   ;swap size to bx for indexing
        mov     byte [bx+si],0          ;null terminate command line
        call    parse                   ;parse command line
        jmp     main                    ;go on with main
usage:  mov     bx,utext                ;pointer usage text
        jmp     errout                  ;skip this
main:
        mov     si,inbuff               ;check for valid HEX input
        mov     bx,errt1                ;proper text
ishex:  lodsb                           ;get the char
        cmp     al,'0'
        jb      errout
        and     al,0dfh                 ;force UPPERCASE
        cmp     al,'F'                  ;>F ?
        ja      errout                  ;yeahh, dump this
        loop    ishex
        call    hexbin                  ;make hex bin
                                        ;start address now in EDX
        mov     ax,dx                   ;get low word (segment)
        mov     es,ax                   ;start segment
        shr     edx,16                  ;shift in offset
        mov     di,dx                   ;start offset
dopage:
        push    es                      ;save registers
        push    di
        push    ds
        push    si
        mov     ax,es
        mov     ds,ax                   ;make ds=es
        mov     si,di                   ;and si=di
        
        call    showpage                ;show it
        
        pop     si                      ;restore registers
        pop     ds
        pop     di
        pop     es
        add     di,512                  ;adjust memory position

        ;xor     ah,ah                  ;wait for ANY key
        ;int     kbd
        
        mov     bx,text                 ;show message
        call    write
        mov     ah,0                    ;wanna see next screen  ?
        int     kbd                     ;chek out keyboard buffer
        and     al,0DFh                 ;force UPPER CASE
        cmp     al,"Q"                  ;wanna quit ?
        je      quit                    ;yeahh
        jmp     dopage
errout:
        call    write
quit:   
        mov     ax,exit
        int     msdos

;***********************************************************
;*      Convert ascii hex to 32 bit binary
;*      Input = command line buffer, output EDX
;***********************************************************
hexbin:
        mov     si,inbuff               ;pointer command line buffer
        xor     edx,edx                 ;clear binary output
aschexbin:
        lodsb
        cmp     al,'0'                  ;< 0
        jb      notasc                  ;yes invalid character
        cmp     al,'9'                  ;<= 9
        jbe     astrip                  ;yes, strip high 4 bits
        and     al,05fh                 ;force upper case
        cmp     al,'A'                  ;< ascii A
        jb      notasc                  ;yes, invalid character
        cmp     al,'F'                  ;> ascii F
        ja      notasc                  ;yes, invalid character
        add     al,9                    ;ok, add 9 for strip
astrip:
        and     al,0fh                  ;strip high 4 bits
        mov     cx,4                    ;set shift count
        shl     edx,cl                  ;rotate EDX 4 bits
        xor     ah,ah                   ;zero out AH
        cbw
        add     edx,eax                 ;add digit to value
        jmp     aschexbin               ;continue
notasc: ret

;*********************************************************************
;*      Format and show the stuff in a "sector"
;*      Input SI
;*********************************************************************
showpage:
        mov     cx,32                   ;32*16=512
arow:   push    cx
        mov     di,outline              ;output buffer
        mov     cx,16                   ;process 16 bytes
hexrow: push    cx
        lodsb                           ;load al with byte
        mov     dl,al                   ;get value
        mov     cx,2                    ;2 nibbles
chexb:  push    cx                      ;save that
        mov     cl,4                    ;4 bits
        rol     dl,cl                   ;rotate source left
        mov     al,dl                   ;move digit into AL
        and     al,15                   ;clear high nibble
        daa                             ;adjust AL if A through F
        add     al,240                  ;bump the carry
        adc     al,40h                  ;convert HEX to ASCII
        stosb                           ;copy to buffer
        pop     cx                      ;get digit counter
        loop    chexb                   ;next digit
        mov     al,32                   ;copy a SPACE
        stosb
        pop     cx                      ;restore loop counter
        loop    hexrow                  ;loop on
        mov     al,32                   ;copy 2 spaces
        stosb
        stosb
        sub     si,16                   ;adjust source back
        mov     cx,16                   ;copy ASCII bytes
cccp:   lodsb
        cmp     al,32                   ;< SPACE ?
        jb      noa                     ;yeahh, skip it
        stosb                           ;no, store in buffer
        jmp     next
noa:    mov     al,'.'
        stosb
next    loop    cccp   
        mov     al,13
        stosb
        mov     al,10
        stosb
        mov     al,0                    ;null terminate line
        stosb
        mov     bx,outline              ;show the line
        call    write
        pop     cx
        cmp     cx,17
        jne     nopause
        push    ds
        mov     ax,cs
        mov     ds,ax
        mov     bx,text1
        call    write
        pop     ds
        xor     ah,ah
        int     kbd
nopause:
        loop    arow                    ;next 16 bytes
        ret

;************************************************************************'
;*      Convert bin WORD to HEX ascii. Input DX. Result in Numbuff      *
;************************************************************************
binhex: pusha       
        mov     di,numbuff              ;destination buffer
        mov     dx,[count]              ;binary number
        mov     cx,4                    ;four nibbles
convhex:
        push    cx                      ;save counter
        mov     cl, 4                   ;4 bits
        rol     dx, cl                  ;rotate source left
        mov     al, dl                  ;move digit into AL
        and     al, 15                  ;clear high nibble
        daa                             ;adjust AL if A through F
        add     al, 240                 ;bump the carry
        adc     al, 40h                 ;convert HEX to ASCII
        stosb                           ;copy to buffer
        pop     cx                      ;get digit counter
        loop    convhex                 ;next digit
        mov     al,32                   ;copy a space
        stosb
        mov     al,0                    ;null terminate
        stosb
        popa
        ret

;*************************************************************************
;*       Writes out the NULL terminated text supplied in BX.             *
;*       OR writes out data,BX and size,CX if called at lwrite.          *
;*************************************************************************
write:  pusha
        mov     si,bx                   ;copy to SI
        mov     cx,0                    ;clear count
wloop:  lodsb                           ;load AL with SI
        cmp     al,0                    ;end of line ?
        je      lwrite                   ;yeahh
        inc     cx                      ;no, incrase byte count
        jmp     wloop                   ;test next byte
lwrite: mov     dx,bx                   ;text address in DX
        mov     bx,1                    ;filehandle standard output = 1
        mov     ah,writef               ;MS-DOS writefile with handle is 040
        int     msdos                   ;write buffer to standard output
        popa
        ret                             ;done

;*************************************************************************
;*      My kind of command line parsing. It just checks if there�s
;*      any blankspaces between the options. The parameters ends up
;*      in the inbuff separated by 0:s, binary zeroes.
;*************************************************************************
parse:
        mov     di,inbuff               ;our buffer
ifspc:  cmp     byte [si],32            ;leading space  ?
        jne     nospc                   ;noo
        inc     si                      ;yeahh, dump that
        jmp     ifspc                   ;check next
nospc:  mov     cx,1                    ;were here, so we got one arg
copy1:  lodsb                           ;load byte SI to AL
        cmp     al,0                    ;0 ?(end of line)
        je      done                    ;yeahh
        cmp     al,32                   ;SPACE ?
        je      cop2                    ;yeah
        stosb                           ;noo, move AL to DI, incrase DI
        jmp     copy1                   ;go on
cop2:   mov     byte [di],0             ;null terminate
        add     cx,1
        inc     di                      ;dump that byte(SPACE)
        jmp     copy1                   ;back
done:   mov     byte [di],0             ;null terminate
        ret                             ;return


;*************************** DATA STUFF **********************************

XMS_SEGMENT     dw 0
XMS_OFFSET      dw 0

inbuff          times 64 dw 0           ;128 byte command line buffer
outline         times 40 dw 0           ;buffer output line
numbuff         times 7 dw 0            ;word ascii number buffer
comseg          dw 0
count           dw 0
bcount          dw 0
acount          dw 0

;outbuff         times 512 db 0


utext           db      'WWW',13,10
                db      'Usage: Showmem [start address].',13,10
                db      'Start address = Hexadecimal.',13,10,0
text:           db      13,10,'Q = Quit. Any key = Next page.',13,10,0
text1:          db      13,10,'Any Key = Next 256 Bytes.',13,10,0
errt1:          db      'That address is not hexadecimal.',13,10,0

s2:

END