import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import csv
def main():
    base = input("Output CSV filename: ").strip()
    if not base:
        base = "uart_log"
    filename = base + ".csv"

    NUM_SAMPLES = 1000
    # --- Prepare CSV (only header now, data written at the end) ---
    f = open(filename, "w", newline="")
    writer = csv.writer(f)
    writer.writerow(["sample", "D_ctrl_16bit", "Yk_12bit"])
    N = NUM_SAMPLES
    ykarr = np.zeros(N)
    dcontarr = np.zeros(N)
    num_collected = 0


    for i in range((N)):
        ykarr[num_collected] = i
        dcontarr[num_collected] = i
        num_collected += 1


    for i in range(num_collected):
        writer.writerow([i,dcontarr[i],ykarr[i]])

    f.close

if __name__== "__main__":
    main()