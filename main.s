#include <xc.inc>
extrn   SPI1_Init, DAC_WriteWord_16bit,SPI1_SendByte,DAC_WriteWord_12bit
extrn	LCD_Setup, LCD_Write_Message, LCD_Write_Hex,LCD_Send_Byte_D ; external LCD subroutines
extrn	ADC_Setup, ADC_Read		   ; external ADC subroutines
extrn	Mul16x16,Mul24x8
extrn	ARG1L,ARG1H,ARG2L,ARG2H
extrn	X0,X1,X2,Y0
extrn	RES0,RES1,RES2,RES3	
extrn	ADC_to_4digits
extrn	DEC3,DEC2,DEC1,DEC0
extrn   DAC_high, DAC_low

psect   code, abs
        org 0x0000
        goto start

        org 0x0100
start:
        ;call    SPI1_Init
	call	LCD_Setup	; setup LCD
	call	ADC_Setup	; setup ADC

	movlw   0x02	;first 4 bits are overwritten by config bits for 12bit send
        ;movwf   DAC_high, A
        movlw   0xFF
       ; movwf   DAC_low, A
loop:	;call    DAC_WriteWord_12bit
    
	call	ADC_Read
	call	ADC_to_4digits
	;call	ADC_Read
	;movf	ADRESH, W, A
	;call	LCD_Write_Hex
	;movf	ADRESL, W, A
	;call	LCD_Write_Hex
	
    ; thousands
	movf    DEC3, W, A
	addlw   '0'
	call    LCD_Send_Byte_D

    ; hundreds
	movf    DEC2, W, A
	addlw   '0'
	call    LCD_Send_Byte_D

    ; tens
	movf    DEC1, W, A
	addlw   '0'
	call    LCD_Send_Byte_D

    ; ones
	movf    DEC0, W, A
	addlw   '0'
	call    LCD_Send_Byte_D
	

        end 