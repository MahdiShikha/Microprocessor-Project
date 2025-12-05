;========================================================
;  main.s ? Plant branch:
;           Vctrl (AN0) -> ADC -> Ak -> ModelPlant -> Yk -> UART
;========================================================

#include <xc.inc>

    ; external routines from other modules
    extrn   Init_Model
    extrn   ModelPlant

    extrn   AkL, AkH
    extrn   YkL, YkH

    extrn   ADC_Setup
    extrn   ADC_Read

    extrn   UART_Setup
    extrn   UART_Transmit_Byte
    
    extrn   LCD_Setup	
    extrn   LCD_Send_Byte_D
    extrn   ADC_to_4digits
    extrn   DEC3,DEC2,DEC1,DEC0

    psect   code, abs
rst:    org 0x0000
        goto    setup

;--------------------------------------------------------
; setup: initialise model, ADC and UART
;--------------------------------------------------------
setup:
        ; world model (alpha, drift, noise, etc.)
        call    Init_Model

        ; on-chip ADC (AN0 = Vctrl)
        call    ADC_Setup

        ; UART for sending Yk over TX1/RC6
        call    UART_Setup
	
	call	LCD_Setup

        goto    MainLoop

;--------------------------------------------------------
; MainLoop:
;   1) Convert Vctrl on AN0 -> ADRESH:ADRESL
;   2) Copy ADC result to AkH:AkL (12-bit right justified)
;   3) Call ModelPlant to compute YkH:YkL
;   4) Send YkH and YkL over UART
;--------------------------------------------------------
MainLoop:
        ; 1) ADC conversion
        call    ADC_Read           ; blocking until conversion completes

        ; 2) Copy 12-bit ADC result to Ak
        ;    ADRESL -> AkL, ADRESH -> AkH
        movff   ADRESL, AkL
        movff   ADRESH, AkH

        ; 3) One world-model step: Ak -> Yk
        call    ModelPlant

        ; 4) Transmit Yk over UART: high byte first, then low byte
	;Header
	movlw	0xFF
	call	UART_Transmit_Byte
	movlw	0xFF
	call	UART_Transmit_Byte
	
        movf    YkH, W, A
        call    UART_Transmit_Byte

        movf    YkL, W, A
        call    UART_Transmit_Byte
	
	call	ADC_to_4digits
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

        bra     MainLoop           ; repeat forever

        end     rst
