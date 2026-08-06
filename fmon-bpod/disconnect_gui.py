import pyautogui
import time
import pygetwindow as gw

# Get a specific window by its title
bonsai = gw.getWindowsWithTitle('bpod-fmon')[0]
bpod = gw.getWindowsWithTitle('Bpod Console')[0]

# Activate the window
bonsai.activate()

# Wait for the window to be active
time.sleep(.5)

# Stop Bonsai
pyautogui.hotkey('shift', 'f5')

# Wait for the keystroke to be counted
time.sleep(1)

# Activate the window
bpod.activate()