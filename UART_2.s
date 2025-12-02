#include <xc.inc>

global  UART2_Setup
global  UART2_Receive_Byte, UART2_Receive_12bit
global  UART2_H, UART2_L

; ---------------- RAM ----------------
psect   udata_acs
UART2_H:    ds 1          ; high byte received from UART2
UART2_L:    ds 1          ; low  byte received from UART2

; ---------------- CODE ----------------
psect   uart2_code, class=CODE

;--------------------------------------
; UART2_Setup  (9600 baud, async, 8N1, polling RX)
;--------------------------------------
UART2_Setup:
    ; 0) Make sure RG1/RG2 are digital inputs (no analogue on them)
    ;    On this device RG pins are digital-only, so nothing to clear in ANSELx.

    ; 1) Pins:
    ;    For EUSARTs Microchip recommend TRIS=1 even for TX,
    ;    the peripheral then drives the pin.
    bsf     TRISG, PORTG_TX2_POSN, A   ; RG1 = TX2 (set as input, peripheral drives it)
    bsf     TRISG, PORTG_RX2_POSN, A   ; RG2 = RX2 (input)

    ; 2) Baud rate generator for 9600 baud @ 64 MHz:
    ;    SPBRG2 = 103, BRGH2 = 0, BRG162 = 0  -> low-speed, 8-bit BRG
    clrf    SPBRGH2, A                 ; high byte = 0
    movlw   103
    movwf   SPBRG2, A                  ; low byte

    bcf     BRG162                     ; 8-bit BRG
    bcf     BRGH2                      ; low speed (÷64)

    ; 3) Async mode:
    bcf     SYNC2                      ; asynchronous mode

    ; 4) Enable serial port and receiver:
    bsf     SPEN2                      ; enable EUSART2, RG1/RG2 become RX2/TX2
    bsf     CREN2                      ; continuous receive enable

    ; (TX not strictly needed, but harmless)
    bsf     TXEN2                      ; enable transmitter (we may want it later)

    ; 5) Clear any junk in the FIFO and RC2IF
    movf    RCREG2, W, A              ; dummy reads
    movf    RCREG2, W, A

    ; If an overrun somehow happened, clear it:
    btfsc   OERR2                      ; overrun error?
    bcf     CREN2                      ; clear CREN2 to reset receiver
    bsf     CREN2

    return

;--------------------------------------
; UART2_Receive_Byte
;   Blocks until one byte is received on UART2.
;   Returns the byte in W.
;--------------------------------------
UART2_Receive_Byte:
RX_wait:
    btfss   RC2IF                      ; PIR3.RC2IF = 1 when RCREG2 has a byte
    bra     RX_wait
    movf    RCREG2, W, A               ; read byte ? W, clears RC2IF
    return

;--------------------------------------
; UART2_Receive_12bit
;   Waits for two bytes and stores them:
;   UART2_H = first byte  (MSB)
;   UART2_L = second byte (LSB)
;--------------------------------------
UART2_Receive_12bit:
    call    UART2_Receive_Byte
    movwf   UART2_H, A

    call    UART2_Receive_Byte
    movwf   UART2_L, A

    return

    end
