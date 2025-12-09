;========================================================
; main_model_adc_stream.s
;   PIC #2 (model PIC):
;   Reads AN0 via 12-bit ADC and streams codes over UART1.
;   Frame format:
;       [0xAA][ADRESH][ADRESL]
;========================================================
#include <xc.inc>

    extrn   ADC_Setup
    extrn   ADC_Read           ; leaves result in ADRESH:ADRESL
    extrn   UART_Setup
    extrn   UART_Transmit_Byte

    psect   udata_acs
ADCDelay1: ds 1
ADCDelay2: ds 1

    psect   code, abs
    org 0x0000
    goto    main_model

;--------------------------------------------------------
; Small delay (~1 ms-ish) between ADC samples
;--------------------------------------------------------
ADC_SmallDelay:
    movlw   100
    movwf   ADCDelay1, A
AD_L1:
    movlw   80
    movwf   ADCDelay2, A
AD_L2:
    decfsz  ADCDelay2, F, A
    bra     AD_L2
    decfsz  ADCDelay1, F, A
    bra     AD_L1
    return

;--------------------------------------------------------
; Main loop: ADC → UART1 (0xAA header + ADRESH + ADRESL)
;--------------------------------------------------------
    psect   code
main_model:
    ; Initialise on-chip ADC and UART1 TX
    call    ADC_Setup          ; sets AN0, Vref, right-justified, etc.
    call    UART_Setup         ; 9600 baud, async, TX1 on RC6

ADC_Stream_Loop:
    ; 1) One ADC conversion on AN0
    call    ADC_Read           ; ADRESH:ADRESL now holds 12-bit result

    ; 2) Send frame: [0xAA][ADRESH][ADRESL]
    movlw   0xFF               ; header byte
    call    UART_Transmit_Byte

    movf    ADRESH, W, A
    call    UART_Transmit_Byte

    movf    ADRESL, W, A
    call    UART_Transmit_Byte

    ; 3) Small pause before next reading
    call    ADC_SmallDelay

    bra     ADC_Stream_Loop

    end
