#include <xc.inc> 

    

global  UART1_Setup

global  UART1_Receive_Byte, UART1_Receive_12bit

global  UART1_Transmit_Byte, UART1_Transmit_Message

global  UART1_H, UART1_L



psect   udata_acs

UART1_H:        ds 1        ; high byte received

UART1_L:        ds 1        ; low  byte received

UART1_counter:  ds 1        ; length counter for TX messages



psect   uart1_code, class=CODE



;--------------------------------------

; UART1_Setup  (~115200 baud @ 64 MHz, async, 8N1)

;   RX1 (RC7): from model PIC

;   TX1 (RC6): to PC (USB-UART) or other host

;--------------------------------------

UART1_Setup:

    ; Configure pins:

    ; RC7 = RX1 input, RC6 = TX1 (set TRISC6=1 to let EUSART drive it)

    bsf     TRISC, PORTC_RX1_POSN, A   ; RC7 input

    bsf     TRISC, PORTC_TX1_POSN, A   ; RC6 controlled by EUSART



    ; Baud rate configuration (Fosc = 64 MHz):

    ;   BRG16 = 0, BRGH = 1  -> Baud ≈ Fosc / (16 * (SPBRG + 1))

    ;   For Baud ≈ 115200:

    ;       SPBRG ≈ 34 -> Baud ≈ 64 MHz / (16 * 35) ≈ 114285 bps (error < 1%)

    clrf    SPBRGH1, A                 ; high byte = 0 (8-bit BRG)

    movlw   34                         ; SPBRG1 = 34 -> ~115200 baud

    movwf   SPBRG1, A



    bcf     BRG16                      ; 8-bit BRG

    bsf     BRGH                       ; high-speed baud

    bcf     SYNC                       ; asynchronous mode



    bsf     SPEN                       ; enable EUSART1 module

    bsf     CREN                       ; enable receiver

    bsf     TXEN                       ; enable transmitter



    return



;--------------------------------------

; UART1_Receive_Byte

;   Blocking read of one byte from UART1

;   Returns byte in W

;--------------------------------------

UART1_Receive_Byte:

UART1_RxWait:

    btfss   RC1IF                      ; 1 when RCREG1 has a byte

    bra     UART1_RxWait

    movf    RCREG1, W, A               ; read clears RC1IF

    return



;--------------------------------------

; UART1_Receive_12bit

;   Receive 2 bytes: MSB then LSB

;   Store into UART1_H / UART1_L

;--------------------------------------

UART1_Receive_12bit:

    call    UART1_Receive_Byte

    movwf   UART1_H, A



    call    UART1_Receive_Byte

    movwf   UART1_L, A



    return



;--------------------------------------

; UART1_Transmit_Byte

;   Transmit byte in W over UART1

;--------------------------------------

UART1_Transmit_Byte:

UART1_TxWait:

    btfss   TX1IF                      ; TXREG1 empty?

    bra     UART1_TxWait

    movwf   TXREG1, A

    return



;--------------------------------------

; UART1_Transmit_Message

;   W = length, FSR2 points to buffer

;   Sends buffer[0..length-1] over UART1

;--------------------------------------

UART1_Transmit_Message:

    movwf   UART1_counter, A



UART1_TxLoop:

    movf    POSTINC2, W, A

    call    UART1_Transmit_Byte

    decfsz  UART1_counter, A

    bra     UART1_TxLoop

    return



    end
