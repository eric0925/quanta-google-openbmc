#!/bin/bash
# ==============================================================================
# File: /home/ericlee/quanta_openbmc_toolbox/ssh_utils.sh
# Description: Quanta OpenBMC Lab 共用工具包
# ==============================================================================
# 寫在這裡的變數，底下所有的 Function 都能直接讀取，不需要再各自 local 宣告
SERVER="http://10.10.10.203:8888"
conf_file="/home/ericlee/quanta_openbmc_toolbox/auto_ip_list.conf"
cookie_path="/home/ericlee/quanta_openbmc_toolbox/cookie.txt"

select_machine_from_conf() {
    if [ ! -f "$conf_file" ]; then
        echo "Error: Configuration file $conf_file not found!"
        return 1
    fi

    cat "$conf_file"
    echo "========================================================================================================="

    local num
    read -p "Enter Machine ID: " num

    # 3. 精確搜尋該行
    local line
    line=$(grep -E "^${num}[[:space:]]*\|" "$conf_file")

    if [ -z "$line" ]; then
        echo "Invalid Machine ID"
        return 1
    fi

    IFS='|' read -r id device detail location bmc_ip console status user<<< "$line"

    id=$(echo "$id" | xargs)
    device=$(echo "$device" | xargs)
    detail=$(echo "$detail" | xargs)
    location=$(echo "$location" | xargs)
    bmc_ip=$(echo "$bmc_ip" | xargs)
    console=$(echo "$console" | xargs)
    status=$(echo "$status" | xargs)
    user=$(echo "$user" | xargs)

    # 1. 取得 : 號前面的部分 (console_ip)
    # ${var%%:*} 的意思是：從變數右邊開始刪除，直到遇到第一個冒號
    console_ip="10.10.${console%%:*}"

    # 2. 取得 : 號後面的部分 (console_port)
    # ${var#*:} 的意思是：從變數左邊開始刪除，直到遇到第一個冒號
    console_port="${console#*:}"

    echo "Device       : $device"
    echo "Location     : $location"
    echo "BMC IP       : $bmc_ip"
    echo "Console IP   : $console_ip"
    echo "Console Port : $console_port"
    echo "Status       : $status"
    echo "User         : $user"

    if [ "$status" = "available" ]; then
        echo "📡 Machine is available. Automatically registering [ $device ] on the webpage..."
        curl -s -b "$cookie_path" -X POST "$SERVER/api/actions" \
             -H "Content-Type: application/json" \
             -d "{
                 \"type\": \"use_now\",
                 \"machineId\": $id
             }" > /dev/null
    else
        echo "Machine is already $status (User: $user). Skipping webpage registration."
    fi
    return 0
}


update_machine_list() {
    local tmp_file="${conf_file}.tmp"

    echo "Updating machine list from server..."

    mkdir -p "$(dirname "$conf_file")"
    local response
    response=$(curl -s -m 5 -b "$cookie_path" "$SERVER/api/state")

    if echo "$response" | grep -q "請先登入"; then
        echo "Cookie has expired. Attempting automatic login..."

        curl -s -m 5 -c "$cookie_path" \
             -H "Content-Type: application/json" \
             -d '{"userId":"your_userId", "password":"your_password"}' \
             "$SERVER/api/login" > /dev/null

        echo "Login completed. Retrying to fetch machine list..."
        # 登入後重新抓取一次回應
        response=$(curl -s -m 5 -b "$cookie_path" "$SERVER/api/state")
    fi
    # 連線抓取、jq 解析、awk 排版，並先導向至暫存檔 (.tmp)
    curl -s -m 5 -b $cookie_path "$SERVER/api/state" |
        jq -r '.machines[] | "\(.id)|\(.name)|\(.code)|\(.location)|\(.bmcIp)|\(.consoleIp)|\(.consolePort)|\(.status)|\(.user)"' 2>/dev/null |
        awk -F'|' '
        function pad(str, width,   i, len, res) {
            res = str
            len = length(str)
            for (i=1; i<=length(str); i++) {
                if (substr(str, i, 1) ~ /[^ -~]/) len++
            }
            for (i = len; i < width; i++) {
                res = res " "
            }
            if (len > width) {
                return substr(res, 1, width)
            }
            return res
        }

        BEGIN {
            LINE_LENGTH = 120
            for (i = 1; i <= LINE_LENGTH; i++) SEPARATOR = SEPARATOR "-"
            print SEPARATOR

            printf "%s | %s | %s | %s | %s | %s | %s | %s\n",
                   pad("ID", 3), pad("Device", 13), pad("Detail", 23), pad("Location", 15),
                   pad("BMC IP", 13), pad("Console", 11), pad("Status", 10), pad("User", 10)
            print SEPARATOR
        }
        {
            sub(/^10\.10\./, "", $6)
            console_str = $6 ":" $7

            if ($9 == "null") $9 = "-"

            printf "%s | %s | %s | %s | %s | %s | %s | %s\n",
                   pad($1, 3), pad($2, 13), pad($3, 23), pad($4, 15),
                   pad($5, 13), pad(console_str, 11), pad($8, 10), pad($9, 10)
        }' > "$tmp_file"

    # 檢查 jq 是否解析成功
    if [ ${PIPESTATUS[1]} -eq 0 ] && [ -s "$tmp_file" ]; then
        mv "$tmp_file" "$conf_file"
        echo "Update successful."
        return 0
    else
        # 移除爛掉的暫存檔，完整保留原本舊的完好檔案
        rm -f "$tmp_file"
        echo "Warning: Server API error or offline! Using cached machine list."

        # 如果本地連舊檔都沒有，那才算真正失敗
        if [ ! -f "$conf_file" ]; then
            echo "Error: No local cache file available."
            return 1
        fi
        return 0
    fi
}

