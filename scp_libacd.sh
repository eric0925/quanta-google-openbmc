#!/bin/bash
source /home/ericlee/quanta_openbmc_toolbox/ssh_utils.sh
# 請確保你有定義 BASE_TOOL_PATH，或者直接改成絕對路徑
if [ -z "$BASE_TOOL_PATH" ]; then
    BASE_TOOL_PATH="$HOME" # 預設 fallback 到家目錄，可依實際狀況調整
fi

select_machine_from_conf

LINE_LENGTH=60
SEPARATOR=$(printf '%*s' "$LINE_LENGTH" '' | tr ' ' '=')

echo "$SEPARATOR"
echo "Starting remote execution on root@$bmc_ip..."
echo "$SEPARATOR"

# 使用單引號包裹，確保 $(gpiofind ...) 的命令替換是在「遠端 BMC」上執行，而不是在你的本地端

sshpass -p "$PASS" scp $HOME/repo_GSN/build-gsn/tmp/work/cortexa35-openbmc-linux/crashdump/git/package/usr/lib/libacd.so.1.0 root@"$bmc_ip":/home/root

sshpass -p "$PASS" ssh root@"${bmc_ip}" << EOF
    cd /home/root
    
    echo "updating libacd.so soft links..."
    # 建立 libacd.so 導向 libacd.so.1.0
    ln -sf libacd.so.1.0 libacd.so
    
    # 建立 libacd.so.1 導向 libacd.so.1.0
    ln -sf libacd.so.1.0 libacd.so.1
    
    echo "遠端檔案與連結狀態："
    ls -l libacd.so*
EOF

if [ $? -ne 0 ]; then
    echo "$SEPARATOR"
    echo "Error: Failed to connect or execute commands on $bmc_ip"
    exit 1
fi

echo "$SEPARATOR"
echo "Execution completed successfully."
echo "$SEPARATOR"
