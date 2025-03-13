import pyautogui
import time

# Define the coordinates for the clicks (replace with your specific coordinates)
# Example: (x1, y1) for the first position, (x2, y2) for the second position
position1 = (4134, 263)  # First position (replace with your coordinates)
position2 = (5113, 273)  # Second position (replace with your coordinates)

# Define the delay between clicks
delay = 2  # 2 seconds

print("Script is starting. Press Ctrl+C to stop.")

try:
    while True:
        # Click the first position
        pyautogui.click(position1)
        print(f"Clicked at {position1}")
        
        # Wait for the delay
        time.sleep(delay)
        
        # Click the second position
        pyautogui.click(position2)
        print(f"Clicked at {position2}")
        
        # Wait for the delay
        time.sleep(delay)

except KeyboardInterrupt:
    print("Script stopped by user.")
