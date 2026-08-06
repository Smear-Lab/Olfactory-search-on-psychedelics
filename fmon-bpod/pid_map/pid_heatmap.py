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

def plot_timeseries(data, colormap):
    # Create a color map
    cmap = plt.cm.get_cmap(colormap, len(data))  # 'viridis' is one of the color maps, you can choose any
    for i in range(len(data)):
        color = cmap(i)  # get color for each plot
        plt.plot(data[i][0::3], color=color, label=f'PID{i}')
    plt.legend()
    plt.show()


#plot_timeseries(pid_data, 'rainbow')


pid_means = [np.mean(x) for x in pid_data]
heatmap = np.zeros([5,7])
count = 0

for j in range(heatmap.shape[1]-1, -1, -1):
    for i in range(heatmap.shape[0]):
        heatmap[i, j] = pid_means[count]
        count += 1

#heatmap = np.flip(heatmap, axis=1)
heatmap = (heatmap - np.min(heatmap)) / (np.max(heatmap) - np.min(heatmap))
print(heatmap)

plt.imshow(heatmap)
plt.show()