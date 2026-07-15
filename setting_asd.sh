#!/bin/bash
source /home/ericlee/quanta_openbmc_toolbox/ssh_utils.sh
# 請確保你有定義 BASE_TOOL_PATH，或者直接改成絕對路徑

select_machine_from_conf

# 固定長度的分隔線
LINE_LENGTH=60
SEPARATOR=$(printf '%*s' "$LINE_LENGTH" '' | tr ' ' '=')

echo "$SEPARATOR"
echo "Starting remote execution on root@$bmc_ip..."
echo "$SEPARATOR"

# 使用單引號包裹，確保 $(gpiofind ...) 的命令替換是在「遠端 BMC」上執行，而不是在你的本地端
REMOTE_COMMANDS=$(cat << 'EOF'
    echo "Stopping nftables..."
    systemctl stop nftables.service 

    echo "Setting JTAG GPIOs..."
    gpioset -m exit $(gpiofind "JTAG_MUX_SEL_DEBUG_R_N")=0 
    gpioset -m exit $(gpiofind "JTAG_MUX_SEL_HPM_R_N")=0 
    gpioset -m exit $(gpiofind "JTAG_SCM_MUX_OE_HPM0")=0 
    gpioset -m exit $(gpiofind "JTAG_SCM_MUX_SEL_HPM0")=1 

    echo "Launching ASD daemon..."
    /usr/bin/asd -u --xdp-ignore --cpu-index 0 
EOF
)
$PASS="0penBmc"
# 3. 透過 sshpass 遠端執行
# 加上 -o ConnectTimeout 避免遠端掛掉時腳本卡死
echo "executing: sshpass -p \"0penBmc\" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@\"$bmc_ip\" \"$REMOTE_COMMANDS\""
sshpass -p 0penBmc ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$bmc_ip" "$REMOTE_COMMANDS"

if [ $? -ne 0 ]; then
    echo "$SEPARATOR"
    echo "Error: Failed to connect or execute commands on $bmc_ip"
    exit 1
fi

echo "$SEPARATOR"
echo "Execution completed successfully."
echo "$SEPARATOR"
