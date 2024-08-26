#!/bin/bash

##############################################################################################################
# This script is used to add or remove the BGP neighbor for pfSense and the network statement for the VIP
# dynamically from the running FRR configuration. The intention of this script is to leave the base frr
# configuration untouched and only add or remove the necessary statements of the running bgp configurations
# when the VIP is gained or lost on the load-balanced load balancers. This script is intended to be run as a
# update script via keepalived when keepalived transitions states from MASTER to BACKUP and vice versa. The
# reason for this is to minimize the amount of configuration changes that are made to the FRR configuration
# on disk as well as well as to minimize the amount of logs that are generated from the FRR daemon when the
# VIP neighbor lines are present without having acquired the VIP.
##############################################################################################################

# bgp-update.sh
echo "######################################################################################" >> /var/log/keepalived-scripts.log
echo "Running bgp-update.sh at $(date)" >> /var/log/keepalived-scripts.log

# Define variables
VM_LOOPBACK="$(ip -4 addr show dev lo | grep inet | awk '{print $2}' | cut -d'/' -f1 | grep -v '127.0.0.1')"
VIP="192.168.20.5"
PEER="10.10.10.1"
LOCAL_AS="65202"
REMOTE_AS="65200"
NETWORK_VIP="$VIP/32"

echo "Using Load Balancer Loopback Address of: $VM_LOOPBACK" >> /var/log/keepalived-scripts.log

function bgp_neighbor_exists {
    sudo vtysh -c "show ip bgp neighbors" | grep -q "Neighbor: $1"
}
function bgp_network_exists {
    sudo vtysh -c "show ip bgp" | grep -q "Network: $1"
}

# Remove any existing configuration for the neighbor and network
if bgp_neighbor_exists "$PEER"; then
    echo "Removing existing BGP neighbor $PEER." >> /var/log/keepalived-scripts.log
    sudo vtysh -c "configure terminal" -c "router bgp $LOCAL_AS" -c "no neighbor $PEER" >> /var/log/keepalived-scripts.log 2>&1
    if [ $? -ne 0 ]; then
        echo "Error occurred while removing BGP neighbor $PEER." >> /var/log/keepalived-scripts.log
    fi
fi

if bgp_network_exists "$NETWORK_VIP"; then
    echo "Removing existing BGP network $NETWORK_VIP." >> /var/log/keepalived-scripts.log
    sudo vtysh -c "configure terminal" -c "router bgp $LOCAL_AS" -c "no network $NETWORK_VIP" >> /var/log/keepalived-scripts.log 2>&1
    if [ $? -ne 0 ]; then
        echo "Error occurred while removing BGP network $NETWORK_VIP." >> /var/log/keepalived-scripts.log
    fi
fi

# Check if VIP is present
if ip addr show | grep -q "$VIP"; then
    echo "VIP is present. Adding BGP configuration." >> /var/log/keepalived-scripts.log
    # Add neighbor and network configuration if VIP is present
    sudo vtysh -c "configure terminal" -c "router bgp $LOCAL_AS" \
        -c "neighbor $PEER remote-as $REMOTE_AS" \
        -c "neighbor $PEER description pfSense localhost VIP" \
        -c "neighbor $PEER ebgp-multihop" \
        -c "neighbor $PEER update-source $VM_LOOPBACK" \
        -c "network $NETWORK_VIP" \
        >> /var/log/keepalived-scripts.log 2>&1

    if [ $? -ne 0 ]; then
        echo "Error occurred while adding BGP configuration." >> /var/log/keepalived-scripts.log
    fi
else
    echo "VIP $VIP is not present. Skipping BGP configuration." >> /var/log/keepalived-scripts.log
fi
echo "######################################################################################" >> /var/log/keepalived-scripts.log
echo "" >> /var/log/keepalived-scripts.log