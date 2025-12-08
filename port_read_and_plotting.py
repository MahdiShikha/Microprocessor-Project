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


PORT = "COM4"
BAUD = 115200
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
    writer.writerow(["sample", "timestamp_s", "mode", "D_ctrl_12bit", "Yk_12bit"])

    # --- Prepare plot (plotting Yk and D_ctrl vs sample index) ---
    plt.ion()
    fig, ax = plt.subplots()
    line_Yk,   = ax.plot([], [], marker=".", linestyle="-", label="Yk")
    line_Dctr, = ax.plot([], [], marker=".", linestyle="--", label="D_ctrl")
    ax.set_xlabel("Sample index")
    ax.set_ylabel("Value (12-bit)")
    ax.set_title("Live UART data")
    ax.legend()


    xs = []
    ys_Yk = []          # store Yk for plotting
    ys_Dctrl = []       # store D_ctrl for plotting
    sample_idx = 0
    t0 = time.time()

    print("Logging + plotting. Press Ctrl+C to stop.")
    print("Expecting frames: 0xFF 0xFF MODE D_H D_L Y_H Y_L")

    try:
        while sample_idx < NUM_SAMPLES:

            # --- 1) Find 2-byte header 0xFF 0xFF --- 
            #sliding window method
            prev = None
            while True:
                b = ser.read(1)
                if len(b) == 0:
                    # timeout, keep trying
                    continue

                byte = b[0]
                if prev == 0xFF and byte == 0xFF:
                    # Found header
                    break

                prev = byte

            # --- 2) Read the rest of the frame: MODE, D_H, D_L, Y_H, Y_L ---
            frame = ser.read(5)
            if len(frame) < 5:
                # incomplete frame (timeout), restart header search
                continue

            mode      = frame[0]
            D_ctrl_H  = frame[1]
            D_ctrl_L  = frame[2]
            YkH       = frame[3]
            YkL       = frame[4]

            # 12-bit combine (upper nibble from *_H)
            D_ctrl = ((D_ctrl_H & 0x0F) << 8) | D_ctrl_L
            Yk     = ((YkH      & 0x0F) << 8) | YkL

            ts = time.time() - t0
            sample_idx += 1

            # store for plot (Yk)
            xs.append(sample_idx)
            ys_Yk.append(Yk)
            ys_Dctrl.append(D_ctrl)

            # write to CSV
            writer.writerow([sample_idx, f"{ts:.6f}", mode, D_ctrl, Yk])

            # update plot every N samples (e.g. every 10)
            if sample_idx % 10 == 0:
                line_Yk.set_data(xs, ys_Yk)
                line_Dctr.set_data(xs, ys_Dctrl)
                ax.relim()
                ax.autoscale_view()
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