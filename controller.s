;========================================================

;  controller_A.s – FSM + SCAN + PI LOCK + BODE (locked)

;========================================================



#include <xc.inc>

#include "SINLUT.inc"



        global  Init_Controller

        global  Controller_Step



        global  D_ctrlL, D_ctrlH

        global  D_prevL, D_prevH    

        global  CtrlMode



        global  YkL, YkH

        global  Y_targetL, Y_targetH



        global  YpeakL, YpeakH

        global  D_at_YpeakL, D_at_YpeakH





;--------------------------------------------------------

; Data in ACCESS RAM

;--------------------------------------------------------

        psect   udata_acs



; main control word for DAC (logical 12-bit: 0..0xFFFF)

D_ctrlL:        ds  1

D_ctrlH:        ds  1

    

; previous control word (for logging)

D_prevL:        ds  1         

D_prevH:        ds  1       

    

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



; peak tracking during SCAN

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



    ; LOCK internal state

LockState:      ds  1        ; 0=SEARCH, 1=PROBE, 2=MEAS, 3=TRACK

LockSide:       ds  1        ; 0=LEFT slope, 1=RIGHT slope

Y_lockBaseL:    ds  1        ; Y at base point (low)

Y_lockBaseH:    ds  1        ; Y at base point (high)



; temporaries for math

TmpL:           ds  1

TmpH:           ds  1



; PI gains: K = Num / 2^Shift

KpNum:          ds  1

KpShift:        ds  1

KiNum:          ds  1

KiShift:        ds  1



ShiftCnt:       ds  1        ; for shifts

MulCnt:         ds  1        ; for multiplications



; BODE mode state: sine LUT around locked D_ctrl

BodeBaseL:      ds  1        ; base D_ctrl before injection (for logging if needed)

BodeBaseH:      ds  1

BodeIdx:        ds  1        ; LUT index 0..BodeLen-1

BodeLen:        ds  1        ; LUT length

BodeDeltaL:     ds  1        ; current LUT sample (low byte)

BodeDeltaH:     ds  1        ; current LUT sample (high byte, signed)

BodeInitFlag:   ds  1        ; 0 = not initialised, 1 = initialised





;--------------------------------------------------------

; Constants

;--------------------------------------------------------

        psect   controller_consts, class=CODE



STATE_SCAN      equ 0

STATE_LOCK      equ 1

STATE_BODE      equ 2



DCTRL_MAX_L     equ 0xFF      

DCTRL_MAX_H     equ 0xFF      

     

BODE_LUT_LEN    equ 64        ; must match N in SINLUT.inc



SCAN_STEP     equ 16        ;scan step

     

; LOCK sub-states

LOCK_SEARCH     equ 0         ; sweep D until near Y_target

LOCK_PROBE      equ 1         ; D = D_base + PROBE_STEP

LOCK_MEAS       equ 2         ; measure slope sign

LOCK_TRACK      equ 3         ; normal PI tracking



; probe step in D_ctrl units (make one LUT index → 16 counts)

PROBE_STEP      equ 16        ; same scale as SCAN_STEP



; band around Y_target to "capture" lock point

LOCK_CATCH_BAND equ 2         ; |Y - Y_target| <= 2



; error threshold to declare lost lock

LOST_ERR_THRESH equ 50        ; |Err| > 50 -> lost lock



;========================================================

; Init_Controller

;========================================================

        psect   controller_code, class=CODE



