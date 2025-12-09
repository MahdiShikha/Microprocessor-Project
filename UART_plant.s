#include <xc.inc> 
       
global  UART_Setup, UART_Transmit_Message, UART_Transmit_Byte

psect   udata_acs           ; reserve data space in access ram
UART_counter:  ds    1      ; reserve 1 byte for variable UART_counter

psect   uart_code, class=CODE

;--------------------------------------------------------
; UART_Setup
;   Configure EUSART1 for high-speed async TX:
;     - Asynchronous mode
;     - High speed (BRGH = 1)
;     - 8-bit baud generator (BRG16 = 0)
;     - Baud ? 115200 at Fosc = 64 MHz
;--------------------------------------------------------
UART_Setup:
    bsf     SPEN            ; enable serial port
    bcf     SYNC            ; asynchronous mode
    bsf     BRGH            ; high-speed baud rate
    bsf     TXEN            ; enable transmit
    bcf     BRG16           ; 8-bit generator only

    ; Baud rate setting:
    ;   Fosc = 64 MHz
    ;   BRG16 = 0, BRGH = 1  -> Baud ? Fosc / (16 * (SPBRG+1))
    ;   For Baud ? 115200:
    ;       SPBRG ? 34  -> Baud ? 114285 (error < 1%)
    movlw   34              ; SPBRG1 = 34 -> ~115200 Baud
    movwf   SPBRG1, A       ; set baud rate

    ; TX1 pin is output on RC6 pin
    ; TRISC6 must be set to 1 to let EUSART control the pin
    bsf     TRISC, PORTC_TX1_POSN, A

    return

;--------------------------------------------------------
; UART_Transmit_Message
;   Message stored at FSR2, length stored in W
;--------------------------------------------------------
UART_Transmit_Message:
    movwf   UART_counter, A
UART_Loop_message:
    movf    POSTINC2, W, A
    call    UART_Transmit_Byte
    decfsz  UART_counter, A
    bra     UART_Loop_message
    return

;--------------------------------------------------------
; UART_Transmit_Byte
;   Transmits byte stored in W
;--------------------------------------------------------
UART_Transmit_Byte:
    btfss   TX1IF           ; TX1IF is set when TXREG1 is empty
    bra     UART_Transmit_Byte
    movwf   TXREG1, A
    return

end