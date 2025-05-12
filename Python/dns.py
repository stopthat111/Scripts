#!/usr/bin/env python

# Import the necessary packages
import os
import subprocess

# Set the domain that needs to be scanned
domain = 'DOMAIN'

# Perform a DNSRecon scan on the domain
subprocess.call('dnsrecon -d %s -t std' % domain, shell=True)

# Perform a DNSenum scan on the domain
subprocess.call('dnsenum %s' % domain, shell=True)

# Perform a WhoIs call on the domain
subprocess.call('whois %s' % domain, shell=True)
