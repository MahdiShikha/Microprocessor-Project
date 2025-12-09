;========================================================
; main_controller_dac_ramp.s  (16-bit version)
;   PIC #1 (controller PIC):
;   Drives Mikro DAC 2 with a 0?0xFFFF ramp.
;   Uses external:
;       SPI1_Init
;       DAC_WriteWord_16bit
;       DAC_high, DAC_low
;========================================================
#include <xc.inc>

    extrn   SPI1_Init
    extrn   DAC_WriteWord_16bit
    extrn   DAC_high, DAC_low      ; 16-bit value used by your DAC driver

;--------------------------------------------------------
; RAM for delay counters
;--------------------------------------------------------
    psect   udata_acs
RampDelay1: ds 1
RampDelay2: ds 1

;--------------------------------------------------------
; Reset vector
;--------------------------------------------------------
    psect   code, abs
    org 0x0000
    goto    main_controller

;--------------------------------------------------------
; ~few-ms delay (tune constants for desired sweep time)
;--------------------------------------------------------
    psect   code
RampDelay:
    movlw   125            ; was 250 in old 12-bit version
    movwf   RampDelay1, A
RD_L1:
    movlw   80
    movwf   RampDelay2, A
RD_L2:
    decfsz  RampDelay2, F, A
    bra     RD_L2
    decfsz  RampDelay1, F, A
    bra     RD_L1
    return

;--------------------------------------------------------
; Main: ramp DAC_high:DAC_low from 0x0000 to 0xFFFF
;--------------------------------------------------------
main_controller:
    ; Initialise SPI and DAC
    call    SPI1_Init

    ; Start at code 0x0000
    clrf    DAC_high, A
    clrf    DAC_low,  A

Ramp_Loop:
    ; 1) Send current 16-bit word to DAC
    call    DAC_WriteWord_16bit

    ; 2) Delay between steps (controls total sweep time)
    call    RampDelay

    ; 3) If we've already output 0xFFFF, stop ramping
    movf    DAC_high, W, A
    xorlw   0xFF
    btfss   STATUS, 2, A        ; Z=1 if DAC_high == 0xFF
    bra     NotMax

    movf    DAC_low, W, A
    xorlw   0xFF
    btfss   STATUS, 2, A        ; Z=1 if DAC_low == 0xFF
    bra     NotMax

    ; Here DAC_high==0xFF and DAC_low==0xFF -> we're done
    bra     Ramp_Done

NotMax:
    ; 4) Increment 16-bit DAC code: DAC_low++, carry into DAC_high
    incf    DAC_low, F, A
    ; incf sets Z=1 only when result is 0x00. If not 0, just loop.
    btfss   STATUS, 2, A        ; Z flag
    bra     Ramp_Loop

    ; low byte wrapped 0xFF?0x00, so bump high byte
    incf    DAC_high, F, A
    bra     Ramp_Loop

;--------------------------------------------------------
; Ramp_Done:
;   We have output 0xFFFF to the DAC. Sit here forever
;   (or modify if you want repeat / ramp down etc.).
;--------------------------------------------------------
Ramp_Done:
    bra     Ramp_Done

    end
