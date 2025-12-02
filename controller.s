;========================================================

;  controller.s ? FSM + SCAN (triangle) + PI LOCK (BODE stub)

;========================================================



#include <xc.inc>



        global  Init_Controller

        global  Controller_Step



        global  D_ctrlL, D_ctrlH

        global  CtrlMode



        global  YkL, YkH

        global  Y_targetL, Y_targetH



        global  YpeakL, YpeakH

        global  D_at_YpeakL, D_at_YpeakH



;--------------------------------------------------------

; Data in ACCESS RAM

;--------------------------------------------------------

        psect   udata_acs



; main control word for DAC (12-bit)

D_ctrlL:        ds  1

D_ctrlH:        ds  1



; mode: 0=SCAN, 1=LOCK, 2=BODE

CtrlMode:       ds  1



; scan limit

DmaxL:          ds  1

DmaxH:          ds  1



; scan direction: 0 = up, 1 = down

ScanDir:        ds  1



; measurement from plant

YkL:            ds  1

YkH:            ds  1



; lock target level

Y_targetL:      ds  1

Y_targetH:      ds  1



; peak tracking during SCAN (optional)

YpeakL:         ds  1

YpeakH:         ds  1

D_at_YpeakL:    ds  1

D_at_YpeakH:    ds  1



; button + LEDs

BtnPrev:        ds  1

TmpBtn:         ds  1



; PI controller state

ErrL:           ds  1        ; error e[k]

ErrH:           ds  1

IntL:           ds  1        ; integral I[k]

IntH:           ds  1



PtermL:         ds  1        ; proportional term

PtermH:         ds  1

IincL:          ds  1        ; Ki*Err increment

IincH:          ds  1

CorrL:          ds  1        ; total correction = P + I

CorrH:          ds  1



; lock base point

D_baseL:        ds  1

D_baseH:        ds  1



; PI gains: K = Num / 2^Shift

KpNum:          ds  1

KpShift:        ds  1

KiNum:          ds  1

KiShift:        ds  1



ShiftCnt:       ds  1        ; for shifts

MulCnt:         ds  1        ; for multiplications



;--------------------------------------------------------

; Constants

;--------------------------------------------------------

        psect   controller_consts, class=CODE



STATE_SCAN      equ 0

STATE_LOCK      equ 1

STATE_BODE      equ 2



;========================================================

; Init_Controller

;========================================================

        psect   controller_code, class=CODE



Init_Controller:

        ; D_ctrl = 0

        clrf    D_ctrlL, A

        clrf    D_ctrlH, A



        ; initial mode = SCAN

        movlw   STATE_SCAN

        movwf   CtrlMode, A



        ; Dmax = 0x0FFF (12-bit full scale)

        movlw   0xFF

        movwf   DmaxL, A

        movlw   0x0F

        movwf   DmaxH, A



        ; ScanDir = up (0)

        clrf    ScanDir, A



        ; clear measurement / peak / base

        clrf    YkL, A

        clrf    YkH, A

        clrf    YpeakL, A

        clrf    YpeakH, A

        clrf    D_at_YpeakL, A

        clrf    D_at_YpeakH, A



        clrf    D_baseL, A

        clrf    D_baseH, A



        ; clear PI state

        clrf    ErrL, A

        clrf    ErrH, A

        clrf    IntL, A

        clrf    IntH, A

        clrf    PtermL, A

        clrf    PtermH, A

        clrf    IincL, A

        clrf    IincH, A

        clrf    CorrL, A

        clrf    CorrH, A



        ; default Y_target (will be overwritten when entering LOCK)

        movlw   0xD0

        movwf   Y_targetL, A

        movlw   0x07

        movwf   Y_targetH, A



        ; PI gains: K = Num / 2^Shift

        ; example: Kp = 2/8 = 0.25, Ki = 1/64 ? 0.016

        movlw   2

        movwf   KpNum, A

        movlw   3

        movwf   KpShift, A



        movlw   1

        movwf   KiNum, A

        movlw   6

        movwf   KiShift, A



        ; RB0 input (button), RD0..2 outputs (mode LEDs)

        bsf     TRISB, 0, A

        bcf     TRISD, 0, A

        bcf     TRISD, 1, A

        bcf     TRISD, 2, A



        ; read initial button state

        movf    PORTB, W, A

        andlw   0x01

        movwf   BtnPrev, A



        ; set LEDs for initial mode

        call    UpdateModeLED



        return



