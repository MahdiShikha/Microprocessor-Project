#include <xc.inc>



global  SPI1_Init, DAC_WriteWord_16bit

global  DAC_high, DAC_low, SPI1_SendByte

global  DAC_Setup, Timer_Int_Hi, DAC_LoadFromDctrl



; D_ctrl is the 12-bit logical control word from controller.s

extrn  D_ctrlL, D_ctrlH

extrn  Controller_Step



; ---------------- RAM ----------------

psect   udata_acs

DAC_high:       ds 1        ; high data byte for DAC

DAC_low:        ds 1        ; low  data byte for DAC

DAC_ShiftCnt:   ds 1        ; local counter for left shifts



; ---------------- CODE ----------------

psect   dac_code,  class=CODE



;======================================

; SPI1_Init

;   CKP=0, CKE=1, Master Fosc/64

;======================================

SPI1_Init:

    ; SCK1, SDI1, SDO1 directions

    bcf     TRISC, PORTC_SCK1_POSN, A   ; RC3 = SCK1 (output)

    bsf     TRISC, PORTC_SDI1_POSN, A   ; RC4 = SDI1 (input)

    bcf     TRISC, PORTC_SDO1_POSN, A   ; RC5 = SDO1 (output)



    ; optional debug pin on RC0

    bcf     TRISC, 0, A

    bsf     LATC, 0, A



    ; RE0 used as DAC chip select (CS)

    bcf     TRISE, 0, A                 ; RE0 = CS (output)

    bsf     LATE, 0, A                  ; CS high (inactive)



    ; SSP1STAT: CKE=1, SMP=0

    clrf    SSP1STAT, A

    bsf     CKE1



    ; SSP1CON1: SSPEN=1, CKP=0, SSPM=0010 (Master Fosc/64)

    movlw   0x22

    movwf   SSP1CON1, A



    return



;======================================

; SPI1_SendByte

;   Sends W via SPI1, waits until BF=1.

;======================================

SPI1_SendByte:

    movwf   SSP1BUF, A

SPI1_WaitBF:

    btfss   SSP1STAT, 0, A      ; BF bit

    bra     SPI1_WaitBF

    movf    SSP1BUF, W, A       ; dummy read to clear BF

    return



;======================================

; DAC_WriteWord_16bit

;   Sends 16-bit value DAC_high:DAC_low

;   using MCP4922-style command 0x30.

;======================================

DAC_WriteWord_16bit:

    bcf     LATE, 0, A                  ; CS low



    movlw   0x30                        ; command: write & update

    call    SPI1_SendByte



    movf    DAC_high, W, A

    call    SPI1_SendByte



    movf    DAC_low, W, A

    call    SPI1_SendByte



    bsf     LATE, 0, A                  ; CS high (latch)

    return



;--------------------------------------

; DAC_LoadFromDctrl

;   D_ctrl is full 16-bit (0..0xFFFF).

;   DAC is 16-bit: send D_ctrl as-is.

;-------------------------------------ss-

DAC_LoadFromDctrl:

    movff   D_ctrlL, DAC_low

    movff   D_ctrlH, DAC_high

    return



;======================================

; Timer_Int_Hi

;   High-priority ISR:

;   - Check TMR0IF

;   - Reload Timer0 for next Ts

;   - Run one controller step

;   - Write D_ctrl to DAC

;======================================

Timer_Int_Hi:

    ; Make sure this is Timer0 interrupt

    btfss   TMR0IF

    retfie  f



    ; Clear Timer0 flag

    bcf     TMR0IF



    ;----------------------------------

    ; Reload Timer0 for next period Ts

    ;   HERE: Ts ? 1 ms

    ;   Fosc = 64 MHz ? instruction clock = 16 MHz

    ;   Timer0 clock = Fosc/4 = 16 MHz

    ;   Prescaler = 1:8  ? tick = 0.5 Âµs

    ;   Need 2000 ticks ? 2000 * 0.5 Âµs = 1 ms

    ;   Preload = 65536 - 2000 = 0xF810

    ;   >>> change these two lines to change Ts <<<

    ;----------------------------------

    movlw   0xF8

    movwf   TMR0H, A

    movlw   0x30

    movwf   TMR0L, A



    ; One control step (SCAN / LOCK / BODE)

    call    Controller_Step



    ; Convert D_ctrl to DAC_high:low and send

    call    DAC_LoadFromDctrl

    call    DAC_WriteWord_16bit



    retfie  f



;======================================

; DAC_Setup

;   - Initialise SPI/DAC pins

;   - Configure Timer0 for control period Ts

;   - Enable Timer0 interrupt and GIEH

;======================================

DAC_Setup:

    ; Set up SPI and DAC pins

    call    SPI1_Init



    ; Initial preload for Timer0

    ; Same value as in Timer_Int_Hi so the first period is correct.

    ; Ts ? 1 ms with prescaler 1:8 and preload 0xF810.

    movlw   0xF8

    movwf   TMR0H, A

    movlw   0x30

    movwf   TMR0L, A



    ;----------------------------------

    ; T0CON sets the Timer0 "clock rate":

    ;   - TMR0ON = 1    (enable)

    ;   - T08BIT = 0    (16-bit)

    ;   - T0CS   = 0    (clock = Fosc/4)

    ;   - PSA    = 0    (use prescaler)

    ;   - T0PS2:0 = 010 (prescaler 1:8)

    ;

    ;   >>> change T0PS2:0 to change Timer0 tick (prescaler) <<<

    ;   Examples:

    ;     000: 1:2

    ;     001: 1:4

    ;     010: 1:8   (used here)

    ;     011: 1:16

    ;     100: 1:32

    ;     101: 1:64

    ;     110: 1:128

    ;     111: 1:256

    ;----------------------------------

    movlw   0b10000010          ; TMR0ON=1, T08BIT=0, T0CS=0, PSA=0, T0PS=010

    movwf   T0CON, A



    ; Clear and enable Timer0 interrupt

    bcf     TMR0IF

    bsf     TMR0IE



    ; Enable high-priority interrupts

    bsf     GIEH



    return
