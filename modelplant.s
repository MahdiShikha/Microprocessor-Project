;======================================================== 
;  modelplant.s  - World model with adjustable alpha,
;                  drift (random walk) and noise
;
;  i_base = (AlphaNum * Ak) >> AlphaShift
;  i      = i_base + d
;  index  = i mod 2048           ; N_LUT = 2048
;  Yk     = FP_LUT_TABLE[index] + noise_y
;  d is updated every DriftDiv control cycles:
;           d = d + DriftSpeed + noise_d
;
;  Notes:
;    - If alpha = 1  -> i_base = Ak
;    - FP_LUT stores values 0..3000 (approx 12-bit peak)
;    - Final Y will be clipped to 0..4095 (12-bit), not 0xFFFF
;========================================================

#include <xc.inc>
#include "FP_LUT.inc" 

        global  Init_Model
        global  ModelPlant
        global  AkL, AkH
        global  dL, dH
        global  YkL, YkH
        global  AlphaNum, AlphaShift
        global  DriftSpeedL, DriftSpeedH
        global  Tmp_L, Tmp_H
        global  I_L, I_H
        global  IdxL, IdxH

        ; Parameters and state related to drift
        global  DriftDiv
        global  DriftTick
        global  Rand

;--------------------------------------------------------
; Data in ACCESS RAM
;--------------------------------------------------------
        psect   udata_acs

AkL:            ds  1      ; ADC low byte
AkH:            ds  1      ; ADC high byte (only low 4 bits used)

dL:             ds  1      ; drift low byte
dH:             ds  1      ; drift high byte

YkL:            ds  1      ; model output low byte
YkH:            ds  1      ; model output high byte

AlphaNum:       ds  1      ; M   in alpha = M / 2^S
AlphaShift:     ds  1      ; S   in alpha = M / 2^S

DriftSpeedL:    ds  1      ; drift increment low byte (per update)
DriftSpeedH:    ds  1      ; drift increment high byte

Tmp_L:          ds  1      ; temp: i_base / i low
Tmp_H:          ds  1      ; temp: i_base / i high

IdxL:           ds  1      ; index low (bits 7..0)
IdxH:           ds  1      ; index high bits (bits 10..8 in bit0..2)

I_L:            ds  1      ; accumulator low for M*Ak
I_H:            ds  1      ; accumulator high
Cnt:            ds  1      ; loop counter

DriftDiv:       ds  1      ; how many cycles between drift updates
DriftTick:      ds  1      ; drift cycle counter

Rand:           ds  1      ; 8-bit pseudo-random state

;--------------------------------------------------------
; Noise tables
;--------------------------------------------------------
        psect   noise_tables, class=CODE

; Measurement noise table for Y:
; index = Rand & 0x07 (0..7)
; 8-bit signed values:
;   0x00 =  0
;   0x01 = +1
;   0xFF = -1
NoiseTable_Y:
        db  -1      ; 0: -1
        db   1      ; 1: +1
        db   0      ; 2:  0
        db   0      ; 3:  0
        db  -1      ; 4: -1
        db   1      ; 5: +1
        db   0      ; 6:  0
        db   1      ; 7: +1

; Drift noise table for d:
; index = Rand & 0x07
; small signed steps for drift random walk
NoiseTable_D:
        db   1      ; 0: +1
        db  -1      ; 1: -1
        db   1      ; 2: +1
        db   0      ; 3:  0
        db  -1      ; 4: -1
        db   1      ; 5: +1
        db   0      ; 6:  0
        db   0      ; 7:  0

;--------------------------------------------------------
; Code
;--------------------------------------------------------
        psect   modelplant_code, class=CODE

;--------------------------------------------------------
; Init_Model
;   Sets alpha = 1 (M=1, S=0) and drift = 0
;   For drift: about 1 index step per ~50 cycles
;--------------------------------------------------------
Init_Model:
        ; alpha = 1 -> i_base = Ak
        movlw   1
        movwf   AlphaNum, A      ; M = 1

        movlw   2
        movwf   AlphaShift, A    ; S = 0 -> >>0

        ; drift state = 0
        clrf    dL, A
        clrf    dH, A

        ; drift speed = +1 index per update
        movlw   0
        movwf   DriftSpeedL, A
        clrf    DriftSpeedH, A

        ; Drift: update roughly every 50 cycles
        movlw   100000
        movwf   DriftDiv, A
        clrf    DriftTick, A

        ; Rand initial seed
        movlw   0x5A
        movwf   Rand, A

        return

