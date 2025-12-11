
"""
Make sure pyserial is installed on anacodna environment,
conda install -c anaconda pyserial
"""

"""
Code logic:

Read bytes from the serial port
Decode them into a value
Append to an array
Stops after a set amount of samples have been read or a keyboard interrupt
Write array values to csv

Frame format (3 bytes in total):
[0xFF][ADRESH][ADRESL]
"""
import csv
import time
import serial
import matplotlib.pyplot as plt
from serial.tools import list_ports
import numpy as np


PORT = "COM4"
BAUD = 9600
NUM_SAMPLES = 100000

def list_serial_ports():
    ports = list_ports.comports()
    print("Available serial ports:")
    for port in ports:
        print(f"{port.device}: {port.description}")
        # p.device is like "COM4" on Windows, "/dev/ttyUSB0" on Linux, etc.

def main():
    # --- Ask for filename ---
    base = input("Output CSV filename: ").strip()
    if not base:
        base = "uart_log"
    filename = base + ".csv"

    # --- Open serial ---
    ser = serial.Serial(PORT, BAUD, timeout=10.0)
    ser.reset_input_buffer()  # flush any old junk

    # --- Prepare CSV ---
    f = open(filename, "w", newline="")
    writer = csv.writer(f)
    writer.writerow(["sample", "ADC_Value"])

    sample_idx = 0
    t0 = time.time()

    print("Logging + plotting. Press Ctrl+C to stop.")
    print("Expecting frames: 0xFF ADRESH ADRESL")

    try:    #FRAMES: 0xFF [adresh][adresL]
        N = 50000
        adc_arr = np.zeros(N)
        num_collected = 0
        for i in range(N):
            while not ser.read(1)==b'\xff':
                pass
            adc_bytes = ser.read(2)
            adc_val = adc_bytes[0] * 256 + adc_bytes[1]
            adc_arr[i] = adc_val
            print(f"{adc_val}")
            num_collected += 1
            # print(f'{yk}, {dcont}')
            # print(f"{hex(byte[0])}, {byte}")
        print(adc_arr)
        plt.figure()
        plt.plot(adc_arr, label="ADC Values")
        plt.xlabel("Sample Index")
        plt.ylabel("Value (12bit)")
        plt.legend()
        plt.show()
        ser.close

    except KeyboardInterrupt:
        print("\nStopping logging.")
        
        print(adc_arr)
        plt.figure()
        plt.plot(adc_arr, label="ADC Values")
        plt.xlabel("Sample Index")
        plt.ylabel("Value (12bit)")
        plt.legend()
        plt.show()
        ser.close
        
    finally:
        for i in range(num_collected):
            writer.writerow([i, adc_arr[i]])
        f.close()
        ser.close()
        plt.show()  # keep final plot on screen


if __name__ == "__main__":
    list_serial_ports()
    main()