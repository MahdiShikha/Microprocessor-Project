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


PORT = "COM5"
BAUD = 114285
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
    writer.writerow(["sample", "D_ctrl_12bit", "Yk_12bit"])

    # --- Prepare plot (plotting Yk and D_ctrl vs sample index) ---
    plt.ion()
    fig1, ax1 = plt.subplots()
    fig2, ax2 = plt.subplots()
    line_Yk,   = ax1.plot([], [], marker=".", linestyle="-", label="Yk")
    line_Dctr, = ax2.plot([], [], marker=".", linestyle="--", label="D_ctrl")
    ax1.set_xlabel("Sample index")
    ax1.set_ylabel("Value (12-bit)")
    ax1.set_title("Live UART data")
    ax1.legend()
    ax2.set_xlabel("Sample index")
    ax2.set_ylabel("Value (16-bit)")
    ax2.set_title("Live UART data")
    ax2.legend()



    xs = []
    ys_Yk = []          # store Yk for plotting
    ys_Dctrl = []       # store D_ctrl for plotting
    sample_idx = 0
    t0 = time.time()
    t =[]
    num_collected = 0

    print("Logging + plotting. Press Ctrl+C to stop.")
    print("Expecting frames: 0xFF 0xFF MODE D_H D_L Y_H Y_L")

    try:
        N = 50000
        ykarr = np.zeros(N)
        dcontarr = np.zeros(N)
        for i in range(N):
            while not ser.read(1)==b'\xff':
                pass
            ykbytes = ser.read(2)
            yk = ykbytes[0] * 256 + ykbytes[1]
            ykarr[i] = yk
            dcontb = ser.read(2)
            dcont = dcontb[0] * 256 + dcontb[1]
            dcontarr[i] = dcont
            # print(f'{yk}, {dcont}')
            # print(f"{hex(byte[0])}, {byte}")

            num_collected += num_collected
        plt.figure()
        plt.plot(ykarr)
        plt.show()
        plt.figure()
        plt.plot(dcontarr)
        plt.show()

    except KeyboardInterrupt:
        print("\nStopping logging.")
        plt.figure()
        plt.plot(ykarr)
        plt.show()
        plt.figure()
        plt.plot(dcontarr)
        plt.show()
        ser.close
        
    

    except KeyboardInterrupt:
        print("\nStopping logging.")

    finally:
        for i in range(num_collected):
            writer.writerow([i,int(dcontarr[i]),int(ykarr[i])])
        f.close()
        ser.close()
        plt.ioff()
        plt.show()  # keep final plot on screen


if __name__ == "__main__":
    list_serial_ports()
    main()