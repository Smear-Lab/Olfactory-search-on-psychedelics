import numpy as np
import matplotlib.pyplot as plt
import time

# Import .dat and zip raw and smoothed into DF
data = np.fromfile('D:/fmon-bpod/NiDAQ_sniff.dat', dtype=float)

print(data.shape)

#plt.plot(data[0:800:4])
plt.plot(data[0:250000:4])
#plt.plot(data[2::4])
#plt.plot(data[3::4])
plt.show()
