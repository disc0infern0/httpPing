# Readme

<!--@START_MENU_TOKEN@-->Summary<!--@END_MENU_TOKEN@-->

## Overview

A small command-line tool that “pings” an HTTP/HTTPS URL, analogous to the Unix ping command but using HTTP instead of ICMP.

### Summary of featureset

• Accepts command line options (via Swift Argument Parser) or input from the console.
• Validates the input as a well formed HTTP URL and auto-adds https:// if a valid http scheme is missing.
• Sends a lightweight HTTP request (prefer HEAD, switching to GET if HEAD isn’t supported).
• Follows redirects while preserving the HTTP method where possible.
• Optionally repeats the check a specified number of times and displays summary min/mean/max/stddev of response times.
• Prints succinct or verbose output and exits with a shell-friendly exit code.
