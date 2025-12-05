import numpy as np
import matplotlib.pyplot as plt
import pandas as pd

df = pd.read_csv("test5.csv",usecols=[0,2])
print(df)

xs = df["sample"].to_numpy()
ys = df["value_12bit"].to_numpy()

plt.plot(xs,ys)
plt.show()