Init_Controller:

        clrf    D_ctrlL, A

        clrf    D_ctrlH, A

	clrf    D_prevL, A     

        clrf    D_prevH, A     



        movlw   STATE_SCAN

        movwf   CtrlMode, A



        ; Dmax = 0xFFFF (16-bit full scale)

        movlw   0xFF

        movwf   DmaxL, A

        movlw   0xFF

        movwf   DmaxH, A



        clrf    ScanDir, A



        clrf    YkL, A

        clrf    YkH, A



        clrf    YpeakL, A

        clrf    YpeakH, A

        clrf    D_at_YpeakL, A

        clrf    D_at_YpeakH, A



        clrf    D_baseL, A

        clrf    D_baseH, A



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



	; LOCK state init

        movlw   LOCK_SEARCH

        movwf   LockState, A

        clrf    LockSide, A

        clrf    Y_lockBaseL, A

        clrf    Y_lockBaseH, A



        ; Y_target = 0x07D0 (~2000)

        movlw   0xD0

        movwf   Y_targetL, A

        movlw   0x07

        movwf   Y_targetH, A



        ; Kp, Ki

        movlw   5

        movwf   KpNum, A

        movlw   0

        movwf   KpShift, A



        movlw   0

        movwf   KiNum, A

        movlw   0

        movwf   KiShift, A



        ; RJ0 = button input, RH0..2 = mode LEDs

        bsf     TRISJ, 0, A

        bcf     TRISH, 0, A

        bcf     TRISH, 1, A

        bcf     TRISH, 2, A



        ; clear BODE state

        clrf    BodeBaseL, A

        clrf    BodeBaseH, A

        clrf    BodeIdx, A

        clrf    BodeLen, A

        clrf    BodeDeltaL, A

        clrf    BodeDeltaH, A

        clrf    BodeInitFlag, A



        ; init button prev value

        movf    PORTJ, W, A

        andlw   0x01

        movwf   BtnPrev, A



        call    UpdateModeLED

        return





;========================================================

; Controller_Step

;========================================================

Controller_Step:

    ; Save D_prev = control word that was active in the last control step

        movff   D_ctrlL, D_prevL    

        movff   D_ctrlH, D_prevH    

      

	call    UpdateModeFromButton

	

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



        ; default: SCAN

        movlw   STATE_SCAN

        movwf   CtrlMode, A

        bra     CS_DoScan





;--------------------------------------------------------

; CS_DoScan  – 16-bit sawtooth scan

;   D_ctrl = D_ctrl + STEP

;   if D_ctrl > Dmax → wrap to 0

;--------------------------------------------------------

CS_DoScan:

        ; ----- add step to D_ctrl -----

        movlw   low(SCAN_STEP)      ; low byte

        addwf   D_ctrlL, F, A

        movlw   high(SCAN_STEP)     ; high byte

        addwfc  D_ctrlH, F, A        ; add with carry



        ; ----- check if D_ctrl > Dmax -----

        movf    D_ctrlL, W, A

        subwf   DmaxL, W, A

        movf    D_ctrlH, W, A

        subwfb  DmaxH, W, A



        btfsc   STATUS, 0, A         ; C=1 → Dmax ≥ D_ctrl → OK

        bra     CS_Scan_Done         ; no wrap



        ; ----- wrap to zero -----

        clrf    D_ctrlL, A

        clrf    D_ctrlH, A



CS_Scan_Done:

        call    CS_UpdatePeakFromY

        return

	

;--------------------------------------------------------

; CS_DoLock – LOCK mode with internal sub-states

;   LOCK_SEARCH:

;       - sweep D_ctrl until |Yk - Y_target| <= LOCK_CATCH_BAND

;       - then store D_base and Y_lockBase, go to PROBE

;   LOCK_PROBE:

;       - set D_ctrl = D_base + PROBE_STEP (small nudge)

;       - go to MEAS

;   LOCK_MEAS:

;       - measure slope dY = Yk - Y_lockBase

;       - if dY >= 0  -> LEFT slope (dY/dD > 0)

;         else       -> RIGHT slope (dY/dD < 0)

;       - restore D_ctrl = D_base, go to TRACK

;   LOCK_TRACK:

;       - PI control around D_base

;       - Err_raw = Y_target - Yk

;       - if RIGHT slope -> Err = -Err_raw

;       - if |Err| > LOST_ERR_THRESH -> lost lock -> back to SEARCH

;--------------------------------------------------------

CS_DoLock:

        ; branch on LockState

        movf    LockState, W, A

        xorlw   LOCK_SEARCH

        btfsc   STATUS, 2, A

        bra     CDL_Search



        movf    LockState, W, A

        xorlw   LOCK_PROBE

        btfsc   STATUS, 2, A

        bra     CDL_Probe



        movf    LockState, W, A

        xorlw   LOCK_MEAS

        btfsc   STATUS, 2, A

        bra     CDL_Meas



        ; otherwise: TRACK

        bra     CDL_Track



