#!/bin/bash

LOG_FILE="/tmp/node_sync_buffer.txt"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

calculate_progress() {
    local current=$1
    local target=$2
    if [[ $target -gt 0 ]]; then
        echo $(awk -v current="$current" -v target="$target" 'BEGIN { printf "%.2f", (current/target)*100 }')
    else
        echo "0.00"
    fi
}

print_progress() {
    local target_main=$1
    local target_resource=$2
    local my_main=$3
    local my_resource=$4

    local main_progress=$(calculate_progress $my_main $target_main)
    local resource_progress=$(calculate_progress $my_resource $target_resource)

    echo -e "${GREEN}Main Block Sync Progress: ${main_progress}%${NC}"
    echo -e "${GREEN}Resource Block Sync Progress: ${resource_progress}%${NC}"
}

sync_node() {
    > $LOG_FILE

    docker exec -i saseul-node saseul-script forcesync --peer main.saseul.net 2>&1 | tee -a $LOG_FILE &
    PID=$!

    sleep 10
    echo >> "$LOG_FILE"

    local update_main=0
    local update_resource=0

    tail -f $LOG_FILE | while read LINE; do
        case "$LINE" in
            *"Target Last Main Block:"*)
                TARGET_MAIN=$(echo $LINE | awk '{print $5}')
                ;;
            *"Target Last Resource Block:"*)
                TARGET_RESOURCE=$(echo $LINE | awk '{print $5}')
                ;;
            *"Main Block Sync:"*)
                MY_MAIN=$(echo $LINE | awk '{print $4}')
                update_main=1
                ;;
            *"Resource Block Sync:"*)
                MY_RESOURCE=$(echo $LINE | awk '{print $4}')
                update_resource=1
                ;;
            *"Connection failed. Retry.. 5"* | "There is no data."*)
                kill $PID
                break
                ;;
        esac

        if [[ $update_main -eq 1 && $update_resource -eq 1 ]]; then
            print_progress $TARGET_MAIN $TARGET_RESOURCE $MY_MAIN $MY_RESOURCE
            update_main=0
            update_resource=0
        fi
    done
}

echo -e "${GREEN}########## 노드 동기화를 시작합니다... ##########${NC}"

while true; do 
    sync_node
    echo -e "${YELLOW}########## Peer 연결 시도 중 문제가 발생했습니다. 재시도 합니다... ##########${NC}"
    sleep 1
done
