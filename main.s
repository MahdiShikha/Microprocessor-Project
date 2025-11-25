#include <xc.inc>

extrn	UART_Setup, UART_Transmit_Message  ; external subroutines
extrn	LCD_Setup, LCD_Write_Message,LCD_Clear,LCD_GotoRow2,LCD_GotoRow1,LCD_Puts_PM,LCD_Send_Byte_D
	
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
line1:     
	db 'Hello World',0
	line1_len  EQU 13	
   align	2
    
psect	code, abs	
rst: 	org 0x0
 	goto	setup

	; ******* Programme FLASH read Setup Code ***********************
setup:	bcf	CFGS	; point to Flash program memory  
	bsf	EEPGD 	; access Flash program memory
	call	UART_Setup	; setup UART
	call	LCD_Setup	; setup UART
	goto	start
	
	; ******* Main programme ****************************************
start: 	;lfsr	0, myArray	; Load FSR0 with address in RAM	
	movlw	low highword(myTable)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(myTable)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(myTable)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	myTable_l	; bytes to read
	movwf 	counter, A		; our counter register
	  ; ------- Row1: col=0, print "Hello World" -------
	; ===== Row1, col = 0 =====
	movlw   0
	call    LCD_GotoRow1            ; set DDRAM address to row 1, column 0

    ; --- Loop count N = myTable_l - 1 (skip trailing 0x0A for LCD) ---
	movlw   myTable_l
	addlw   0xFF                    ; W = len - 1
	movwf   counter, A              ; reuse existing counter byte

LCD_PM_Row1:
	tblrd*+                         ; FLASH[TBLPTR] -> TABLAT, then TBLPTR++
	movf    TABLAT, W, A            ; W = byte just read from PM
	call    LCD_Send_Byte_D         ; send data byte (RS=1) in 4-bit mode
	decfsz  counter, A              ; N-- ; done?
	bra     LCD_PM_Row1             ; loop until all bytes sent
    ; ===== Row2, col = 0 =====
	movlw   0
	call    LCD_GotoRow2            ; set DDRAM address to row 2, column 0

    ; --- Rewind TBLPTR back to start of message in PM ---
	movlw   low  highword(myTable)
	movwf   TBLPTRU, A
	movlw   high myTable
	movwf   TBLPTRH, A
	movlw   low  myTable
	movwf   TBLPTRL, A

	movlw   myTable_l
	addlw   0xFF                    ; W = len - 1 (again skip 0x0A)
	movwf   counter, A

LCD_PM_Row2:
	tblrd*+                         ; read next PM byte to TABLAT, TBLPTR++
	movf    TABLAT, W, A            ; W = byte from PM
	call    LCD_Send_Byte_D         ; write data byte to LCD
	decfsz  counter, A
	bra     LCD_PM_Row2             ; loop for all bytes

;loop: 	tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
;	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
;	decfsz	counter, A		; count down to zero
;	bra	loop		; keep going until finished
;		
;	movlw	myTable_l	; output message to UART
;	lfsr	2, myArray
;	call	UART_Transmit_Message
;
;	call	LCD_GotoRow2	; Called before output message to LCD method 
;	movlw	myTable_l	; output message to LCD
;	addlw	0xff		; don't send the final carriage return to LCD
;	lfsr	2, myArray
	
	
;	call	LCD_Write_Message
	;call	LCD_Clear

;	goto	$		; goto current line in code

	; a delay subroutine if you need one, times around loop in delay_count
delay:	decfsz	delay_count, A	; decrement until zero
	bra	delay
	return

	end	rst