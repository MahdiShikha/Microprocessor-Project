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
    writer.writerow(["sample", "timestamp_s", "D_ctrl_12bit", "Yk_12bit"])

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
        plt.figure()
        plt.plot(ykarr)
        plt.show()
        plt.figure()
        plt.plot(dcontarr)
        plt.show()

    except KeyboardInterrupt:
        print("\nStopping logging.")

        ser.close
        while sample_idx > NUM_SAMPLES:
            

            # --- 1) Find 2-byte header 0xFF 0xFF --- 
            #sliding window method
            prev = None
            while True:
                b = ser.read(1)
                if len(b) == 0:
                    # timeout, keep trying
                    continue
                if b[0] == 0xFF:
                #byte = b[0]
                #if prev == 0xFF and byte == 0xFF:
                    # Found header
                    break

                #prev = byte

            # --- 2) Read the rest of the frame: MODE, D_H, D_L, Y_H, Y_L ---
            frame = ser.read(4)
            if len(frame) < 4:
                # incomplete frame (timeout), restart header search
                continue

            #mode      = frame[0]
            D_ctrl_H  = frame[2]
            D_ctrl_L  = frame[3]
            YkH       = frame[0]
            YkL       = frame[1]

            # 12-bit combine (upper nibble from *_H)
            D_ctrl = (D_ctrl_H  << 8) | D_ctrl_L
            Yk     = ((YkH      & 0x0F) << 8) | YkL

            ts = time.time() - t0
            sample_idx += 1

            # store for plot (Yk)
            xs.append(sample_idx)
            ys_Yk.append(Yk)
            ys_Dctrl.append(D_ctrl)

            # write to CSV
            writer.writerow([sample_idx, f"{ts:.6f}", D_ctrl, Yk])
            print(f"{sample_idx:6d}: 0x{YkH:02X} 0x{YkL:02X} -> {Yk:5d}")
            print(f"{sample_idx:6d}: 0x{D_ctrl_H:02X} 0x{D_ctrl_L:02X} -> {D_ctrl:5d}")   

            # update plot every N samples (e.g. every 10)
            if sample_idx % 10 == 0:
                line_Yk.set_data(xs, ys_Yk)
                line_Dctr.set_data(xs, ys_Dctrl)
                ax1.relim()
                ax1.autoscale_view()
                ax2.relim()
                ax2.autoscale_view()
                plt.pause(0.001)

    except KeyboardInterrupt:
        print("\nStopping logging.")

    finally:
        f.close()
        ser.close()
        plt.ioff()
        plt.show()  # keep final plot on screen


if __name__ == "__main__":
    list_serial_ports()
    main()