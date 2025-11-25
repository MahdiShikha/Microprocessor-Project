#include <xc.inc>
    
    global  SPI1_Init, DAC_WriteWord
    global  DAC_high, DAC_low,SPI1_SendByte
    
    psect   udata_acs
    DAC_high:	ds 1
    DAC_low:	ds 1
    ; ---- SPI1 init: CKP=1, CKE=0, Master Fosc/64 ----
    psect dac_code,  class=CODE
SPI1_Init:
    bcf	  TRISC, PORTC_SCK1_POSN, A	;RC3 = SCK1       
    bsf	  TRISC, PORTC_SDI1_POSN, A	;RC4 = SDI1
    bcf	  TRISC, PORTC_SDO1_POSN, A     ;RC5 = SDO1
    
    bcf TRISC, 0, A
    bsf LATC,0,A
    
    bcf	  TRISE, 0, A
    bsf	  LATE, 0 , A 
    
    ; --- SPI1 config: Master, Fosc/64, mode 0,0 (CKP=0, CKE=1) ---
    
    clrf    SSP1STAT, A
    bsf    CKE1             ; transmit on active->idle edge

    ; SSP1CON1: SSPEN=1, CKP=0, SSPM=0010 (Master Fosc/64)
    movlw   0x22                 ; WCOL=0,SSPOV=0,SSPEN=1,CKP=0,SSPM=0010
    movwf   SSP1CON1, A                 ; enable MSSP1 in SPI mode

    return

; ---- Send 1 byte via SPI1 (MSB-first, auto 8 clocks) ----
SPI1_SendByte:
    ;bSf	  LATE,0,A
    movwf SSP1BUF, A
WBF:btfss SSP1STAT, 0, A        ; BF?
    bra   WBF
    movf  SSP1BUF, W, A         ; clear BF
    ;bcf	  LATE,0,A
    return
DAC_WriteWord:
    bcf     LATE, 0, A                  ; CS low (select DAC)

    movlw   0x30                        ; command: write & update
    call    SPI1_SendByte

    movf    DAC_high, W, A               ; high data byte
    call    SPI1_SendByte

    movf    DAC_low, W, A               ; low data byte
    call    SPI1_SendByte

    bsf     LATE, 0, A                  ; CS high (latch output)
    return

