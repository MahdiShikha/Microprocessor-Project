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
;  Configure EUSART2 to match the working UART1 settings:
;    SPBRGH1 = 0x00
;    SPBRG1  = 0x67
;    BAUDCON1 = 0x40
;    TXSTA1  = 0x22
;    RCSTA1  = 0x90
;--------------------------------------
UART2_Setup:
    clrf    SPBRGH2,A
    clrf    SPBRG2, A
    clrf    BAUDCON2, A
    clrf    RCSTA2, A
    
    ; 0) Make RG2 the RX2 input pin
    bsf     TRISG, PORTG_RX2_POSN, A   ; RG2 = RX2 (input)

    ; 1) Baud-rate generator: SPBRGH2:SPBRG2 = 0x00:0x67
    clrf    SPBRGH2, A                 ; SPBRGH2 = 0x00
    movlw   103
    movwf   SPBRG2, A                  ; SPBRG2  = 0x67

    ; 2) BAUDCON2 = 0x40 (same as BAUDCON1)
    movlw   0x40                       ; 0100 0000
    movwf   BAUDCON2, A                ; BRG16=0, WUE=0, RCIDL=1

    ; 3) TXSTA2 = 0x22 (same as TXSTA1)
    ;movlw   0x22                       ; 0010 0010
    ;movwf   TXSTA2, A                  ; async, BRGH=0, TXEN=1

    ; 4) RCSTA2 = 0x90 (same as RCSTA1)
    movlw   0x90                       ; 1001 0000
    movwf   RCSTA2, A                  ; SPEN=1, CREN=1, 8-bit, no addr detect

    return

;--------------------------------------
; UART2_Receive_Byte
;   Blocks until one byte is received on UART2.
;   Returns the byte in W.
;--------------------------------------
UART2_Receive_Byte:
RX2_wait:
    btfss   RC2IF                      ; PIR3.RC2IF = 1 when RCREG2 has a byte
    bra     RX2_wait
    movf    RCREG2, W, A               ; read byte -> W, clears RC2IF
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
