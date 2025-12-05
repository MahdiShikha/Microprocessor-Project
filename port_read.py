"""
Make sure pyserial is installed on anacodna environment,
conda install -c anaconda pyserial
"""
import serial
import time
import csv

PORT = "COM4"          # your USB-UART port
BAUD = 9600            # must match PIC (SPBRG1 = 103)
NUM_SAMPLES = 100000    # samples to read (each = 2 bytes: high, low)


def main():
    # Ask user for file name
    filename = input("Enter CSV filename (default: uart_log.csv): ").strip()
    if not filename:
        filename = "uart_log.csv"
    elif not filename.lower().endswith(".csv"):
        filename += ".csv"

    # open serial port: 8 data bits, no parity, 1 stop bit (8N1)
    ser = serial.Serial(
        PORT,
        baudrate=BAUD,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=10.0,      # 10 second read timeout
    )

    print(f"Opened {PORT} at {BAUD} baud")
    print(f"Logging to {filename}")

    with open(filename, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["index", "timestamp_s", "high_byte", "low_byte", "value_16bit"])

        index = 0
        try:
            while index < NUM_SAMPLES:
                frame = ser.read(2)        # 2 bytes per sample (MSB, LSB)
                if len(frame) < 2:
                    continue               # timeout, no data this iteration

                hi = frame[0]
                lo = frame[1]
                value = (hi << 8) | lo
                t = time.time()

                writer.writerow([index, t, hi, lo, value])
                print(f"{index:6d}: 0x{hi:02X} 0x{lo:02X} -> {value:5d}")   
                #index - base 10
                #hi    - hex
                #lo    - hex
                #value - base 10

                index += 1

        except KeyboardInterrupt:
            print("\nStopped by user (Ctrl+C)")

    ser.close()
    print("Port closed, data saved.")


if __name__ == "__main__":
    main()
