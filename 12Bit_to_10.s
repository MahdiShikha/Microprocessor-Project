#include <xc.inc>

extrn  Mul16x16, Mul24x8
extrn  ARG1L,ARG1H,ARG2L,ARG2H
extrn  X0,X1,X2,Y0
extrn  RES0,RES1,RES2,RES3

global ADC_to_4digits
global DEC3,DEC2,DEC1,DEC0

psect udata_acs
DEC3:   ds 1
DEC2:   ds 1
DEC1:   ds 1
DEC0:   ds 1

psect adc_conv_code, class=CODE

; ----------------------------------------------
; ADC_to_4digits
; IN:  ADRESH:ADRESL = 12-bit ADC value (0..0x0FFF)
; OUT: DEC3 DEC2 DEC1 DEC0 = decimal digits (thousands..ones)
; Uses algorithm from slides:
;   Step 1: N * 0x418A  (16×16) ? first digit + 24-bit remainder
;   Step 2?4: remainder * 10    (24×8) ? next digits
; ----------------------------------------------
ADC_to_4digits:

    ; -----------------------------
    ; Step 1: 16×16: N * 0x418A
    ; -----------------------------
    ; ARG1 = N (ADC result)
    movff   ADRESL, ARG1L
    movff   ADRESH, ARG1H

    ; ARG2 = 0x418A (k = 2^24 / 1000)
    movlw   0x8A
    movwf   ARG2L, A
    movlw   0x41
    movwf   ARG2H, A

    call    Mul16x16    ; result in RES3:RES2:RES1:RES0

    ; First decimal digit = top byte RES3
    movff   RES3, DEC3

    ; 24-bit remainder = low 24 bits ? X2:X1:X0
    movff   RES2, X2    ; high of remainder
    movff   RES1, X1
    movff   RES0, X0    ; low

    ; -----------------------------
    ; Step 2: remainder * 10 ? DEC2
    ; -----------------------------
    movlw   0x0A
    movwf   Y0, A       ; multiply by 10
    call    Mul24x8     ; RES3:RES2:RES1:RES0

    movff   RES3, DEC2              ; next digit
    movff   RES2, X2                ; new remainder (24-bit)
    movff   RES1, X1
    movff   RES0, X0

    ; -----------------------------
    ; Step 3: remainder * 10 ? DEC1
    ; -----------------------------
    movlw   0x0A
    movwf   Y0, A
    call    Mul24x8

    movff   RES3, DEC1
    movff   RES2, X2
    movff   RES1, X1
    movff   RES0, X0

    ; -----------------------------
    ; Step 4: remainder * 10 ? DEC0
    ; -----------------------------
    movlw   0x0A
    movwf   Y0, A
    call    Mul24x8

    movff   RES3, DEC0
    ; (we don't need the final remainder now)

    return


