# Microprocessors
Branch to test how the ouput of a digital signal from the controller pic can be offset when read in the model pic
Osciliscope will probe port AN0 (A0) on the model PIC

Files: main_controller_dac_ramp.s, DAC.S and config.s are used in the controller pic
Files: main_model_adc_stream.s, ADC.S, UART.S and config.s are used in the model pic
Files: port_read_and_plotting.py are used in the PC
