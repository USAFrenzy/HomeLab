#!/bin/bash
if pgrep haproxy > /dev/null; then
  exit 0  # Service is running
else
  exit 1  # Service is not running
fi
