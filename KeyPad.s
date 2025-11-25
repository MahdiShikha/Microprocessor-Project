#include <xc.inc>
    global KeyPad_init

    
    KeyPad_init:
		movlw	0x0F
		movwf	TRISE, A
		
    
    KeyPad_read:
	    

