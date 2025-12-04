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
"""
import csv
import time
import serial
import matplotlib.pyplot as plt

PORT = "COM4"
BAUD = 9600

def main():
    # --- Ask for filename ---
    base = input("Output CSV filename: ").strip()
    if not base:
        base = "uart_log"
    filename = base + ".csv"

    # --- Open serial ---
    ser = serial.Serial(PORT, BAUD, timeout=1)
    ser.reset_input_buffer()

    # --- Prepare CSV ---
    f = open(filename, "w", newline="")
    writer = csv.writer(f)
    writer.writerow(["sample", "timestamp_s", "value_12bit"])

    # --- Prepare plot ---
    plt.ion()
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
        while True:
            # read 2 bytes = 12-bit value, high then low
            frame = ser.read(2)
            if len(frame) < 2:
                continue  # timeout / incomplete frame, skip

            high, low = frame[0], frame[1]
            value = (high << 8) | low  # 0–65535; mask if needed

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
    main()