;---------------- LOCK_SEARCH: sweep D_ctrl until near Y_target -----

CDL_Search:

        ; diff = Y_target - Yk  -> TmpH:TmpL (signed)

        movf    YkL, W, A

        subwf   Y_targetL, W, A   ; W = Y_targetL - YkL

        movwf   TmpL, A



        movf    YkH, W, A

        subwfb  Y_targetH, W, A   ; W = Y_targetH - YkH

        movwf   TmpH, A



        ; |diff| -> TmpH:TmpL (absolute value)

        movf    TmpH, W, A

        andlw   0x80

        btfsc   STATUS, 2, A

        bra     CDL_SearchAbsDone



        ; negative -> two's complement

        comf    TmpL, F, A

        comf    TmpH, F, A

        incf    TmpL, F, A

        movf    TmpL, W, A

        addwfc  TmpH, F, A



CDL_SearchAbsDone:

        ; compare |diff| with LOCK_CATCH_BAND

        movlw   low(LOCK_CATCH_BAND)

        subwf   TmpL, W, A

        movlw   high(LOCK_CATCH_BAND)

        subwfb  TmpH, W, A



        ; if LOCK_CATCH_BAND >= |diff|  (C=1) -> capture point

        btfsc   STATUS, 0, A

        bra     CDL_SearchCaptured



        ; not yet in band -> keep sweeping D_ctrl (step = +1)

        incf    D_ctrlL, F, A

        btfsc   STATUS, 0, A

        incf    D_ctrlH, F, A



        ; wrap if D_ctrl > Dmax

        movf    D_ctrlL, W, A

        subwf   DmaxL, W, A

        movf    D_ctrlH, W, A

        subwfb  DmaxH, W, A

        btfsc   STATUS, 0, A

        bra     CDL_SearchDone   ; Dmax >= D_ctrl -> OK



        ; wrap to zero

        clrf    D_ctrlL, A

        clrf    D_ctrlH, A



CDL_SearchDone:

        return



CDL_SearchCaptured:

        ; store base point and Y at base

        movff   D_ctrlL, D_baseL

        movff   D_ctrlH, D_baseH



        movff   YkL, Y_lockBaseL

        movff   YkH, Y_lockBaseH



        ; clear integral

        clrf    IntL, A

        clrf    IntH, A



        ; next state: PROBE

        movlw   LOCK_PROBE

        movwf   LockState, A

        return



;---------------- LOCK_PROBE: D_ctrl = D_base + PROBE_STEP ----------

CDL_Probe:

        movff   D_baseL, D_ctrlL

        movff   D_baseH, D_ctrlH



        ; Clear carry before 16-bit add

        bcf     STATUS, 0, A



        movlw   low(PROBE_STEP)

        addwf   D_ctrlL, F, A

        movlw   high(PROBE_STEP)

        addwfc  D_ctrlH, F, A



        ; simple saturation to max if overflow

        btfsc   STATUS, 0, A

        bra     CDL_ProbeClampHigh

        bra     CDL_ProbeSetState



CDL_ProbeClampHigh:

        movlw   DCTRL_MAX_L

        movwf   D_ctrlL, A

        movlw   DCTRL_MAX_H

        movwf   D_ctrlH, A



CDL_ProbeSetState:

        movlw   LOCK_MEAS

        movwf   LockState, A

        return



;---------------- LOCK_MEAS: measure slope sign ---------------------

CDL_Meas:

        ; dY = Yk - Y_lockBase  -> TmpH:TmpL

        movf    YkL, W, A

        subwf   Y_lockBaseL, W, A

        movwf   TmpL, A



        movf    YkH, W, A

        subwfb  Y_lockBaseH, W, A

        movwf   TmpH, A



        ; check sign bit of dY (TmpH)

        movf    TmpH, W, A

        andlw   0x80

        btfsc   STATUS, 2, A

        bra     CDL_SlopeLeft    ; sign=0 -> dY>=0 -> LEFT slope



        ; negative -> RIGHT slope

        movlw   1                ; LOCK_SIDE_RIGHT

        movwf   LockSide, A

        bra     CDL_SlopeDone



