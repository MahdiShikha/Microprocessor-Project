;========================================================
; main_controller_dac_ramp.s
;   PIC #1 (controller PIC):
;   Drives Mikro DAC 2 with a 0→4095 ramp over ~15–20 s.
;   Uses external:
;       SPI1_Init
;       DAC_WriteWord_16bit
;       DAC_high, DAC_low
;========================================================
#include <xc.inc>

    extrn   SPI1_Init
    extrn   DAC_WriteWord_16bit
    extrn   DAC_high, DAC_low      ; 16-bit value used by your DAC driver

; Simple software delay
    psect   udata_acs
RampDelay1: ds 1
RampDelay2: ds 1

    psect   code, abs
    org 0x0000
    goto    main_controller

;--------------------------------------------------------
; ~4 ms-ish delay (for a ~16 s full sweep)
;--------------------------------------------------------
RampDelay:
    movlw   d'250'
    movwf   RampDelay1, A
RD_L1:
    movlw   d'80'
    movwf   RampDelay2, A
RD_L2:
    decfsz  RampDelay2, F, A
    bra     RD_L2
    decfsz  RampDelay1, F, A
    bra     RD_L1
    return

;--------------------------------------------------------
; Main: ramp DAC_high:DAC_low from 0x0000 to 0x0FFF
;--------------------------------------------------------
    psect   code
main_controller:
    ; Initialise SPI and DAC
    call    SPI1_Init

    ; Start at code 0x0000
    clrf    DAC_high, A
    clrf    DAC_low,  A

Ramp_Loop:
    ; Send current 16-bit word to DAC
    call    DAC_WriteWord_16bit

    ; Delay between steps (controls total sweep time)
    call    RampDelay

    ; Increment 12-bit DAC code in DAC_high:DAC_low
    incf    DAC_low, F, A
    btfss   STATUS, Z, A          ; if DAC_low rolled over 0xFF→0x00
    bra     No_Low_Overflow
    incf    DAC_high, F, A
No_Low_Overflow:

    ; Stop when code reaches 0x1000 (just after 0x0FFF)
    movf    DAC_high, W, A
    xorlw   0x10                  ; high == 0x10 ?
    btfsc   STATUS, Z, A
    bra     Ramp_Done

    bra     Ramp_Loop

Ramp_Done:
    ; Hold final value forever
    bra     Ramp_Done

    end
