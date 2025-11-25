#include <xc.inc>
    
global KeyPad_init
global KeyPad_read
  
psect  KeyPad_code, class=Code
  
KeyPad_init:	;configures pull upts to on for PORTE
    movlb   0x0F ;SFR (PADCFG1) needs to be accessed outside of access ram
    bsf	    REPU
    clrf    LATE, A ;write 0s to the LATE register
    movlw   0x0F    ;configure R0-3 as inputs, R4-7 as outputs
    movwf   TRISE, A
    return
    
  
KeyPad_read:
    movlw 0x00
    return
    
    end
  

    