CDL_SlopeLeft:

        clrf    LockSide, A      ; 0 = LEFT



CDL_SlopeDone:

        ; restore D_ctrl = D_base

        movff   D_baseL, D_ctrlL

        movff   D_baseH, D_ctrlH



        ; enter TRACK

        movlw   LOCK_TRACK

        movwf   LockState, A

        return



;---------------- LOCK_TRACK: PI + lost-lock detection --------------

CDL_Track:

        ; 1) Err_raw = Y_target - Yk

        movff   Y_targetL, ErrL

        movff   Y_targetH, ErrH



        movf    YkL, W, A

        subwf   ErrL, F, A

        movf    YkH, W, A

        subwfb  ErrH, F, A



        ; 2) If RIGHT slope -> Err = -Err_raw

        movf    LockSide, W, A

        btfsc   STATUS, 2, A

        bra     CDL_ErrSignDone  ; LockSide==0 (LEFT) -> keep sign



        ; RIGHT slope (LockSide!=0) -> two's complement

        comf    ErrL, F, A

        comf    ErrH, F, A

        incf    ErrL, F, A

        movf    ErrL, W, A

        addwfc  ErrH, F, A



CDL_ErrSignDone:

        ; 3) Pterm = Kp * Err

        call    Scale_Err_Kp



        ; 4) Iinc = Ki * Err, Int += Iinc

        call    Scale_Err_Ki

        movf    IincL, W, A

        addwf   IntL, F, A

        movf    IincH, W, A

        addwfc  IntH, F, A



        ; 5) Corr = Pterm + Int

        movff   PtermL, CorrL

        movff   PtermH, CorrH



        movf    IntL, W, A

        addwf   CorrL, F, A

        movf    IntH, W, A

        addwfc  CorrH, F, A



        ; 6) D_ctrl = D_base + Corr, saturate to 0..0xFFFF

        movff   D_baseL, D_ctrlL

        movff   D_baseH, D_ctrlH



        bcf     STATUS, 0, A      ; C = 0 before add



        movf    CorrL, W, A

        addwf   D_ctrlL, F, A

        movf    CorrH, W, A

        addwfc  D_ctrlH, F, A



        ; negative -> clamp to 0

        movf    D_ctrlH, W, A

        andlw   0x80

        btfss   STATUS, 2, A

        bra     PI_Clamp_Zero_Track



        ; overflow (carry) -> clamp to max

        btfsc   STATUS, 0, A

        bra     PI_Clamp_High_Track



        bra     PI_Done_Track



PI_Clamp_High_Track:

        movlw   DCTRL_MAX_L

        movwf   D_ctrlL, A

        movlw   DCTRL_MAX_H

        movwf   D_ctrlH, A

        bra     PI_Done_Track



PI_Clamp_Zero_Track:

        clrf    D_ctrlL, A

        clrf    D_ctrlH, A



PI_Done_Track:

        ; 7) lost-lock detection: |Err| > LOST_ERR_THRESH ?

        movff   ErrL, TmpL

        movff   ErrH, TmpH



        ; |Err| into TmpH:TmpL

        movf    TmpH, W, A

        andlw   0x80

        btfsc   STATUS, 2, A

        bra     CDL_AbsErrDone



        comf    TmpL, F, A

        comf    TmpH, F, A

        incf    TmpL, F, A

        movf    TmpL, W, A

        addwfc  TmpH, F, A



CDL_AbsErrDone:

        movlw   low(LOST_ERR_THRESH)

        subwf   TmpL, W, A

        movlw   high(LOST_ERR_THRESH)

        subwfb  TmpH, W, A



        ; if LOST_ERR_THRESH >= |Err| (C=1) -> still locked

        btfsc   STATUS, 0, A

        bra     CDL_TrackDone



        ; else: lost lock -> go back to SEARCH

        movlw   LOCK_SEARCH

        movwf   LockState, A

        ; optional: clear integral for fresh search

        clrf    IntL, A

        clrf    IntH, A



