#!/bin/bash

# NFS server IP address and share path
NFS_SERVER_IP="x.x.x.x"
NFS_SHARE_PATH="/path/to/share"
SSH_PORT="xxxx"  # Custom SSH port
SSH_PRIVATE_KEY="$HOME/.ssh/id_rsa" # Adjust path if the SSH key is located elsewhere

# Function to ensure NFS share is mounted
function ensure_nfs_mount {
    local mount_point="/mnt/Archival_Pool"
    if ! mountpoint -q $mount_point; then
        echo "NFS share is not mounted. Attempting to mount..."
        sudo mount -t nfs -o port=$SSH_PORT $NFS_SERVER_IP:$NFS_SHARE_PATH $mount_point
        if [ $? -ne 0 ]; then
            echo "Failed to mount NFS share."
            exit 1
        else
            echo "NFS share mounted successfully."
        fi
    fi
}

# Function to ensure directory exists on both NFS share and local machine
function ensure_directories {
    local dir="$1"
    # Ensure directory exists on NFS share
    if ! sudo ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT $NFS_SERVER_IP "[ -d '$dir' ]"; then
        echo "Creating directory: $dir on NFS share"
        sudo ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT $NFS_SERVER_IP "mkdir -p '$dir'"
    fi
    # Ensure directory exists locally
    if [ ! -d "$dir" ]; then
        echo "Creating directory: $dir locally"
        sudo mkdir -p "$dir"
    fi
}

# Function for backup operation
function perform_backup {
    echo "Performing backup..."
    
    # Start ssh-agent and add your SSH key
    eval $(ssh-agent)
    ssh-add "$SSH_PRIVATE_KEY"

    # Ensure NFS share is mounted
    ensure_nfs_mount

    # Prompt user for backup folder name
    read -p "Enter a name for the backup folder (leave blank for default timestamp): " backup_name
    if [ -z "$backup_name" ]; then
        backup_name=$(date +%Y%m%d)
    fi

    # Define full backup directory path on NFS share
    BACKUP_DIR="$NFS_SHARE_PATH/$backup_name"

    # Ensure directories exist on NFS share and locally
    ensure_directories "$BACKUP_DIR/etc/pve/"
    ensure_directories "$BACKUP_DIR/etc/network/"
    ensure_directories "$BACKUP_DIR/etc/"
    ensure_directories "$BACKUP_DIR/root/.ssh/"
    ensure_directories "$BACKUP_DIR/etc/ssh/"
    ensure_directories "$BACKUP_DIR/var/lib/pve-cluster/"
    ensure_directories "$BACKUP_DIR/root/scripts/"

    # Backup configuration files to NFS share
    sudo rsync -av -e "ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT" /etc/pve/ "$NFS_SERVER_IP:$BACKUP_DIR/etc/pve/"
    sudo rsync -av -e "ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT" /etc/network/interfaces "$NFS_SERVER_IP:$BACKUP_DIR/etc/network/interfaces"
    sudo rsync -av -e "ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT" /etc/hosts "$NFS_SERVER_IP:$BACKUP_DIR/etc/hosts"
    sudo rsync -av -e "ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT" /etc/resolv.conf "$NFS_SERVER_IP:$BACKUP_DIR/etc/resolv.conf"
    sudo rsync -av -e "ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT" /etc/fstab "$NFS_SERVER_IP:$BACKUP_DIR/etc/fstab"
    sudo rsync -av -e "ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT" /root/.ssh/ "$NFS_SERVER_IP:$BACKUP_DIR/root/.ssh/"
    sudo rsync -av -e "ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT" /etc/ssh/ "$NFS_SERVER_IP:$BACKUP_DIR/etc/ssh/"
    sudo rsync -av -e "ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT" /var/lib/pve-cluster/ "$NFS_SERVER_IP:$BACKUP_DIR/var/lib/pve-cluster/"
    sudo rsync -av -e "ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT" /root/scripts/ "$NFS_SERVER_IP:$BACKUP_DIR/root/scripts/"

    # Backup crontab to NFS share
    sudo crontab -l | sudo ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT $NFS_SERVER_IP "cat > '$BACKUP_DIR/crontab_backup'"

    echo "Backup completed and stored in $BACKUP_DIR"
    # Stop ssh-agent
    ssh-agent -k
    exit 0
}

# Function for restore operation
function perform_restore {
    echo "Performing restore..."

    # Start ssh-agent and add your SSH key
    eval $(ssh-agent)
    ssh-add "$SSH_PRIVATE_KEY"

    # Ensure NFS share is mounted
    ensure_nfs_mount

    # List all backup directories on NFS share in numerical order
    echo "Available backup directories:"
    backup_dirs=($(sudo ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT $NFS_SERVER_IP "ls -d1 $NFS_SHARE_PATH/*/ | sort -t/ -k6 -g"))

    # Display numbered list of directories
    for i in "${!backup_dirs[@]}"; do
        echo "$i: ${backup_dirs[$i]}"
    done

    # Ask user to select a backup directory
    read -p "Enter the number of the backup directory to restore from: " choice

    # Validate user input
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 )) || (( choice >= ${#backup_dirs[@]} )); then
        echo "Invalid choice. Please enter a valid number."
        exit 1
    fi

    selected_backup="${backup_dirs[$choice]}"
    echo "Selected backup directory: $selected_backup"

    # Confirm with the user before proceeding
    read -p "Is this the backup directory you wish to restore from? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Aborted."
        exit 1
    fi

    # Ensure directories exist on local machine
    ensure_directories "/etc/pve/"
    ensure_directories "/etc/network/"
    ensure_directories "/etc/"
    ensure_directories "/root/.ssh/"
    ensure_directories "/etc/ssh/"
    ensure_directories "/var/lib/pve-cluster/"
    ensure_directories "/root/scripts/"

    # Use rsync to recursively copy directories and their contents
    sudo rsync -av -e "ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT" $NFS_SERVER_IP:$selected_backup/ / --delete

    echo "Restore completed."
    # Stop ssh-agent
    ssh-agent -k
    exit 0
}

# Main script logic
while true; do
    echo "What would you like to do?"
    echo "1. Create a new backup"
    echo "2. Restore from an existing backup"
    echo "3. Exit"

    read -p "Enter your choice (1, 2, or 3): " choice

    case $choice in
        1)
            perform_backup
            ;;
        2)
            perform_restore
            ;;
        3)
            echo "Exiting script."
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, or 3."
            ;;
    esac
done