;--------------------------------------------------------
; Scale_Ak_to_i_base
;   i_base = (AlphaNum * Ak) >> AlphaShift
;   Inputs:  AkH:AkL, AlphaNum, AlphaShift
;   Outputs: Tmp_H:Tmp_L = i_base
;--------------------------------------------------------
Scale_Ak_to_i_base:

        ; I = 0
        clrf    I_L, A
        clrf    I_H, A

        ; Cnt = AlphaNum (M)
        movf    AlphaNum, W, A
        movwf   Cnt, A

        ; If M == 0 then i_base = 0 (skip multiply and shift)
        movf    Cnt, F, A
        btfsc   STATUS, 2, A     ; Z=1 if M==0
        bra     SA_DoneMul

SA_MulLoop:
        ; I += Ak  (16-bit add)
        movf    AkL, W, A
        addwf   I_L, F, A
        movf    AkH, W, A
        addwfc  I_H, F, A

        decfsz  Cnt, F, A
        bra     SA_MulLoop

SA_DoneMul:
        ; Cnt = AlphaShift (S)
        movf    AlphaShift, W, A
        movwf   Cnt, A

        ; If S == 0, skip shifting
        movf    Cnt, F, A
        btfsc   STATUS, 2, A     ; Z=1 if S==0
        bra     SA_DoneShift

SA_ShiftLoop:
        ; Arithmetic right shift: I >>= 1
        bcf     STATUS, 0, A     ; C = 0 before rrcf chain
        rrcf    I_H, F, A
        rrcf    I_L, F, A

        decfsz  Cnt, F, A
        bra     SA_ShiftLoop

SA_DoneShift:
        ; Copy I into Tmp_H:Tmp_L as i_base
        movff   I_L, Tmp_L
        movff   I_H, Tmp_H

        return

;--------------------------------------------------------

;--------------------------------------------------------
; UpdateRand
;   Simple 8-bit pseudo-random update
;--------------------------------------------------------
UpdateRand:
        movf    Rand, W, A
        addlw   0x33
        movwf   Rand, A
        return

;--------------------------------------------------------
; Add_Y_Noise
;   Uses Rand & 0x07 as index into NoiseTable_Y
;   Adds (-1, 0, or +1) to Yk, with clipping at 0
;   FP LUT peak is around 3000, so +/-1 is very small
;--------------------------------------------------------
Add_Y_Noise:
        ; Rand is updated in ModelPlant before Y-noise
        movf    Rand, W, A
        andlw   0x07
        movwf   Tmp_L, A          ; Tmp_L = index 0..7

        ; TBLPTR = NoiseTable_Y + index
        movlw   low highword(NoiseTable_Y)
        movwf   TBLPTRU, A
        movlw   high(NoiseTable_Y)
        movwf   TBLPTRH, A
        movlw   low(NoiseTable_Y)
        movwf   TBLPTRL, A

        movf    Tmp_L, W, A
        addwf   TBLPTRL, F, A

        ; Read 1 byte noise sample
        tblrd*
        movf    TABLAT, W, A
        movwf   Tmp_L, A          ; Tmp_L = noise (0,1,0xFF)

        ; If noise == 0, nothing to do
        movf    Tmp_L, F, A
        btfsc   STATUS, 2, A      ; Z=1 if 0
        bra     AYN_End

        ; Distinguish +1 vs -1:
        ;  0x01 = +1, 0xFF = -1
        movf    Tmp_L, W, A
        xorlw   0x01
        btfsc   STATUS, 2, A
        bra     AYN_Plus1

        ; Otherwise interpret as -1
        bra     AYN_Minus1

AYN_Plus1:
        ; Yk = Yk + 1 (16-bit, no upper bound check here)
        incf    YkL, F, A
        btfsc   STATUS, 0, A      ; C=1 if low byte overflowed
        incf    YkH, F, A
        bra     AYN_End

AYN_Minus1:
        ; Yk = max(Yk - 1, 0)
        movf    YkL, W, A
        iorwf   YkH, W, A
        btfsc   STATUS, 2, A      ; Z=1 if Yk == 0
        bra     AYN_End           ; already at 0

        decf    YkL, F, A
        btfss   STATUS, 0, A      ; C=0 if borrow from high byte
        decf    YkH, F, A

AYN_End:
        return

