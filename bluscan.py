from bleak import BleakScanner

# Scan Bluetooth devices and display their information
async def scan_devices():
    devices = await BleakScanner.discover()
    for device in devices:
        print(f"Device {device.name} at {device.address}, RSSI: {device.rssi}")

# Run the scanner
import asyncio
asyncio.run(scan_devices())
