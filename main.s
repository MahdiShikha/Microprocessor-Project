#include <xc.inc>
extrn   SPI1_Init, DAC_WriteWord_16bit,SPI1_SendByte
extrn   DAC_high, DAC_low
extrn	Twelve_bit_to_ten_bit
extrn	LCD_Setup, LCD_Write_Message, LCD_Write_Hex,LCD_Send_Byte_D ; external LCD subroutines
extrn	UART2_Setup, UART2_Receive_12bit
extrn	UART_Setup, UART_Transmit_Byte
extrn	DEC3,DEC2,DEC1,DEC0

psect   code, abs
        org 0x0000
        goto start

        org 0x0100
start:
        call    SPI1_Init
	call	LCD_Setup
	call	UART2_Setup
	call	UART_Setup

        
	movlw   0xFF
        movwf   DAC_high, A
        movlw   0xFF
        movwf   DAC_low, A
loop:	
	movf	DAC_high, W, A
	call	UART_Transmit_Byte  ;loop debugging, send DAC high and low through RC6
				    ;and check the input in RG2
	
	movf	DAC_low, W, A
	call	UART_Transmit_Byte
	
        call    UART2_Receive_12bit ;12bits stored in UART2_H and UART2_L
	
	
	call	Twelve_bit_to_ten_bit
	
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

    
	;call    DAC_WriteWord_16bit
    

        bra    loop

        end 