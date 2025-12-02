#include <xc.inc>
extrn   SPI1_Init, DAC_WriteWord,SPI1_SendByte
extrn   DAC_high, DAC_low
extrn	LCD_Setup, LCD_Write_Message, LCD_Write_Hex,LCD_Send_Byte_D ; external LCD subroutines

psect   code, abs
        org 0x0000
        goto start

        org 0x0100
start:
        call    SPI1_Init
	call	LCD_Setup

        
	movlw   0xFF
        movwf   DAC_high, A
        movlw   0xFF
        movwf   DAC_low, A
loop:	call    DAC_WriteWord
    

        bra    loop

        end 