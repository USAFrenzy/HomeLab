#!/bin/bash

# Define variables
VIP="192.168.20.5"
BGP_UPDATE_SCRIPT="/usr/local/bin/bgp-update.sh"
LOG_FILE="/var/log/keepalived-scripts.log"

update_bgp_configuration() {
    echo "Updating BGP configuration." >> $LOG_FILE
    sudo $BGP_UPDATE_SCRIPT
}

start_haproxy_and_update() {
    if sudo systemctl start haproxy 2>> $LOG_FILE; then
        return 0;
    else
        return 1;
    fi
}

stop_haproxy_and_update() {
    if sudo systemctl stop haproxy 2>> $LOG_FILE; then
      return 0;
    else
      return 1;
    fi
}

##############################################################################
# NOTE: A better approach to the below logic would be to check keepalived's
#       state but I currently don't know how to do that yet, so, a workaround
#       is to check if the VIP is assigned to this VM. This assumes that the
#       VIP is only assigned to the master node (admittedly, kind of hacky).
##############################################################################

echo "######################################################################################" >> $LOG_FILE
echo "Running chk_haproxy.sh at $(date)" >> $LOG_FILE

# Check if the VIP is assigned to this node
if ip addr show | grep -q "$VIP"; then
    # VIP is present, meaning we are the master according to keepalived
    if sudo systemctl is-active --quiet haproxy; then
        # HAProxy is running, so just update the BGP configuration
        echo "Keepalived master state detected and haproxy is running." >> $LOG_FILE
        update_bgp_configuration
    else
        # HAProxy is not running, so start HAProxy and then update BGP configuration
        echo "Keepalived master state detected without haproxy running. \
              Starting HAProxy and updating BGP configuration." \
              >> $LOG_FILE
        if start_haproxy_and_update; then
            echo "HAProxy started successfully." >> $LOG_FILE
            update_bgp_configuration
            echo "######################################################################################" >> $LOG_FILE
            echo "" >> $LOG_FILE
            exit 0
        else
            # Need to exit if HAProxy fails to start so that keepalived transitions to backup, on the next interval
            # check, the vip will no longer be present, so then the bgp configuration will be updated. This will result
            # in a minimum of 2 seconds to transition state, stop haproxy if it's still running, and update the bgp
            # configuration with 'interval 1' in the keepalived configuration.
            echo "Error occurred while starting HAProxy. Marking script as failed." >> $LOG_FILE
            echo "######################################################################################" >> $LOG_FILE
            echo "" >> $LOG_FILE
            exit 1
        fi
    fi
else
    # VIP is not present, meaning we are not the master here
    if sudo systemctl is-active --quiet haproxy; then
        # HAProxy is running, so stop it and update BGP configuration
        echo "Keepalived backup state detected with haproxy running. \
              Stopping HAProxy and updating BGP configuration." \
              >> $LOG_FILE
        if stop_haproxy_and_update; then
            echo "HAProxy stopped successfully." >> $LOG_FILE
        else
            echo "Error occurred while stopping HAProxy." >> $LOG_FILE
        fi
            update_bgp_configuration
            echo "######################################################################################" >> $LOG_FILE
            echo "" >> $LOG_FILE
    else
        # HAProxy is not running, so just update BGP configuration
        echo "Keepalived backup state detected and haproxy is not running." >> $LOG_FILE
        update_bgp_configuration
    fi
fi

echo "######################################################################################" >> $LOG_FILE
echo "" >> $LOG_FILE
