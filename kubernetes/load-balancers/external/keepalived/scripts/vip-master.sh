#!/bin/bash
echo "Running vip-master.sh at $(date)" >> /var/log/keepalived-scripts.log
systemctl start haproxy >> /var/log/keepalived-scripts.log 2>&1
/usr/local/bin/bgp-update.sh >> /var/log/keepalived-scripts.log 2>&1
