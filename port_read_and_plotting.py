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
"""
import csv
import time
import serial
import matplotlib.pyplot as plt
from serial.tools import list_ports


PORT = "COM4"
BAUD = 9615
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
    ser.reset_input_buffer() # possible comment

    # --- Prepare CSV ---
    f = open(filename, "w", newline="")
    writer = csv.writer(f)
    writer.writerow(["sample", "timestamp_s", "value_12bit"])

    # --- Prepare plot ---
    plt.ion()   #interactive mode
    fig, ax = plt.subplots()
    line, = ax.plot([], [], marker=".")
    ax.set_xlabel("Sample index")
    ax.set_ylabel("Value (12-bit)")
    ax.set_title("Live UART data")

    xs = []
    ys = []
    sample_idx = 0
    t0 = time.time()

    print("Logging + plotting. Press Ctrl+C to stop.")

    try:
        while sample_idx < NUM_SAMPLES:
            # read 2 bytes = 12-bit value, high then low
            frame = ser.read(2)
            if len(frame) < 2:
                continue  # timeout / incomplete frame, skip

            high, low = frame[0], frame[1]
            raw_16 = (high << 8) | low  # 0–65535; mask if needed
            value = (raw_16 >> 4) & 0x0FFF

            ts = time.time() - t0
            sample_idx += 1

            # store for plot
            xs.append(sample_idx)
            ys.append(value)

            # write to CSV
            writer.writerow([sample_idx, f"{ts:.6f}", value])

            # update plot every N samples (e.g. every 10)
            if sample_idx % 10 == 0:
                line.set_data(xs, ys)
                ax.relim()
                ax.autoscale_view()
                plt.pause(0.001)  # let GUI update

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
