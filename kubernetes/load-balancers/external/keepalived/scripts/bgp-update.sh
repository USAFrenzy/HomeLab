#!/bin/bash

##############################################################################################################
# This script is used to add or remove the BGP neighbor for pfSense and the network statement for the VIP
# dynamically from the running FRR configuration. The intention of this script is to leave the base frr
# configuration untouched and only add or remove the necessary statements of the running bgp configurations
# when the VIP is gained or lost on the load-balanced load balancers. The reason for this is to minimize the
# amount of configuration changes that are made to the FRR configuration on disk as well as well as to minimize
# the amount of logs that are generated from the FRR daemon when the VIP neighbor lines are present without
# having acquired the VIP. This script is intended to be run as a update script via keepalived when keepalived
# transitions states from MASTER to BACKUP and vice versa.
##############################################################################################################

# Define variables
LOG_FILE="/var/log/keepalived-scripts.log"
VM_LOOPBACK="$(ip -4 addr show dev lo | grep inet | awk '{print $2}' | cut -d'/' -f1 | grep -v '127.0.0.1')"
VIP="192.168.20.5"
PEER="10.10.10.1"
LOCAL_AS="65202"
REMOTE_AS="65200"
NETWORK_VIP="$VIP/32"
PEER_DESCRIPTION="pfSense localhost VIP"

# Define functions (easier to read and maintain vs what was going on with the repeating logic previously)
function bgp_neighbor_exists {
    if sudo vtysh -c "show ip bgp neighbors" | grep -q "$1"; then
        return 0
    else
        return 1
    fi
}

function bgp_network_exists {
    if sudo vtysh -c "show ip bgp" | grep -q "$1"; then
        return 0
    else
        return 1
    fi
}

function write_bgp_neighbor {
    echo "Writing BGP neighbor configuration for $PEER." >> $LOG_FILE
    sudo vtysh -c "configure terminal" -c "router bgp $LOCAL_AS" \
        -c "neighbor $PEER remote-as $REMOTE_AS" \
        -c "neighbor $PEER description $PEER_DESCRIPTION" \
        -c "neighbor $PEER ebgp-multihop" \
        -c "neighbor $PEER update-source $VM_LOOPBACK" \
        >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
        echo "Error occurred while adding BGP neighbor $PEER." >> $LOG_FILE
    fi
}

function write_bgp_network {
    echo "Writing BGP network configuration for $NETWORK_VIP." >> $LOG_FILE
    sudo vtysh -c "configure terminal" -c "router bgp $LOCAL_AS" \
        -c "network $NETWORK_VIP" \
        >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
        echo "Error occurred while adding BGP network $NETWORK_VIP." >> $LOG_FILE
    fi
}

function verify_bgp_neighbor {
    local neighbor_config
    neighbor_config=$(sudo vtysh -c "show running-config" | grep -A 5 "neighbor $PEER")

    if [[ ! $neighbor_config =~ "remote-as $REMOTE_AS" ]] || \
       [[ ! $neighbor_config =~ "update-source $VM_LOOPBACK" ]] || \
       [[ ! $neighbor_config =~ "description $PEER_DESCRIPTION" ]] || \
       [[ ! $neighbor_config =~ ebgp-multihop ]]; then
        echo "BGP neighbor $PEER configuration mismatch detected." >> $LOG_FILE
        write_bgp_neighbor
    else
        echo "BGP neighbor $PEER configuration is correct." >> $LOG_FILE
    fi
}


function verify_bgp_network {
    if ! bgp_network_exists "$NETWORK_VIP"; then
        echo "BGP network $NETWORK_VIP configuration mismatch detected." >> $LOG_FILE
        write_bgp_network
    else
        echo "BGP network $NETWORK_VIP configuration is correct." >> $LOG_FILE
    fi
}

#
################################################# Actual Script Logic #################################################

# Check if VIP is present
if ip addr show | grep -q "$VIP"; then
    echo "VIP is present. Ensuring BGP configuration is active." >> $LOG_FILE

    # Check and apply BGP neighbor configuration
    if ! bgp_neighbor_exists "$PEER"; then
        echo "BGP neighbor $PEER not found. Adding neighbor configuration." >> $LOG_FILE
        write_bgp_neighbor
    else
        echo "BGP neighbor $PEER found. Verifying neighbor configuration." >> $LOG_FILE
        verify_bgp_neighbor
    fi

    # Check and apply BGP network configuration
    if ! bgp_network_exists "$NETWORK_VIP"; then
        echo "BGP network $NETWORK_VIP not found. Adding network configuration." >> $LOG_FILE
        write_bgp_network
    else
        echo "BGP network $NETWORK_VIP Found. Verifying network configuration." >> $LOG_FILE
        verify_bgp_network
    fi
else
    echo "VIP $VIP is not present. Ensuring BGP configuration is removed." >> $LOG_FILE

    # Check and remove BGP neighbor if it exists
    if bgp_neighbor_exists "$PEER"; then
        echo "BGP neighbor $PEER exists. Removing neighbor configuration." >> $LOG_FILE
        sudo vtysh -c "configure terminal" -c "router bgp $LOCAL_AS" \
            -c "no neighbor $PEER" \
            >> $LOG_FILE 2>&1
        if [ $? -ne 0 ]; then
            echo "Error occurred while removing BGP neighbor $PEER." >> $LOG_FILE
        fi
    else
        echo "BGP neighbor $PEER does not exist. No action needed." >> $LOG_FILE
    fi

    # Check and remove BGP network if it exists
    if bgp_network_exists "$NETWORK_VIP"; then
        echo "BGP network $NETWORK_VIP exists. Removing network configuration." >> $LOG_FILE
        sudo vtysh -c "configure terminal" -c "router bgp $LOCAL_AS" \
            -c "no network $NETWORK_VIP" \
            >> $LOG_FILE 2>&1
        if [ $? -ne 0 ]; then
            echo "Error occurred while removing BGP network $NETWORK_VIP." >> $LOG_FILE
        fi
    else
        echo "BGP network $NETWORK_VIP does not exist. No action needed." >> $LOG_FILE
    fi
fi
