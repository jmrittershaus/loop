;
input    equ       080h      ;command line tail buffer
cr       equ       0dh       ;ASCII carriage return
;
cseg     segment   byte
         assume    cs:cseg,ds:cseg
;
         org       0100h     ;since this will be
                             ; a COM file
;
clear:                       ;initialize display...
                             ;call BIOS video driver to
         mov       ah,15     ;get current display mode:
         int       10h       ;returns AL = mode, and
                             ;AH = no. of columns.
         cmp       al,7      ;if we are in graphics modes
         je        clear0    ;(modes 4,5,6) then exit
         cmp       al,3      ;but if we are in mode 0-3
         ja        clear9    ;or 7 then continue.
clear0:                      ;set up size of window to
                             ;be initialized...
         xor       cx,cx     ;set upper left corner of
                             ;window to (X,Y)=(0,0)
         mov       dh,24     ;set Y to 24 for lower right
         mov       dl,ah     ;corner, and X to the number
         dec       dl        ;of columns returned by BIOS
                             ;minus 1
         mov       bh,7      ;initialize attribute byte
                             ;to "normal" video display,
                             ;i.e. white on black.
                             ;set SI=address of command
                             ;tail's length byte
         mov       si,offset input
         cld                 ;clear the Direction Flag
                             ;for "LODS" string instruction.
         lodsb               ;check length byte to see if
         or        al,al     ;there's any command tail.
         jz        clear8    ;no,go clear the screen
                             ;with normal video attribute
                             ;
clear1:  lodsb               ;check the next byte of
                             ;the command tail,
         cmp       al,cr     ;if carriage return
         je        clear8    ;we are done.
         or        al,20h    ;fold the character to
                             ;lower case.
         cmp       al,'a'    ;make sure it's in range a-z
         jb        clear1    ;no, skip it
         cmp       al,'z'
         ja        clear1    ;no, skip it
         cmp       al,'i'    ;I=Set intensity
         jne       clear2    ;jump if not I
         or        bh,08     ;set intensity bit
         jmp       short clear1
clear2:  cmp       al,'r'    ;R=Reverse
         jne       clear3    ;jump if not R
         and       bh,088h   ;mask off old foreground/
                             ;background bits and
         or        bh,070h   ;change to reverse video
         jmp       short clear1
clear3:  cmp       al,'u'    ;U=Underline
         jne       clear4    ;jump if not U
         and       bh,088h   ;mask off old foreground/
                             ;background bits and
         or        bh,01h    ;change to underline
         jmp       short clear1
clear4:  cmp       al,'b'    ;B=Blink
         jne       clear5    ;jump if not B
         or        bh,080h   ;set blink bit
         jmp       short clear1
clear5:  cmp       al,'s'    ;S=Silent
         jne       clear1    ;if not S try next char.
         mov       bh,0      ;if S command, rig for
                             ;silent running.  Clear
                             ;the foreground/background
                             ;display control fields, and
                             ;don't bother to look for
                             ;any more command characters.
                             ;
clear8:                      ;now we have decoded all
                             ;the characters in the
                             ;command tail, and are ready
                             ;to initialize the display.
                             ;BH=   desired attribute
                             ;CL,CH=(X,Y),upper left
                             ;      corner of window
                             ;DL,DH=(X,Y),lower right
                             ;      corner of window
         mov       ax,0600h  ;AH =  function type 6,
                             ;AL =  lines to scroll (zero)
         int       10h       ;request initialization
                             ;of window by BIOS
                             ;
         mov       ah,2      ;now set the cursor to
         mov       bh,0      ;(X,Y)=(0,0), Page=0
         xor       dx,dx
         int       10h
                             ;
clear9:  int       20h       ;exit to PC-DOS
;
cseg     ends
;
         end       clear
