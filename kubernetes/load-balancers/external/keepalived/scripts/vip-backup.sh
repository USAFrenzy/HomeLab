#!/bin/bash
echo "Running vip-backup.sh at $(date)" >> /var/log/keepalived-scripts.log
systemctl stop haproxy >> /var/log/keepalived-scripts.log 2>&1
/usr/local/bin/bgp-update.sh >> /var/log/keepalived-scripts.log 2>&1
