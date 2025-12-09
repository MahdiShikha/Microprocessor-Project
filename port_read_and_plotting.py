
"""
Make sure pyserial is installed on anacodna environment,
conda install -c anaconda pyserial
"""

"""
Code logic:

Read bytes from the serial port
Decode them into a value
Append to a Python list (for plotting)
Write the same value as a row into the CSV
Update the plot every few samples
Stops after a set amount of samples have been read or a keyboard interrupt

Frame format (7 bytes in total):
[0xFF][0xFF][MODE][D_ctrl_H][D_ctrl_L][YkH][YkL]
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
    writer.writerow(["sample", "timestamp_s", "ADC_Value"])

    sample_idx = 0
    t0 = time.time()

    print("Logging + plotting. Press Ctrl+C to stop.")
    print("Expecting frames: 0xFF 0xFF MODE D_H D_L Y_H Y_L")

    try:    #FRAMES: 0xFF [adresh][adresL]
        N = 50000
        adc_arr = np.zeros(N)
        for i in range(N):
            while not ser.read(1)==b'\xff':
                pass
            adc_bytes = ser.read(2)
            adc_val = adc_bytes[0] * 256 + adc_bytes[1]
            adc_arr[i] = adc_val
            print(f"{adc_val}")
            # print(f'{yk}, {dcont}')
            # print(f"{hex(byte[0])}, {byte}")
        print(adc_arr)
        plt.figure()
        plt.plot(adc_arr)
        plt.show()
    except KeyboardInterrupt:
        print("\nStopping logging.")
        plt.figure()
        plt.plot(adc_arr)
        plt.show()
        ser.close()
    finally:
        for i in range(len(adc_arr)):
            writer.writerow([i,time.time() - t0, adc_arr[i]])
        f.close()
        ser.close()
        plt.ioff()
        plt.show()  # keep final plot on screen


if __name__ == "__main__":
    list_serial_ports()
    main()