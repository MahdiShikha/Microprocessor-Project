#include <xc.inc>

extrn	UART_Setup, UART_Transmit_Message  ; external uart subroutines
extrn	LCD_Setup, LCD_Write_Message, LCD_Write_Hex,LCD_Send_Byte_D ; external LCD subroutines
extrn	ADC_Setup, ADC_Read		   ; external ADC subroutines
extrn	Mul16x16,Mul24x8
extrn	ARG1L,ARG1H,ARG2L,ARG2H
extrn	X0,X1,X2,Y0
extrn	RES0,RES1,RES2,RES3	
extrn	ADC_to_4digits
extrn	DEC3,DEC2,DEC1,DEC0
psect	udata_acs   ; reserve data space in access ram
counter:    ds 1    ; reserve one byte for a counter variable
delay_count:ds 1    ; reserve one byte for counter in the delay routine
    
psect	udata_bank4 ; reserve data anywhere in RAM (here at 0x400)
myArray:    ds 0x80 ; reserve 128 bytes for message data


psect	data    
	; ******* myTable, data in programme memory, and its length *****
myTable:
	db	'H','e','l','l','o',' ','W','o','r','l','d','!',0x0a
					; message, plus carriage return
	myTable_l   EQU	13	; length of data
	align	2
    
psect	code, abs	
rst: 	org 0x0
 	goto	setup

	; ******* Programme FLASH read Setup Code ***********************
setup:	bcf	CFGS	; point to Flash program memory  
	bsf	EEPGD 	; access Flash program memory
	call	UART_Setup	; setup UART
	call	LCD_Setup	; setup UART
	call	ADC_Setup	; setup ADC
	goto	start
	
	; ******* Main programme ****************************************
start: 	lfsr	0, myArray	; Load FSR0 with address in RAM	
	movlw	low highword(myTable)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(myTable)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(myTable)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	myTable_l	; bytes to read
	movwf 	counter, A		; our counter register
loop: 	tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loop		; keep going until finished
		
	movlw	myTable_l	; output message to UART
	lfsr	2, myArray
	call	UART_Transmit_Message

	movlw	myTable_l-1	; output message to LCD
				; don't send the final carriage return to LCD
	lfsr	2, myArray
	;call	LCD_Write_Message
;Test_Mul16x16:
;	movlw	0xD2
;	movwf	ARG1L, A
;	movlw	0x04
;	movwf	ARG1H, A
;	
;	movlw	0x8A
;	movwf	ARG2L, A
;	movlw	0x41
;	movwf	ARG2H, A
;	
;	call	Mul16x16
;	movf	RES3, W, A
;	call	LCD_Write_Hex
;	movf	RES2, W, A
;	call	LCD_Write_Hex
;	movf	RES1, W, A
;	call	LCD_Write_Hex
;	movf	RES0, W, A
;	call	LCD_Write_Hex
;	call	delay
;Test_Mul24x8:
;	movlw	0x34
;	movwf	X0, A
;	movlw	0xEB
;	movwf	X1, A
;	movlw	0x3B
;	movwf	X2, A
	
;	movlw	0x0A
;	movwf	Y0,A
;	
;	call	Mul24x8
;	movf	RES3, W, A
;	call	LCD_Write_Hex
;	movf	RES2, W, A
;	call	LCD_Write_Hex
;	movf	RES1, W, A
;	call	LCD_Write_Hex
;	movf	RES0, W, A
;	call	LCD_Write_Hex
;	call	delay
measure_loop:
	call    ADC_Read          ; ADRESH:ADRESL now contain 12-bit code

	call    ADC_to_4digits    ; fills DEC3..DEC0 with digits 0..9

    ; Convert digits to ASCII and print: "d3 d2 d1 d0"
    ; (just as 4 chars; you can insert a decimal point later, e.g. d3 '.' d2 d1 d0)

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

    ; maybe move cursor back or clear, then loop
	goto    measure_loop
;measure_loop:
;	call	ADC_Read
;	movf	ADRESH, W, A
;	call	LCD_Write_Hex
;	movf	ADRESL, W, A
;	call	LCD_Write_Hex
;	goto	measure_loop		; goto current line in code
	
	; a delay subroutine if you need one, times around loop in delay_count
delay:	decfsz	delay_count, A	; decrement until zero
	bra	delay
	return

	end	rst