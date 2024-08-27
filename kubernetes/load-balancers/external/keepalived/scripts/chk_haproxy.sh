#!/bin/bash

# Define variables
VIP="192.168.20.5"
BGP_UPDATE_SCRIPT="/usr/local/bin/bgp-update.sh"
LOG_FILE="/var/log/keepalived-scripts.log"

start_haproxy_and_update() {
    echo "Keepalived master state detected without haproxy running. \
          Starting HAProxy and updating BGP configuration." \
          >> $LOG_FILE
    if sudo systemctl start haproxy 2>> $LOG_FILE; then
        echo "HAProxy started successfully." >> $LOG_FILE
    else
        echo "Error occurred while starting HAProxy." >> $LOG_FILE
    fi
    $BGP_UPDATE_SCRIPT
}

stop_haproxy_and_update() {
    echo "Keepalived backup state detected with haproxy running. \
          Stopping HAProxy and updating BGP configuration." \
          >> $LOG_FILE
    if sudo systemctl stop haproxy 2>> $LOG_FILE; then
        echo "HAProxy stopped successfully." >> $LOG_FILE
    else
        echo "Error occurred while stopping HAProxy." >> $LOG_FILE
    fi
    $BGP_UPDATE_SCRIPT
}

update_bgp_configuration() {
    echo "Updating BGP configuration." >> $LOG_FILE
    $BGP_UPDATE_SCRIPT
}

##############################################################################
# NOTE: A better approach to the below logic would be to check keepalived's
#       state but I currently don't know how to do that yet, so, a workaround
#       is to check if the VIP is assigned to this VM. This assumes that the
#       VIP is only assigned to the master node (admittedly, kind of hacky).
##############################################################################

# Check if the VIP is assigned to this node
if ip addr show | grep -q "$VIP"; then
    # VIP is present, meaning we are the master according to keepalived
    if pgrep haproxy > /dev/null; then
        # HAProxy is running, so just update the BGP configuration
        echo "Keepalived master state detected and, as intended, haproxy is running." >> $LOG_FILE
        update_bgp_configuration
    else
        # HAProxy is not running, so start HAProxy and then update BGP configuration
        start_haproxy_and_update
    fi
else
    # VIP is not present, meaning we are not the master here
    if pgrep haproxy > /dev/null; then
        # HAProxy is running, so stop it and update BGP configuration
        stop_haproxy_and_update
    else
        # HAProxy is not running, so just update BGP configuration
        echo "Keepalived backup state detected and, as intended, haproxy is not running." >> $LOG_FILE
        update_bgp_configuration
    fi
fi