;========================================================

; Controller_Step

;========================================================

Controller_Step:

        ; handle button and potential mode changes

        call    UpdateModeFromButton



        ; dispatch by CtrlMode

        movf    CtrlMode, W, A

        xorlw   STATE_SCAN

        btfsc   STATUS, 2, A

        bra     CS_DoScan



        movf    CtrlMode, W, A

        xorlw   STATE_LOCK

        btfsc   STATUS, 2, A

        bra     CS_DoLock



        movf    CtrlMode, W, A

        xorlw   STATE_BODE

        btfsc   STATUS, 2, A

        bra     CS_DoBode



        ; fallback

        movlw   STATE_SCAN

        movwf   CtrlMode, A

        bra     CS_DoScan



;--------------------------------------------------------

; SCAN mode: triangle D_ctrl from 0 up to Dmax and back

;   ScanDir = 0: ramp up

;   ScanDir = 1: ramp down

;--------------------------------------------------------

CS_DoScan:

        ; check ScanDir

        movf    ScanDir, W, A

        andlw   0x01

        btfsc   STATUS, 2, A      ; Z=1 -> ScanDir == 0 (up)

        bra     CS_Scan_Up



        ;----------------------

        ; ScanDir == 1 : down

        ;----------------------

CS_Scan_Down:

        ; if D_ctrl == 0 -> flip direction to up, no change this cycle

        movf    D_ctrlL, W, A

        iorwf   D_ctrlH, W, A

        btfsc   STATUS, 2, A      ; Z=1 -> D_ctrl == 0

        bra     CS_Scan_DownFlip



        ; D_ctrl > 0 -> D_ctrl = D_ctrl - 1 (16-bit)

        movlw   0x01

        subwf   D_ctrlL, F, A

        movlw   0x00

        subwfb  D_ctrlH, F, A

        bra     CS_Scan_AfterStep



CS_Scan_DownFlip:

        ; reached bottom, switch to up

        clrf    ScanDir, A        ; 0 = up

        bra     CS_Scan_AfterStep



        ;----------------------

        ; ScanDir == 0 : up

        ;----------------------

CS_Scan_Up:

        ; D_ctrl++ (16-bit)

        incf    D_ctrlL, F, A

        btfsc   STATUS, 0, A      ; C bit

        incf    D_ctrlH, F, A



        ; if D_ctrl > Dmax -> clamp to Dmax and switch direction to down

        movf    D_ctrlH, W, A

        subwf   DmaxH, W, A       ; W = DmaxH - D_ctrlH

        btfss   STATUS, 0, A      ; C=0 -> D_ctrlH > DmaxH

        bra     CS_Scan_UpClamp



        movf    D_ctrlH, W, A

        xorwf   DmaxH, W, A

        btfss   STATUS, 2, A      ; high bytes differ

        bra     CS_Scan_AfterStep



        movf    D_ctrlL, W, A

        subwf   DmaxL, W, A       ; W = DmaxL - D_ctrlL

        btfss   STATUS, 0, A      ; C=0 -> D_ctrlL > DmaxL

        bra     CS_Scan_UpClamp



        bra     CS_Scan_AfterStep



CS_Scan_UpClamp:

        movff   DmaxL, D_ctrlL

        movff   DmaxH, D_ctrlH

        movlw   1

        movwf   ScanDir, A        ; 1 = down



CS_Scan_AfterStep:

        ; optional: track peak during scan

        call    CS_UpdatePeakFromY

        return



;--------------------------------------------------------

; LOCK mode: PI controller (DC-lock)

;--------------------------------------------------------

