import pyautogui
import time
import pygetwindow as gw

# Get a specific window by its title
bonsai = gw.getWindowsWithTitle('fmon-pid.bonsai')[0]
bpod = gw.getWindowsWithTitle('Bpod Console')[0]

# Activate the window
bonsai.activate()

# Wait for the window to be active
time.sleep(1)

# Start Bonsai
pyautogui.press('f5')

# Wait for the window to be active
time.sleep(1)

# Activate the window
bpod.activate()
