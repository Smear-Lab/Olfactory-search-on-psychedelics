import numpy as np
import matplotlib.pyplot as plt
import time

pid_data = []
dat = []

# Import .dat files
for i in range(35):
    dat = np.fromfile(f"E:/Git Repos/fmon-bpod/pid_map/data/position{i}.dat", dtype=float)
    pid_data.append(dat)
print('done')

# Create a color map
cmap = plt.cm.get_cmap('viridis', len(pid_data))  # 'viridis' is one of the color maps, you can choose any


for i in range(len(pid_data)):
    color = cmap(i)  # get color for each plot
    plt.plot(pid_data[i][0::3], color=color, label=f'PID{i}')
plt.legend()
plt.show()
