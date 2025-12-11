; ============================================================
; File: ADC24.s
; Description: SPI driver for AMC131M03 24-bit ADC (ISO ADC 7 click)
; PIC18F87K22 ? mikroBUS pins:
; CS  = RE0, SCK = RC3, SDI = RC4, SDO = RC5, XEN = RC1, DRDY = RB0
; ============================================================

#include <xc.inc>

global  ADC24_Setup, ADC24_Read
global  ADC24_H, ADC24_M, ADC24_L

psect   udata_acs
ADC24_H:    ds 1      ; 24-bit result MSB
ADC24_M:    ds 1      ; middle byte
ADC24_L:    ds 1      ; LSB

psect   adc24_code, class=CODE

; ============================================================
;  Subroutine: ADC24_Setup
; ============================================================
ADC24_Setup:
    ; ----- Configure SPI and control pins -----
    bcf     TRISE, 0, A     ; RE0 (CS) output
    bcf     TRISC, 1, A     ; RC1 (XEN) output
    bsf     TRISB, 0, A     ; RB0 (DRDY) input
    bcf     TRISC, 3, A     ; RC3 (SCK) output
    bsf     TRISC, 4, A     ; RC4 (SDI) input
    bcf     TRISC, 5, A     ; RC5 (SDO) output

    ; Idle states
    bsf     LATE, 0, A      ; CS high
    bsf     LATC, 1, A      ; XEN high (enable oscillator)

    ; ----- Configure SPI (MSSP1) -----
    ; SPI Master mode, Fosc/16, CKP=0, CKE=1
    movlw   0b00100010
    movwf   SSP1CON1, A
    movlw   0b01000000
    movwf   SSP1STAT, A
    bsf     SSPEN, A        ; enable SPI

    ; ----- Delay for ADC power-up -----
    movlw   d'100'
    call    delay_ms_24adc

    ; ----- Configure AMC131M03 registers -----
    ; Clock Control Register (0x01): CH0 enabled, internal clock, 1 MHz output
    movlw   0x01        ; register address
    movwf   FSR2L, A
    movlw   0x00        ; CH0_EN=1, CLKSEL=internal, OSR=512 (default)
    call    ADC24_Write_Reg

    ; CH0_CFG register (0x03): Gain=1, bipolar, input = AIN0P/AIN0N
    movlw   0x03
    movwf   FSR2L, A
    movlw   0x00
    call    ADC24_Write_Reg

    ; POWER_CFG register (0x05): normal power mode
    movlw   0x05
    movwf   FSR2L, A
    movlw   0x00
    call    ADC24_Write_Reg

    return

; ============================================================
; Subroutine: ADC24_Read
; Waits for DRDY low, then clocks out 3 bytes from ADC
; ============================================================
ADC24_Read:
wait_DRDY:
    btfsc   PORTB, 0, A     ; Wait until RB0 (DRDY) = 0
    bra     wait_DRDY

    bcf     LATE, 0, A      ; CS low
    call    SPI_Read_Byte
    movwf   ADC24_H, A

    call    SPI_Read_Byte
    movwf   ADC24_M, A

    call    SPI_Read_Byte
    movwf   ADC24_L, A

    bsf     LATE, 0, A      ; CS high
    return

; ============================================================
; Helper: Write one configuration register
; Input:  register address in FSR2L, data in W
; ============================================================
ADC24_Write_Reg:
    movwf   PRODH, A        ; Save data byte in PRODH
    bcf     LATE, 0, A      ; CS low

    ; Send write command: 0x40 | (reg addr)
    movf    FSR2L, W, A
    iorlw   0x40
    call    SPI_Write_Byte

    ; Send data byte
    movf    PRODH, W, A
    call    SPI_Write_Byte

    bsf     LATE, 0, A      ; CS high
    return

; ============================================================
; SPI Byte Write
; ============================================================
SPI_Write_Byte:
    movwf   SSP1BUF, A
wait_spi_tx:
    btfss   SSP1STAT, BF
    bra     wait_spi_tx
    movf    SSP1BUF, W, A
    return

; ============================================================
; SPI Byte Read (dummy write)
; ============================================================
SPI_Read_Byte:
    movlw   0x00
    movwf   SSP1BUF, A
wait_spi_rx:
    btfss   SSP1STAT, BF
    bra     wait_spi_rx
    movf    SSP1BUF, W, A
    return

; ============================================================
; Delay (approx ms) for ADC startup
; ============================================================
delay_ms_24adc:
    movwf   TMR0L, A    ; crude wait loop
delay_loop_24adc:
    decfsz  TMR0L, A
    bra     delay_loop_24adc
    return

end
