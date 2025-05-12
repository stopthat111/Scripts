#!/usr/bin/env python

# Import the necessary packages
import os
import subprocess

# Request user input for the domain
domain = input("Please enter the domain: ")

# Perform a EmailHarvester call on the domain
subprocess.call('emailharvester -d %s' % domain, shell=True)

# Perform a KnockPy scan on the domain
subprocess.call('knockpy %s' % domain, shell=True)
