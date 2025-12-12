
    ;========================================================
;  main.s ? Plant branch (model PIC)
;           Vctrl (AN0) -> ADC -> Ak -> ModelPlant -> Yk -> UART
;           Timer0 interrupt drives one plant step per Ts
;========================================================

#include <xc.inc>

    ;----------------------------------------------------
    ; External routines and variables from other modules
    ;----------------------------------------------------
    extrn   Init_Model
    extrn   ModelPlant

    extrn   AkL, AkH
    extrn   YkL, YkH

    extrn   ADC_Setup
    extrn   ADC_Read

    extrn   UART_Setup
    extrn   UART_Transmit_Byte

;========================================================
;  Vectors
;========================================================

psect   resetVec, class=CODE, abs
rst:    org 0x0000
        goto    setup

psect   highIntVec, class=CODE, abs
        org 0x0008
        goto    Timer_Int_Hi

;========================================================
;  Main code
;========================================================
psect   main_code, class=CODE

;--------------------------------------------------------
; setup: initialise model, ADC, UART and Timer0
;   Timer0 configuration is written to mimic DAC_Setup style:
;     - 16-bit mode
;     - clock = Fosc/4
;     - prescaler 1:8
;     - Ts ? 1 ms with preload 0xF810
;--------------------------------------------------------
setup:
        ; 1) World model init (alpha, drift, noise, etc.)
        call    Init_Model

        ; 2) On-chip ADC (AN0 = Vctrl)
        call    ADC_Setup

        ; 3) UART for sending Yk over TX (same interface as before)
        call    UART_Setup

        ; 4) Timer0 initial preload
        ;    Same style as controller DAC_Setup:
        ;    Fosc = 64 MHz -> instruction clock = 16 MHz
        ;    Timer0 clock = Fosc/4 = 16 MHz
        ;    Prescaler = 1:8  => tick = 0.5 탎
        ;    Need 2000 ticks  => 2000 * 0.5 탎 = 1 ms
        ;    Preload = 65536 - 2000 = 0xF810
        ;
        ;    >>> Change these two lines to change Ts <<<
        movlw   0xF8
        movwf   TMR0H, A
        movlw   0x30
        movwf   TMR0L, A

        ; 5) T0CON: same style as controller branch
        ;   - TMR0ON = 1    (enable)
        ;   - T08BIT = 0    (16-bit)
        ;   - T0CS   = 0    (clock = Fosc/4)
        ;   - PSA    = 0    (use prescaler)
        ;   - T0PS2:0 = 010 (prescaler 1:8)
        ;
        ;   >>> Change T0PS2:0 to change Timer0 tick (prescaler) <<<
        ;   Examples:
        ;     000: 1:2
        ;     001: 1:4
        ;     010: 1:8   (used here)
        ;     011: 1:16
        ;     100: 1:32
        ;     101: 1:64
        ;     110: 1:128
        ;     111: 1:256
        movlw   0b10000010          ; TMR0ON=1, 16-bit, Fosc/4, prescaler 1:8
        movwf   T0CON, A

        ; 6) Clear and enable Timer0 interrupt
        bcf     TMR0IF              ; clear Timer0 flag
        bsf     TMR0IE              ; enable Timer0 interrupt

        ; 7) Enable high-priority interrupts (same style as controller)
        bsf     GIEH                ; global high-priority enable

        ; main loop: idle, all work done in Timer_Int_Hi
        goto    MainLoop

;========================================================
; Timer_Int_Hi
;   High-priority ISR (model PIC side):
;   - Check TMR0IF
;   - Reload Timer0 for next Ts
;   - Run one plant step:
;       ADC_Read  -> Ak
;       ModelPlant -> Yk
;       UART send Yk (high then low byte)
;========================================================
Timer_Int_Hi:
        ; Make sure this is Timer0 interrupt
        btfss   TMR0IF
        retfie  f

        ; Clear Timer0 flag
        bcf     TMR0IF

        ;----------------------------------
        ; Reload Timer0 for next period Ts
        ;   HERE: Ts ? 1 ms
        ;   Fosc = 64 MHz -> instruction clock = 16 MHz
        ;   Timer0 clock = Fosc/4 = 16 MHz
        ;   Prescaler = 1:8  -> tick = 0.5 탎
        ;   Need 2000 ticks -> 2000 * 0.5 탎 = 1 ms
        ;   Preload = 65536 - 2000 = 0xF810
        ;
        ;   >>> Change these two lines to change Ts <<<
        ;----------------------------------
        movlw   0xF8
        movwf   TMR0H, A
        movlw   0x30
        movwf   TMR0L, A

        ;----------------------------------
        ; 1) ADC conversion: Vctrl(AN0) -> ADRESH:ADRESL
        ;----------------------------------
        call    ADC_Read           ; blocking until conversion completes

        ;----------------------------------
        ; 2) Copy ADC result to Ak (12-bit right-justified)
        ;    ADRESL -> AkL, ADRESH -> AkH
        ;----------------------------------
        movff   ADRESL, AkL
        movff   ADRESH, AkH

        ;----------------------------------
        ; 3) One world-model step: Ak -> Yk
        ;----------------------------------
        call    ModelPlant

        ;----------------------------------
        ; 4) Transmit Yk over UART:
        ;    high byte first, then low byte
        ;----------------------------------
        movf    YkH, W, A
        call    UART_Transmit_Byte

        movf    YkL, W, A
        call    UART_Transmit_Byte

        retfie  f

;--------------------------------------------------------
; MainLoop:
;   Idle loop ? all periodic work is done in Timer_Int_Hi.
;--------------------------------------------------------
MainLoop:
        bra     MainLoop           ; repeat forever

        end     rst