CS_DoLock:

        ; 1) Err = Y_target - Yk

        movff   Y_targetL, ErrL

        movff   Y_targetH, ErrH



        movf    YkL, W, A

        subwf   ErrL, F, A

        movf    YkH, W, A

        subwfb  ErrH, F, A



        ; 2) Pterm = Kp * Err

        call    Scale_Err_Kp      ; PtermH:L



        ; 3) Iinc = Ki * Err, Int += Iinc

        call    Scale_Err_Ki      ; IincH:L



        movf    IincL, W, A

        addwf   IntL, F, A

        movf    IincH, W, A

        addwfc  IntH, F, A



        ; (optional: anti-windup could clamp Int here)



        ; 4) Corr = Pterm + Int

        movff   PtermL, CorrL

        movff   PtermH, CorrH



        movf    IntL, W, A

        addwf   CorrL, F, A

        movf    IntH, W, A

        addwfc  CorrH, F, A



        ; 5) D_ctrl = D_base + Corr, with clamp to 0..0x0FFF

        movff   D_baseL, D_ctrlL

        movff   D_baseH, D_ctrlH



        movf    CorrL, W, A

        addwf   D_ctrlL, F, A

        movf    CorrH, W, A

        addwfc  D_ctrlH, F, A



        ; clamp high nibble > 0x0F -> 0x0FFF

        movf    D_ctrlH, W, A

        andlw   0xF0

        btfss   STATUS, 2, A

        bra     PI_Clamp_High



        ; if negative (sign bit set), clamp to 0

        movf    D_ctrlH, W, A

        andlw   0x80

        btfss   STATUS, 2, A

        bra     PI_Clamp_Zero



        bra     PI_Done



PI_Clamp_High:

        movlw   0x0F

        movwf   D_ctrlH, A

        movlw   0xFF

        movwf   D_ctrlL, A

        bra     PI_Done



PI_Clamp_Zero:

        clrf    D_ctrlL, A

        clrf    D_ctrlH, A



PI_Done:

        return



;--------------------------------------------------------

; BODE mode: placeholder for future frequency-response logic

;--------------------------------------------------------

CS_DoBode:

        return



;--------------------------------------------------------

; UpdateModeFromButton: RB0 press -> next mode

;   0 -> 1 -> 2 -> 0

;   On entering SCAN: reset scan and peak

;   On entering LOCK: snapshot D_ctrl and Yk

;--------------------------------------------------------

UpdateModeFromButton:

        ; read current button

        movf    PORTB, W, A

        andlw   0x01

        movwf   TmpBtn, A        ; Now



        ; Prev in BtnPrev

        movf    BtnPrev, W, A

        andlw   0x01

        btfsc   STATUS, 2, A     ; Prev = 0?

        bra     UMB_NoPress      ; only look for 1->0



        ; Prev=1, Now=0 -> press

        movf    TmpBtn, W, A

        andlw   0x01

        btfsc   STATUS, 2, A     ; Now=0?

        bra     UMB_Press



        bra     UMB_NoPress



UMB_Press:

        ; CtrlMode = (CtrlMode + 1) mod 3

        incf    CtrlMode, F, A

        movf    CtrlMode, W, A

        andlw   0x03

        xorlw   0x03

        btfss   STATUS, 2, A

        bra     UMB_ModeOk

        clrf    CtrlMode, A



UMB_ModeOk:

        ; if new mode is SCAN, reset D_ctrl, scan dir and peak info

        movf    CtrlMode, W, A

        xorlw   STATE_SCAN

        btfss   STATUS, 2, A

        bra     UMB_CheckLock



        clrf    D_ctrlL, A

        clrf    D_ctrlH, A

        clrf    ScanDir, A           ; start going up again



        clrf    YpeakL, A

        clrf    YpeakH, A

        clrf    D_at_YpeakL, A

        clrf    D_at_YpeakH, A



        bra     UMB_UpdateLED



UMB_CheckLock:

        ; if new mode is LOCK, snapshot base and target

        movf    CtrlMode, W, A

        xorlw   STATE_LOCK

        btfss   STATUS, 2, A

        bra     UMB_UpdateLED



        ; 1) snapshot current D_ctrl as D_base

        movff   D_ctrlL, D_baseL

        movff   D_ctrlH, D_baseH



        ; 2) snapshot current Yk as Y_target

        movff   YkL, Y_targetL

        movff   YkH, Y_targetH



        ; 3) clear integral

        clrf    IntL, A

        clrf    IntH, A



UMB_UpdateLED:

        call    UpdateModeLED



UMB_NoPress:

        movf    TmpBtn, W, A

        movwf   BtnPrev, A

        return



;--------------------------------------------------------

; UpdateModeLED: RD0=SCAN, RD1=LOCK, RD2=BODE

;--------------------------------------------------------