CDL_TrackDone:

        return



;--------------------------------------------------------

; CS_InitBode

; Initialize LUT index and length for BODE mode.

;--------------------------------------------------------

CS_InitBode:

        clrf    BodeIdx, A

        movlw   BODE_LUT_LEN

        movwf   BodeLen, A

        movlw   1

        movwf   BodeInitFlag, A

        return





;--------------------------------------------------------

; CS_DoBode

; Bode while locked:

; 1) Run PI lock (CS_DoLock) to keep loop closed.

; 2) Take current D_ctrl as base.

; 3) Add sine LUT sample Δ[k] on top, clamp to 16-bit.

; 4) Advance LUT index with wrap.

;--------------------------------------------------------

CS_DoBode:

        ; lazy init for LUT length and index

        movf    BodeInitFlag, W, A

        btfsc   STATUS, 2, A

        call    CS_InitBode



        ; step 1: run PI lock

        call    CS_DoLock



        ; base = locked D_ctrl (for logging if needed)

        movff   D_ctrlL, BodeBaseL

        movff   D_ctrlH, BodeBaseH



        ;--------------------------------------------

        ; set TBLPTR = BodeLUT + 2 * BodeIdx

        ;--------------------------------------------

        movlw   low highword(BodeSineLUT)

        movwf   TBLPTRU, A

        movlw   high(BodeSineLUT)

        movwf   TBLPTRH, A

        movlw   low(BodeSineLUT)

        movwf   TBLPTRL, A



        movf    BodeIdx, W, A

        addwf   BodeIdx, W, A      ; W = BodeIdx*2

        addwf   TBLPTRL, F, A

        clrf    WREG, A

        addwfc  TBLPTRH, F, A



        ; read ΔL

        tblrd*+

        movf    TABLAT, W, A

        movwf   BodeDeltaL, A



        ; read ΔH

        tblrd*

        movf    TABLAT, W, A

        movwf   BodeDeltaH, A



        ;--------------------------------------------

        ; D_ctrl = locked D_ctrl + Δ (signed)

        ;--------------------------------------------

        movff   BodeBaseL, D_ctrlL

        movff   BodeBaseH, D_ctrlH



        movf    BodeDeltaL, W, A

        addwf   D_ctrlL, F, A

        movf    BodeDeltaH, W, A

        addwfc  D_ctrlH, F, A



        ; clamp to 0..0xFFFF

        ; check negative -> clamp to 0

        movf    D_ctrlH, W, A

        andlw   0x80

        btfss   STATUS, 2, A

        bra     Bode_Clamp_Zero



        ; check carry -> clamp to max

        btfsc   STATUS, 0, A

        bra     Bode_Clamp_High



        bra     Bode_Clamp_Done



Bode_Clamp_High:

        movlw   DCTRL_MAX_L

        movwf   D_ctrlL, A

        movlw   DCTRL_MAX_H

        movwf   D_ctrlH, A

        bra     Bode_Clamp_Done



Bode_Clamp_Zero:

        clrf    D_ctrlL, A

        clrf    D_ctrlH, A



Bode_Clamp_Done:

        ; advance index with wrap

        incf    BodeIdx, F, A

        movf    BodeIdx, W, A

        xorwf   BodeLen, W, A

        btfss   STATUS, 2, A

        bra     CSBode_End



        clrf    BodeIdx, A



CSBode_End:

        return





;--------------------------------------------------------

; UpdateModeFromButton: RJ0 press -> next mode

; 0 -> 1 -> 2 -> 0  (active-low button)

;--------------------------------------------------------

UpdateModeFromButton:

        ; read current button (RJ0)

        movf    PORTJ, W, A

        andlw   0x01

        movwf   TmpBtn, A



        ; Prev = BtnPrev & 0x01

        movf    BtnPrev, W, A

        andlw   0x01

        btfsc   STATUS, 2, A

        bra     UMB_NoPress       ; Prev == 0 -> no falling edge



        ; Now = TmpBtn & 0x01

        movf    TmpBtn, W, A

        andlw   0x01

        btfsc   STATUS, 2, A

        bra     UMB_Press         ; Prev=1, Now=0 -> press

        bra     UMB_NoPress