# ==============================================================================
# Function: autossh
# Description: 快速使用ssh連線機器，如果遇到連線失敗，會自動ssh-keygen然後再連線一次
# ==============================================================================
autossh(){
    update_machine_list

    select_machine_from_conf

    CMD="sshpass -p 0penBmc ssh -o StrictHostKeyChecking=no root@$bmc_ip"
    echo
    echo "execute the command:"
    echo "$CMD"
    echo

    eval $CMD
    CMD_RESULT=$?
    if [ $CMD_RESULT -eq 255 ]; then
        echo
        echo "SSH failed with code 255"
        echo "Remove old host key for $bmc_ip"
        ssh-keygen -f "/home/ericlee/.ssh/known_hosts" -R "$bmc_ip"
        echo
        echo "Retry ssh connection..."
        echo
        eval "$CMD"
    fi
}

# ==============================================================================
# Function: mtelent
# Description: 快速使用telnet連線機器
# ==============================================================================
mtelent(){
update_machine_list

select_machine_from_conf
    if [ $? -ne 0 ]; then exit 1; fi
    echo "Connecting to Console: telnet $console_ip:$console_port"
    telnet "$console_ip" "$console_port"
}

# ==============================================================================
# Function: mfree
# Description: 安全版釋放工具。印出清單、讓使用者選 ID、並檢查是否為本人使用的機台。
# ==============================================================================
mfree() {
    local MY_NAME="Eric Lee"

    update_machine_list
    if [ $? -ne 0 ]; then return 1; fi

    cat "$conf_file"

    # 2. 讓使用者輸入想要釋放的 ID
    local num
    read -p "Enter Machine ID to RELEASE: " num

    # 3. 從檔案精確搜尋該行
    local line
    line=$(grep -E "^${num}[[:space:]]*\|" "$conf_file")
    if [ -z "$line" ]; then
        echo "Error: Invalid Machine ID"
        return 1
    fi

    # 4. 解析該機台目前在檔案裡的狀態與使用者 (配合 8 欄縮減版格式)
    local id device detail location bmc_ip console status current_user
    IFS='|' read -r id device detail location bmc_ip console status current_user <<< "$line"
    current_user=$(echo "$current_user" | xargs)
    device=$(echo "$device" | xargs)
    id=$(echo "$id" | xargs)

    # 5.【核心防護機制】檢查是不是我本人
    if [ "$current_user" = "null" ] || [ "$current_user" = "-" ]; then
        echo "Machine [ $device ] (ID: $id) is already available. No need to release."
        return 0
    elif [ "$current_user" != "$MY_NAME" ]; then
        # 抓到現行犯！使用者不是你，拒絕執行，保護同事！
        echo "Permission Denied! This machine is currently used by [ $current_user ]."
        echo "   You can only release machines occupied by yourself ($MY_NAME)."
        return 1
    fi

    # 6. 通過驗證，確認是 Eric Lee 本人的機器，發送 API 釋出
    echo "Verified! Sending request to release [ $device ] (ID: $id)..."
    local response
    response=$(curl -s -m 5 -b "$cookie_path" -X POST "$SERVER/api/actions" \
         -H "Content-Type: application/json" \
         -d "{\"type\": \"end_use\", \"machineId\": $id, \"force\": false}")

    # 7. 檢查 Cookie 是否過期
    if echo "$response" | grep -q "請先登入"; then
        echo "Cookie expired. Re-logging in..."
        curl -s -m 5 -c "$cookie_path" \
             -H "Content-Type: application/json" \
             -d '{"username":"ericlee", "password":"your_password"}' \
             "$SERVER/api/login" > /dev/null

        response=$(curl -s -m 5 -b "$cookie_path" -X POST "$SERVER/api/actions" \
             -H "Content-Type: application/json" \
             -d "{\"type\": \"end_use\", \"machineId\": $id, \"force\": false}")
    fi

    # 8. 顯示最終結果
    if echo "$response" | grep -q "error"; then
        echo "Failed to release machine. Server response: $response"
        return 1
    else
        echo "Success! Machine [ $device ] is now released and free for others."
        return 0
    fi
}


