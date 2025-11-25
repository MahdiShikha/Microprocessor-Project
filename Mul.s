#include <xc.inc>

global	Mul16x16, Mul24x8
global	ARG1L,ARG1H,ARG2L,ARG2H
global	X0,X1,X2,Y0
global	RES0,RES1,RES2,RES3
psect	udata_acs
;16x16 numbers
ARG1L:	ds 1	;low byte of num 1
ARG1H:	ds 1	;high byte of num 1
ARG2L:	ds 1	;low byte of num 2
ARG2H:	ds 1	;high byte of num 2
;24x8 numbers
X0:	ds 1	;bits [0,..,7] of 24
X1:	ds 1	;bits [8,..,15] of 24
X2:	ds 1	;bits [16,..,23] of 24
Y0:	ds 1	; 8 bit
    
;results, used by both methods
RES0:	ds 1	;bits [0,..,7]
RES1:	ds 1	;bits [8,..,15]
RES2:	ds 1	;bits [16,..23]
RES3:	ds 1	;bits [24,..31]
 
psect	mul_code, class=CODE

Mul16x16:
    movf ARG1L, W 
    mulwf ARG2L ; ARG1L * ARG2L-> 
		; PRODH:PRODL 
    movff PRODH, RES1 ; 
    movff PRODL, RES0 ; 
			; 
    movf ARG1H, W 
    mulwf ARG2H ; ARG1H * ARG2H-> 
    ; PRODH:PRODL 
    movff PRODH, RES3 ; 
    movff PRODL, RES2 ; 
			; 
    movf ARG1L, W 
    mulwf ARG2H ; ARG1L * ARG2H-> 
    ; PRODH:PRODL 
    movf PRODL, W ; 
    addwf RES1, F ; Add cross 
    movf PRODH, W ; products 
    addwfc RES2, F ; 
    clrf WREG ; 
    addwfc RES3, F ; 
	    ; 
    movf ARG1H, W ; 
    mulwf ARG2L ; ARG1H * ARG2L-> 
				; PRODH:PRODL 
    movf PRODL, W ; 
    addwf RES1, F ; Add cross 
    movf PRODH, W ; products 
    addwfc RES2, F ; 
    clrf WREG ; 
    addwfc RES3, F ; 
    
    return
    
Mul24x8:
    clrf    RES0, A
    clrf    RES1, A
    clrf    RES2, A
    clrf    RES3, A
    movf    X0, W, A
    mulwf   Y0, A
    movff   PRODL, RES0
    movff   PRODH, RES1
    
    movf    X1, W, A
    mulwf   Y0, A
    movf    PRODL, W, A
    addwf   RES1, F, A
    movf    PRODH, W, A
    addwfc  RES2, F, A
    movlw   0x00
    addwfc  RES3, F , A
    
    movf    X2, W,A
    mulwf   Y0, A
    movf    PRODL, W, A
    addwf   RES2, F, A
    movf    PRODH, W, A
    addwfc  RES3, F, A
    
    return
    
    end
    