UMB_Press:

        incf    CtrlMode, F, A

        movf    CtrlMode, W, A

        andlw   0x03

        xorlw   0x03

        btfss   STATUS, 2, A

        bra     UMB_ModeOk



        clrf    CtrlMode, A



UMB_ModeOk:

        ; actions on entering new mode

        movf    CtrlMode, W, A

        xorlw   STATE_SCAN

        btfss   STATUS, 2, A

        bra     UMB_CheckLock



        ; entering SCAN: reset scan & peak

        clrf    D_ctrlL, A

        clrf    D_ctrlH, A

        clrf    ScanDir, A

        clrf    YpeakL, A

        clrf    YpeakH, A

        clrf    D_at_YpeakL, A

        clrf    D_at_YpeakH, A

        bra     UMB_UpdateLED



UMB_CheckLock:

        movf    CtrlMode, W, A

        xorlw   STATE_LOCK

        btfss   STATUS, 2, A

        bra     UMB_CheckBode



        ; entering LOCK:

        ; - keep manually-set Y_target

        ; - start from current D_ctrl

        ; - clear integral

        ; - set internal state to SEARCH

        movff   D_ctrlL, D_baseL

        movff   D_ctrlH, D_baseH



        clrf    IntL, A

        clrf    IntH, A



        movlw   LOCK_SEARCH

        movwf   LockState, A

        clrf    LockSide, A



        bra     UMB_UpdateLED



UMB_CheckBode:

        movf    CtrlMode, W, A

        xorlw   STATE_BODE

        btfss   STATUS, 2, A

        bra     UMB_UpdateLED



        ; entering BODE: mark LUT uninitialised

        clrf    BodeInitFlag, A



UMB_UpdateLED:

        call    UpdateModeLED



UMB_NoPress:

        movf    TmpBtn, W, A

        movwf   BtnPrev, A

        return





;--------------------------------------------------------

; UpdateModeLED: RH0=SCAN, RH1=LOCK, RH2=BODE

;--------------------------------------------------------

UpdateModeLED:

        bcf     LATH, 0, A

        bcf     LATH, 1, A

        bcf     LATH, 2, A



        movf    CtrlMode, W, A

        xorlw   STATE_SCAN

        btfsc   STATUS, 2, A

        bsf     LATH, 0, A



        movf    CtrlMode, W, A

        xorlw   STATE_LOCK

        btfsc   STATUS, 2, A

        bsf     LATH, 1, A



        movf    CtrlMode, W, A

        xorlw   STATE_BODE

        btfsc   STATUS, 2, A

        bsf     LATH, 2, A



        return





;--------------------------------------------------------

; CS_UpdatePeakFromY

;--------------------------------------------------------

CS_UpdatePeakFromY:

        ; if Yk > Ypeak -> update peak

        movf    YkH, W, A

        subwf   YpeakH, W, A

        btfss   STATUS, 0, A

        bra     CUP_NewPeak



        movf    YkH, W, A

        xorwf   YpeakH, W, A

        btfss   STATUS, 2, A

        bra     CUP_End



        movf    YkL, W, A

        subwf   YpeakL, W, A

        btfss   STATUS, 0, A

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

; Scale_Err_Kp: Pterm = (KpNum * Err) >> KpShift (signed)

;--------------------------------------------------------

Scale_Err_Kp:

        clrf    PtermL, A

        clrf    PtermH, A



        movf    KpNum, W, A

        movwf   MulCnt, A

        movf    MulCnt, F, A

        btfsc   STATUS, 2, A

        bra     SEKp_Shift       ; Num == 0



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

; Scale_Err_Ki: Iinc = (KiNum * Err) >> KiShift (signed)

;--------------------------------------------------------

Scale_Err_Ki:

        clrf    IincL, A

        clrf    IincH, A



        movf    KiNum, W, A

        movwf   MulCnt, A

        movf    MulCnt, F, A

        btfsc   STATUS, 2, A

        bra     SEKi_Shift       ; Num == 0



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
