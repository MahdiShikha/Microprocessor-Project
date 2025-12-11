; ============================================================
; File: main.s
; Description: Example main program for AMC131M03 ADC readout
; ============================================================

#include <xc.inc>

extrn	UART_Setup, UART_Transmit_Message, UART_Transmit_Byte
extrn	LCD_Setup, LCD_Write_Hex
extrn	ADC24_Setup, ADC24_Read
extrn	ADC24_H, ADC24_M, ADC24_L

psect	udata_acs
counter:    ds 1
delay_count:ds 1

psect	data
myTable:
	db	'A','D','C','2','4',':',0x0A
myTable_l   EQU	7

psect	code, abs
rst: 	org 0x0
	goto	setup

setup:
	bcf	CFGS
	bsf	EEPGD

	call	UART_Setup
	call	LCD_Setup
	call	ADC24_Setup

	goto	main_loop

; ============================================================
; Continuous measurement loop
; ============================================================
main_loop:
	call	ADC24_Read

	; Display on LCD
	movf	ADC24_H, W, A
	call	LCD_Write_Hex
	movf	ADC24_M, W, A
	call	LCD_Write_Hex
	movf	ADC24_L, W, A
	call	LCD_Write_Hex

	; Transmit to PC via UART
	movf	ADC24_H, W, A
	call	UART_Transmit_Byte
	movf	ADC24_M, W, A
	call	UART_Transmit_Byte
	movf	ADC24_L, W, A
	call	UART_Transmit_Byte

	goto	main_loop

end	rst
