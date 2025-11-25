#include <xc.inc>
extrn   SPI1_Init, DAC_WriteWord,SPI1_SendByte
extrn   DAC_high, DAC_low

psect   code, abs
        org 0x0000
        goto start

        org 0x0100
start:
        call    SPI1_Init

        ; Example 1: mid-scale (~0.5 * Vref) 
	movlw   0x40
	;call	SPI1_SendByte
        movwf   DAC_high, A
        movlw   0x40
        movwf   DAC_low, A
loop:	call    DAC_WriteWord

        bra    loop

        end 