;--------------------------------------------------------
; Add_Drift_Noise
;   Uses Rand & 0x07 as index into NoiseTable_D
;   Adds (-1, 0, or +1) to dL:dH (no wrap handling here)
;--------------------------------------------------------
Add_Drift_Noise:
        movf    Rand, W, A
        andlw   0x07
        movwf   Tmp_L, A          ; index 0..7

        movlw   low highword(NoiseTable_D)
        movwf   TBLPTRU, A
        movlw   high(NoiseTable_D)
        movwf   TBLPTRH, A
        movlw   low(NoiseTable_D)
        movwf   TBLPTRL, A

        movf    Tmp_L, W, A
        addwf   TBLPTRL, F, A

        tblrd*
        movf    TABLAT, W, A
        movwf   Tmp_L, A          ; Tmp_L = noise (0,1,0xFF)

        ; If 0, do nothing
        movf    Tmp_L, F, A
        btfsc   STATUS, 2, A
        bra     ADN_End

        ; If 1, add +1
        movf    Tmp_L, W, A
        xorlw   0x01
        btfsc   STATUS, 2, A
        bra     ADN_Plus1

        ; Otherwise treat as -1 (0xFF)
        bra     ADN_Minus1

ADN_Plus1:
        incf    dL, F, A
        btfsc   STATUS, 0, A
        incf    dH, F, A
        bra     ADN_End

ADN_Minus1:
        decf    dL, F, A
        btfss   STATUS, 0, A
        decf    dH, F, A

ADN_End:
        return

;--------------------------------------------------------
; ModelPlant
;   Full world model:
;     - scale Ak to i_base
;     - add drift to get i
;     - map to LUT index and read FP fringe
;     - add measurement noise to Yk
;     - update drift state with drift speed and noise
;--------------------------------------------------------
ModelPlant:

        ; 1) i_base = (AlphaNum * Ak) >> AlphaShift
        call    Scale_Ak_to_i_base      ; Tmp_H:Tmp_L = i_base

        ; 2) i = i_base + d  (16-bit)
        movf    dL, W, A
        addwf   Tmp_L, F, A
        movf    dH, W, A
        addwfc  Tmp_H, F, A
        ; Tmp_H:Tmp_L = i

        ; 3) index = i mod 2048 (use only 11 bits)
        ;    IdxL = i[7..0], IdxH = i[10..8]
        movf    Tmp_L, W, A
        movwf   IdxL, A

        movf    Tmp_H, W, A
        andlw   0x07                ; keep bit0..2 as high index bits
        movwf   IdxH, A

        ; 4) offset_bytes = index * 2 (16-bit: value << 1)
        movf    IdxL, W, A
        addwf   IdxL, F, A          ; IdxL = IdxL + IdxL
        movf    IdxH, W, A
        addwfc  IdxH, F, A          ; IdxH = IdxH + IdxH + C

        ; 5) TBLPTR = FP_LUT_TABLE + offset_bytes
        movlw   low highword(FP_LUT_TABLE)
        movwf   TBLPTRU, A
        movlw   high(FP_LUT_TABLE)
        movwf   TBLPTRH, A
        movlw   low(FP_LUT_TABLE)
        movwf   TBLPTRL, A

        movf    IdxL, W, A
        addwf   TBLPTRL, F, A
        movf    IdxH, W, A
        addwfc  TBLPTRH, F, A

        ; 6) Read LUT 16-bit value into Yk
        tblrd*+
        movf    TABLAT, W, A
        movwf   YkL, A

        tblrd*
        movf    TABLAT, W, A
        movwf   YkH, A

        ; 7) Measurement noise: update Rand and perturb Yk
        call    UpdateRand
        call    Add_Y_Noise

        ; 8) Drift update every DriftDiv cycles
        incf    DriftTick, F, A
        movf    DriftTick, W, A
        xorwf   DriftDiv, W, A
        btfss   STATUS, 2, A       ; Z=1 when DriftTick == DriftDiv
        bra     MP_Return          ; not yet time to update drift

        ; Reset DriftTick
        clrf    DriftTick, A

        ; 8a) Add DriftSpeed to drift state
        movf    DriftSpeedL, W, A
        addwf   dL, F, A
        movf    DriftSpeedH, W, A
        addwfc  dH, F, A

        ; 8b) Add random drift noise using Rand and NoiseTable_D
        call    UpdateRand
        call    Add_Drift_Noise

MP_Return:
        return