UpdateModeLED:

        bcf     LATD, 0, A

        bcf     LATD, 1, A

        bcf     LATD, 2, A



        movf    CtrlMode, W, A

        xorlw   STATE_SCAN

        btfsc   STATUS, 2, A

        bsf     LATD, 0, A



        movf    CtrlMode, W, A

        xorlw   STATE_LOCK

        btfsc   STATUS, 2, A

        bsf     LATD, 1, A



        movf    CtrlMode, W, A

        xorlw   STATE_BODE

        btfsc   STATUS, 2, A

        bsf     LATD, 2, A



        return



;--------------------------------------------------------

; CS_UpdatePeakFromY: unsigned peak tracking during SCAN

;--------------------------------------------------------

CS_UpdatePeakFromY:

        ; compare Yk and Ypeak (unsigned 16-bit)

        movf    YkH, W, A

        subwf   YpeakH, W, A     ; W = YpeakH - YkH

        btfss   STATUS, 0, A     ; C=0 -> YkH > YpeakH

        bra     CUP_NewPeak



        movf    YkH, W, A

        xorwf   YpeakH, W, A

        btfss   STATUS, 2, A     ; high bytes differ

        bra     CUP_End



        movf    YkL, W, A

        subwf   YpeakL, W, A     ; W = YpeakL - YkL

        btfss   STATUS, 0, A     ; C=0 -> YkL > YpeakL

        bra     CUP_NewPeak



        bra     CUP_End



CUP_NewPeak:

        movff   YkL, YpeakL

        movff   YkH, YpeakH

        movff   D_ctrlL, D_at_YpeakL

        movff   D_ctrlH, D_at_YpeakH



CUP_End:

        return



;--------------------------------------------------------

; Scale_Err_Kp: Pterm = (KpNum * Err) >> KpShift  (signed)

;   Inputs: ErrH:L, KpNum, KpShift

;   Output: PtermH:L

;--------------------------------------------------------

Scale_Err_Kp:

        clrf    PtermL, A

        clrf    PtermH, A



        movf    KpNum, W, A

        movwf   MulCnt, A

        movf    MulCnt, F, A

        btfsc   STATUS, 2, A

        bra     SEKp_Shift       ; Num==0



SEKp_MulLoop:

        movf    ErrL, W, A

        addwf   PtermL, F, A

        movf    ErrH, W, A

        addwfc  PtermH, F, A



        decfsz  MulCnt, F, A

        bra     SEKp_MulLoop



SEKp_Shift:

        movf    KpShift, W, A

        movwf   ShiftCnt, A



SEKp_ShiftLoop:

        movf    ShiftCnt, F, A

        btfsc   STATUS, 2, A

        bra     SEKp_Done



        ; arithmetic right shift PtermH:L

        bcf     STATUS, 0, A

        movf    PtermH, W, A

        andlw   0x80

        btfss   STATUS, 2, A

        bsf     STATUS, 0, A



        rrcf    PtermH, F, A

        rrcf    PtermL, F, A



        decfsz  ShiftCnt, F, A

        bra     SEKp_ShiftLoop



SEKp_Done:

        return



;--------------------------------------------------------

; Scale_Err_Ki: Iinc = (KiNum * Err) >> KiShift  (signed)

;   Inputs: ErrH:L, KiNum, KiShift

;   Output: IincH:L

;--------------------------------------------------------

Scale_Err_Ki:

        clrf    IincL, A

        clrf    IincH, A



        movf    KiNum, W, A

        movwf   MulCnt, A

        movf    MulCnt, F, A

        btfsc   STATUS, 2, A

        bra     SEKi_Shift       ; Num==0



SEKi_MulLoop:

        movf    ErrL, W, A

        addwf   IincL, F, A

        movf    ErrH, W, A

        addwfc  IincH, F, A



        decfsz  MulCnt, F, A

        bra     SEKi_MulLoop



SEKi_Shift:

        movf    KiShift, W, A

        movwf   ShiftCnt, A



SEKi_ShiftLoop:

        movf    ShiftCnt, F, A

        btfsc   STATUS, 2, A

        bra     SEKi_Done



        ; arithmetic right shift IincH:L

        bcf     STATUS, 0, A

        movf    IincH, W, A

        andlw   0x80

        btfss   STATUS, 2, A

        bsf     STATUS, 0, A



        rrcf    IincH, F, A

        rrcf    IincL, F, A



        decfsz  ShiftCnt, F, A

        bra     SEKi_ShiftLoop



SEKi_Done:

        return



