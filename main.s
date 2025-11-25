; ===== PIC18 + 74HC164: SPI table loop + PORTC speed =====
#include <xc.inc>

TEMP     EQU 0x20
COUNT    EQU 0x21
REPEATS  EQU 0x22
FRAMES   EQU 0x23

psect code, abs
main:
    org 0x0000
    goto start

    org 0x0100

; ---- SPI2 init: CKP=1, CKE=0, Master Fosc/64 ----
SPI2_Init:
    bcf   TRISD, 4, A           ; RD4 SDO2 out
    bcf   TRISD, 6, A           ; RD6 SCK2 out
    clrf  SSP2STAT, A           ; CKE=0
    movlw 0x32                  ; SSPEN=1, CKP=1, SSPM=0010(Fosc/64)
    movwf SSP2CON1, A
    return

; ---- Send 1 byte via SPI2 (MSB-first, auto 8 clocks) ----
SPI2_SendByte:
    movwf SSP2BUF, A
WBF:btfss SSP2STAT, 0, A        ; BF?
    bra   WBF
    movf  SSP2BUF, W, A         ; clear BF
    return

; ---- Rough delay in ms (0..255) ----
Delay_ms:
    movwf COUNT, A
D1: movlw 0xC8
    movwf TEMP, A
D2: nop
    nop
    decfsz TEMP, F, A
    bra   D2
    decfsz COUNT, F, A
    bra   D1
    return

; ---- Long delay by PORTC: blocks of 50 ms, repeat N(=PORTC+1) ----
Delay_By_PORTC:
    movf  PORTC, W, A           ; N=0..255
    bnz   L1
    movlw 1                     ; avoid zero -> at least 1 block
L1: movwf REPEATS, A
L2: movlw 50                    ; one block = ~50 ms
    rcall Delay_ms
    decfsz REPEATS, F, A
    bra   L2
    return

; ---- Pattern table in Program Memory ----
patterns:
    db 0x81,0x42,0x24,0x18,0x24,0x42,0x81,0x00
TABLE_LEN EQU 8

; ================= main =================
start:
    rcall SPI2_Init
    movlw 0xFF
    movwf TRISC, A              ; PORTC as inputs (speed knob)

MainLoop:
    ; point TBLPTR to table start
    movlw low  highword(patterns)
    movwf TBLPTRU, A
    movlw high(patterns)
    movwf TBLPTRH, A
    movlw low (patterns)
    movwf TBLPTRL, A

    movlw TABLE_LEN
    movwf FRAMES, A

PlayLoop:
    tblrd*+                     ; TABLAT = *TBLPTR; TBLPTR++
    movf  TABLAT, W, A
    rcall SPI2_SendByte
    rcall Delay_By_PORTC        ; delay = (PORTC+1)*50 ms
    decfsz FRAMES, F, A
    bra   PlayLoop

    bra   MainLoop              ; loop forever

    end