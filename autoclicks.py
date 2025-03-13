import pyautogui
import time

# Function to prompt the user to click at a position
def get_click_position(prompt):
    input(f"{prompt} - Click on the screen and press Enter when done.")
    return pyautogui.position()

# Prompt the user to click to set the positions
print("Script is starting. Please click on the desired locations.")
position1 = get_click_position("First position (e.g., top-left corner)")
position2 = get_click_position("Second position (e.g., bottom-right corner)")

# Define the delay between clicks
delay = 2  # 2 seconds

print("Positions have been set. Script is now running. Press Ctrl+C to stop.")

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
