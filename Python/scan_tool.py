#!/usr/bin/env python

# Import the necessary packages
import os
import subprocess
import shutil
import argparse
import logging
import json
from datetime import datetime

# Set up logging
logging.basicConfig(filename='scan_tool.log', level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

# Check if the necessary tools are installed
required_tools = ['nmap', 'dnsrecon', 'dnsenum', 'whois', 'sslscan', 'nikto']
for tool in required_tools:
    if not shutil.which(tool):
        logging.error(f"Tool {tool} is not installed. Please install it.")
        print(f"Tool {tool} is not installed. Please install it.")
        exit(1)

# Parse command-line arguments
parser = argparse.ArgumentParser(
    description="Initial Domain/IP Scanning Tool - This tool runs a series of scans on a given domain or IP, including Nmap, DNSRecon, DNSenum, and more. Use the flags to specify which scans to perform."
)

parser.add_argument('--domain', help='Domain to scan (e.g., example.com)')
parser.add_argument('--ip', help='IP address to scan (e.g., 192.168.1.1)')
parser.add_argument('--scan', choices=['nmap', 'dnsrecon', 'dnsenum', 'whois', 'sslscan', 'nikto', 'all'],
                    default='all', help='Specify which scan to perform. Options are: '
                                         '"nmap" (Nmap scan), "dnsrecon" (DNSRecon scan), "dnsenum" (DNSenum scan), '
                                         '"whois" (WhoIs lookup), "sslscan" (SSL/TLS scan), "nikto" (Nikto vulnerability scan), or "all" (all scans).')

args = parser.parse_args()

# Prompt for domain and IP if not provided via arguments
domain = args.domain if args.domain else input("Enter the domain (press Enter to skip): ")
IP = args.ip if args.ip else input("Enter the IP address (press Enter to skip): ")

# Skip operations if no input is provided
if not domain and not IP:
    logging.warning("No domain or IP provided. Skipping...")
    print("No domain or IP provided. Skipping...")
    exit(0)

# Prepare the report data
report = {
    "domain": domain,
    "ip": IP,
    "scan_time": str(datetime.now()),
    "results": {}
}

# Function to perform a DNSRecon scan
def dnsrecon_scan():
    try:
        logging.info(f"Performing DNSRecon scan on domain: {domain}")
        result = subprocess.check_output(f'dnsrecon -d {domain} -t std', shell=True)
        report["results"]["dnsrecon"] = result.decode()
    except Exception as e:
        logging.error(f"Error performing DNSRecon scan: {e}")

# Function to perform a DNSenum scan
def dnsenum_scan():
    try:
        logging.info(f"Performing DNSenum scan on domain: {domain}")
        result = subprocess.check_output(f'dnsenum {domain}', shell=True)
        report["results"]["dnsenum"] = result.decode()
    except Exception as e:
        logging.error(f"Error performing DNSenum scan: {e}")

# Function to perform a WhoIs query
def whois_query():
    try:
        logging.info(f"Performing WhoIs query on domain: {domain}")
        result = subprocess.check_output(f'whois {domain}', shell=True)
        report["results"]["whois"] = result.decode()
    except Exception as e:
        logging.error(f"Error performing WhoIs query: {e}")

# Function to perform an Nmap scan
def nmap_scan():
    try:
        logging.info(f"Performing stealth Nmap port scan on IP: {IP}")
        result = subprocess.check_output(f'sudo nmap -sS -Pn -n -T4 -p- -sV -O {IP}', shell=True)
        report["results"]["nmap"] = result.decode()
    except Exception as e:
        logging.error(f"Error performing Nmap scan: {e}")

# Function to perform an SSL scan
def ssl_scan():
    try:
        logging.info(f"Performing SSL/TLS scan on domain: {domain}")
        result = subprocess.check_output(f'sslscan {domain}', shell=True)
        report["results"]["sslscan"] = result.decode()
    except Exception as e:
        logging.error(f"Error performing SSL scan: {e}")

# Function to perform a Nikto vulnerability scan
def nikto_scan():
    try:
        logging.info(f"Performing Nikto vulnerability scan on domain: {domain}")
        result = subprocess.check_output(f'nikto -h {domain}', shell=True)
        report["results"]["nikto"] = result.decode()
    except Exception as e:
        logging.error(f"Error performing Nikto scan: {e}")

# Run selected scans
if args.scan == 'all' or args.scan == 'nmap':
    if IP:
        nmap_scan()

if args.scan == 'all' or args.scan == 'dnsrecon':
    if domain:
        dnsrecon_scan()

if args.scan == 'all' or args.scan == 'dnsenum':
    if domain:
        dnsenum_scan()

if args.scan == 'all' or args.scan == 'whois':
    if domain:
        whois_query()

if domain:
    ssl_scan()
    nikto_scan()

# Save the results to a file
with open(f"scan_report_{domain if domain else IP}.json", 'w') as report_file:
    json.dump(report, report_file, indent=4)

# Log the completion of the scan
logging.info(f"Scan completed for domain: {domain} and IP: {IP}")

# Provide feedback to the user
print(f"Scan report saved to scan_report_{domain if domain else IP}.json")
