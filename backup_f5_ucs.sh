#!/bin/bash
# please make sure that 'curl' and 'jq' was installed on the system
# 20240809_v0.3_EW

# Variables
F5_USER="your_f5_username"
F5_PASS="your_f5_password"
DOWNLOAD_DIR="/path/to/your/download/directory"
IP_LIST_FILE="f5_ip_list.txt"
LOG_DIR="./log"
LOG_FILE="$LOG_DIR/backup_log_$(date +%F).log"
YESTERDAY=$(date -d "yesterday" +%F)
MAX_BACKUPS=7

# Ensure the log directory exists and has the correct permissions
if [[ ! -d $LOG_DIR ]]; then
    mkdir -p $LOG_DIR
    chmod 600 $LOG_DIR
fi

# Function to log messages to the console and the log file
log_message() {
    local MESSAGE=$1
    echo "$MESSAGE"
    echo "$(date +%F_%T): $MESSAGE" >> "$LOG_FILE"
}

# Ensure the download directory exists and has the correct permissions
if [[ ! -d $DOWNLOAD_DIR ]]; then
    log_message "Download directory $DOWNLOAD_DIR does not exist. Creating it..."
    mkdir -p $DOWNLOAD_DIR
    chmod 600 $DOWNLOAD_DIR
    log_message "Download directory $DOWNLOAD_DIR created and permissions set to 600."
fi

# Function to save the running configuration of an F5 appliance to disk
save_running_config() {
    local F5_HOST=$1
    log_message "Saving running configuration on $F5_HOST..."
    save_config_response=$(curl -sku "$F5_USER:$F5_PASS" -m 600 -H "Content-Type: application/json" -X POST "https://$F5_HOST/mgmt/tm/sys/config" -d '{"command":"save"}')

    # Check if the config save was successful
    if [[ $(echo $save_config_response | jq -r .code) = "400" ]]; then
        log_message "Failed to save running configuration on $F5_HOST: $(echo $save_config_response | jq -r .message)"
        return 1
    fi

    log_message "Running configuration saved on $F5_HOST."
    return 0
}

# Function to create and download UCS backup from an F5 appliance
backup_f5() {
    local F5_HOST=$1
    local BACKUP_NAME="backup_$(date +%F_%H%M%S)_$F5_HOST"

    log_message "Creating UCS backup on $F5_HOST..."
    create_backup_response=$(curl -sku "$F5_USER:$F5_PASS" -m 600 -H "Content-Type: application/json" -X POST "https://$F5_HOST/mgmt/tm/sys/ucs" -d "{\"command\":\"save\",\"name\":\"$BACKUP_NAME\"}")

    # Check if the backup creation was successful
    if [[ $(echo $create_backup_response | jq -r .code) = "400" ]]; then
        log_message "Failed to create UCS backup on $F5_HOST: $(echo $create_backup_response | jq -r .message)"
        return 1
    fi

    # Download UCS Backup
    log_message "Downloading UCS backup from $F5_HOST..."
    #curl -sku "$F5_USER:$F5_PASS" -m 600 "https://$F5_HOST/mgmt/shared/file-transfer/ucs-downloads/$BACKUP_NAME.ucs" -o "$DOWNLOAD_DIR/$BACKUP_NAME.ucs"
    sshpass -p $F5_PASS scp -o StrictHostKeyChecking=no $F5_USER@$F5_HOST:/var/local/ucs/$BACKUP_NAME.ucs $DOWNLOAD_DIR

    # Check if the download was successful
    if [[ $? -ne 0 ]]; then
        log_message "Failed to download UCS backup from $F5_HOST"
        return 1
    fi

    log_message "UCS backup from $F5_HOST downloaded successfully to $DOWNLOAD_DIR/$BACKUP_NAME.ucs"
    return 0
}

# Function to delete UCS backups created yesterday from an F5 appliance
delete_old_backups() {
    local F5_HOST=$1

    log_message "Deleting UCS backups created on $YESTERDAY from $F5_HOST..."
    ucs_list=$(curl -sku "$F5_USER:$F5_PASS" -H "Content-Type: application/json" "https://$F5_HOST/mgmt/tm/sys/ucs" | jq -r ".items[] | select(.apiRawValues.file_created_date | startswith(\"$YESTERDAY\")) | .apiRawValues.filename" | sed 's/\/var\/local\/ucs\///')

    for ucs in $ucs_list; do
        delete_response=$(curl -sku "$F5_USER:$F5_PASS" -m 600 -H "Content-Type: application/json" -X DELETE "https://$F5_HOST/mgmt/tm/sys/ucs/$ucs")

        # Check if the deletion was successful
        if [[ $(echo $delete_response | jq -r .code) = "400" ]]; then
            log_message "Failed to delete UCS backup $ucs on $F5_HOST: $(echo $delete_response | jq -r .message)"
        else
            log_message "Deleted UCS backup $ucs from $F5_HOST"
        fi
    done
}

# Function to rotate local UCS backups if there are more than $MAX_BACKUPS for a single F5 appliance
rotate_local_backups() {
    local F5_HOST=$1
    local BACKUPS=($(ls -t "$DOWNLOAD_DIR"/backup_*_"$F5_HOST".ucs))

    if [[ ${#BACKUPS[@]} -gt $MAX_BACKUPS ]]; then
        log_message "Rotating local UCS backups for $F5_HOST. Keeping only the last $MAX_BACKUPS backups..."
        for ((i=$MAX_BACKUPS; i<${#BACKUPS[@]}; i++)); do
            rm -f "${BACKUPS[$i]}"
            log_message "Deleted old UCS backup ${BACKUPS[$i]}"
        done
    fi
}

# Main script to process the list of IP addresses
if [[ ! -f $IP_LIST_FILE ]]; then
    log_message "IP list file not found: $IP_LIST_FILE"
    exit 1
fi

while IFS= read -r F5_HOST; do
    if [[ -n "$F5_HOST" ]]; then
#        save_running_config "$F5_HOST"
        backup_f5 "$F5_HOST"
        delete_old_backups "$F5_HOST"
        rotate_local_backups "$F5_HOST"
    fi
done < "$IP_LIST_FILE"

exit 0
