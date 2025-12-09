;=============================

; main.s  (controller PIC)

;=============================

#include <xc.inc>



; ---- extern symbols ----

extrn  DAC_Setup

extrn  Timer_Int_Hi



extrn  UART1_Setup

extrn  UART1_Receive_12bit

extrn  UART1_Transmit_Byte

extrn  UART1_H, UART1_L



extrn  Init_Controller

extrn  YkL, YkH

extrn  CtrlMode

extrn  D_prevL, D_prevH     ; from controller_A.s



; ---------------- CODE ----------------

psect   resetVec, class=CODE, abs

resetVec:

        org     0x0000

        goto    start



psect   highIntVec, class=CODE, abs

highIntVec:

        org     0x0008

        goto    Timer_Int_Hi



;-------------------------------

; main entry

;-------------------------------

psect   main_code, class=CODE



start:

        ; 1) DAC + Timer0 interrupt

        call    DAC_Setup



        ; 2) UART1: RX from model PIC, TX to PC

        call    UART1_Setup



        ; 3) Controller init (FSM + PI etc.)

        call    Init_Controller



;-------------------------------

; main loop

;   - receive Yk(k) from model PIC via UART1_RX

;   - copy to YkH:YkL

;   - send frame to PC via UART1_TX:

;       [0xFF, 0xFF, CtrlMode, YkH, YkL, D_prevH, D_prevL]

;   - Timer0 interrupt keeps running Controller_Step + DAC

;-------------------------------

main_loop:

        ; 1) receive Yk (16-bit) from model PIC

        call    UART1_Receive_12bit

        movff   UART1_H, YkH

        movff   UART1_L, YkL



        ; 2) send one frame to PC:

        ;    [0xFF, 0xFF, CtrlMode, YkH, YkL, D_prevH, D_prevL]

        movlw   0xFF

        call    UART1_Transmit_Byte



        ; ---- Yk(k) ----

        movf    YkH, W, A

        call    UART1_Transmit_Byte

        movf    YkL, W, A

        call    UART1_Transmit_Byte



        ; ---- D_prev = D_ctrl(k-1) ----

        movf    D_prevH, W, A

        call    UART1_Transmit_Byte

        movf    D_prevL, W, A

        call    UART1_Transmit_Byte



        bra     main_loop



        end     resetVec


