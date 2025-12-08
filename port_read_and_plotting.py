"""
log_adc_ramp.py

Requires:
    conda install -c anaconda pyserial matplotlib

Frame from model PIC (UART1):
    [0xAA][ADRESH][ADRESL]
Result is 12-bit, right-justified:
    adc_12 = ((ADRESH & 0x0F) << 8) | ADRESL
"""

import csv
import time
import serial
from serial.tools import list_ports
import matplotlib.pyplot as plt

PORT = "COM4"        # adjust as needed
BAUD = 9600
NUM_SAMPLES = 4096   # one full 0..4095 sweep (assuming controller ramp runs once)


def list_serial_ports():
    print("Available serial ports:")
    for p in list_ports.comports():
        print(f"  {p.device}: {p.description}")


def read_one_adc_sample(ser):
    """
    Wait for header 0xAA, then read ADRESH and ADRESL.
    Return decoded 12-bit ADC value, or None if something goes wrong.
    """
    # sync on header
    while True:
        b = ser.read(1)
        if len(b) == 0:
            # timeout – keep looking
            continue
        if b[0] == 0xAA:
            break

    # now read the two data bytes
    frame = ser.read(2)
    if len(frame) < 2:
        return None

    adresh = frame[0]
    adresl = frame[1]

    # 12-bit right-justified in ADRESH:ADRESL
    value_12 = ((adresh & 0x0F) << 8) | adresl
    return value_12


def main():
    list_serial_ports()

    base = input("Output CSV filename (without .csv): ").strip()
    if not base:
        base = "adc_ramp"
    filename = base + ".csv"

    ser = serial.Serial(
        PORT,
        BAUD,
        timeout=2.0,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
    )
    ser.reset_input_buffer()
    print(f"Opened {PORT} at {BAUD} baud")
    print(f"Logging {NUM_SAMPLES} samples to {filename}")

    xs_expected = []
    ys_adc = []

    t0 = time.time()

    with open(filename, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["index", "timestamp_s", "expected_code", "adc_code_12bit"])

        for idx in range(NUM_SAMPLES):
            while True:
                val = read_one_adc_sample(ser)
                if val is not None:
                    break

            ts = time.time() - t0
            expected_code = idx  # since controller PIC ramps 0..4095

            writer.writerow([idx, f"{ts:.6f}", expected_code, val])

            xs_expected.append(expected_code)
            ys_adc.append(val)

            if idx % 256 == 0:
                print(f"{idx:4d}: expected {expected_code:4d}, ADC {val:4d}")

    ser.close()
    print("Done, port closed.")

    # quick sanity plot: ADC vs expected DAC code
    plt.figure()
    plt.plot(xs_expected, ys_adc, ".", markersize=2)
    plt.xlabel("Expected DAC code (0..4095)")
    plt.ylabel("Measured ADC code (12-bit)")
    plt.title("ADC vs expected DAC code")
    plt.grid(True)
    plt.show()


if __name__ == "__main__":
    main()
