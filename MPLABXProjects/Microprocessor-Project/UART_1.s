#include <xc.inc>

global  UART1_Setup
global  UART1_Receive_Byte, UART1_Receive_12bit
global  UART1_H, UART1_L

; ---------------- RAM ----------------
psect   udata_acs
UART1_H:    ds 1          ; high byte received from UART1
UART1_L:    ds 1          ; low  byte received from UART1

; ---------------- CODE ----------------
psect   uart1_code, class=CODE

;--------------------------------------
; UART1_Setup  (9600 baud, async, 8N1, polling RX)
;--------------------------------------
UART1_Setup:
    ; 0) Make sure RC7 is input (RX1)
    ;    For EUSARTs Microchip recommend TRIS=1 even for TX,
    ;    the peripheral then drives the pin.
    bsf     TRISC, PORTC_RX1_POSN, A   ; RC7 = RX1 (input)

    ; 2) Baud rate generator for 9600 baud @ 64 MHz:
    ;    SPBRG1 = 103, BRGH = 0, BRG16 = 0  -> low-speed, 8-bit BRG
    clrf    SPBRGH1, A                 ; high byte = 0
    movlw   103
    movwf   SPBRG1, A                  ; low byte

    bcf     BRG16                      ; 8-bit BRG
    bcf     BRGH                       ; low speed (÷64)

    ; 3) Async mode:
    bcf     SYNC                       ; asynchronous mode

    ; 4) Enable serial port and receiver:
    bsf     SPEN                       ; enable EUSART1, RC6/RC7 become TX1/RX1
    bsf     CREN                       ; continuous receive enable

    ; (TX not needed right now, so TXEN left clear)

    ; 5) Optionally clear any junk in the FIFO and RC1IF
    ;movf    RCREG1, W, A              ; dummy reads
    ;movf    RCREG1, W, A
    ;
    ; If an overrun somehow happened, clear it:
    ;btfsc   OERR                       ; overrun error?
    ;bcf     CREN                       ; clear CREN to reset receiver
    ;bsf     CREN

    return

;--------------------------------------
; UART1_Receive_Byte
;   Blocks until one byte is received on UART1.
;   Returns the byte in W.
;--------------------------------------
UART1_Receive_Byte:
RX1_wait:
    btfss   RC1IF                      ; PIR1.RC1IF = 1 when RCREG1 has a byte
    bra     RX1_wait
    movf    RCREG1, W, A               ; read byte ? W, clears RC1IF
    return

;--------------------------------------
; UART1_Receive_12bit
;   Waits for two bytes and stores them:
;   UART1_H = first byte  (MSB)
;   UART1_L = second byte (LSB)
;   (second byte currently commented, as in your UART2 version)
;--------------------------------------
UART1_Receive_12bit:
    call    UART1_Receive_Byte
    movwf   UART1_H, A

    call    UART1_Receive_Byte
    movwf   UART1_L, A

    return

    end
