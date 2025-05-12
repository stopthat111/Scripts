import asyncio
from bleak import BleakScanner
import math

# Constants: known RSSI at 1 meter and known distance
A = -78  # RSSI at 1 meter (from device at 1 meter)
n = 2    # Path loss exponent (2 is typical in free space, but adjust based on environment)

async def scan_bluetooth_devices():
    devices = await BleakScanner.discover()
    print("Found {} device(s):".format(len(devices)))
    for device in devices:
        rssi = device.rssi  # Use device.rssi directly

        if rssi is not None:
            # Calculate the estimated distance using the RSSI
            distance = 10 ** ((A - rssi) / (10 * n))  # Apply the path loss model
            print(f"Device Address: {device.address}, Device Name: {device.name}, RSSI: {rssi}")
            print(f"Estimated Distance: {distance:.2f} meters\n")
        else:
            print(f"Device Address: {device.address}, Device Name: {device.name}, RSSI: No data\n")

async def main():
    print("Scanning for Bluetooth devices...")
    await scan_bluetooth_devices()

if __name__ == "__main__":
    asyncio.run(main())
