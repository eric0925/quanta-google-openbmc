#!/bin/bash
source $BASE_TOOL_PATH/ssh_utils.sh

# 固定長度的分隔線
LINE_LENGTH=60
SEPARATOR=$(printf '%*s' "$LINE_LENGTH" '' | tr ' ' '=')

usage() {
    cat << EOF
Usage: ${0##*/}

Interactive script to configure ASD JTAG for HPM0 or HPM1 on a selected BMC.

Steps:
  1. Update machine list from server.
  2. Select a machine from the displayed list by Machine ID.
  3. Select HPM 0 or 1.

Options:
  -h, --help    Show this help message

Note:
  一次 asd 只能執行一次，不能同時對兩個 CPU 做測試。
  本腳本會在啟動前自動結束已存在的 asd 程序。
EOF
}

# 處理 help 選項（唯一保留的命令列參數）
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# 互動式：更新機器清單並選擇機器
update_machine_list
if [ $? -ne 0 ]; then
    exit 1
fi

select_machine_from_conf
if [ $? -ne 0 ]; then
    exit 1
fi

# 互動式：選擇 HPM
read -p "Select HPM to connect (0 or 1): " hpm
if [ "$hpm" != "0" ] && [ "$hpm" != "1" ]; then
    echo "Error: HPM must be 0 or 1." >&2
    exit 1
fi

echo "$SEPARATOR"
echo "Starting remote execution on root@$bmc_ip..."
echo "Selected CPU: HPM$hpm"
echo "$SEPARATOR"

case "$hpm" in
    0)
        REMOTE_COMMANDS=$(cat << 'EOF'
echo "Stopping nftables..."
systemctl stop nftables.service

echo "Stopping any existing asd process..."
pidof asd > /dev/null && kill -9 $(pidof asd)

echo "Setting HPM0 JTAG GPIOs..."
gpioset -m exit $(gpiofind "JTAG_MUX_SEL_DEBUG_R_N")=0
gpioset -m exit $(gpiofind "JTAG_MUX_SEL_HPM_R_N")=0
gpioset -m exit $(gpiofind "JTAG_SCM_MUX_OE_HPM0")=0
gpioset -m exit $(gpiofind "JTAG_SCM_MUX_SEL_HPM0")=1

echo "Launching ASD daemon to HPM0..."
/usr/bin/asd -u --xdp-ignore --cpu-index 0
EOF
)
        ;;
    1)
        REMOTE_COMMANDS=$(cat << 'EOF'
echo "Stopping nftables..."
systemctl stop nftables.service

echo "Stopping any existing asd process..."
pidof asd > /dev/null && kill -9 $(pidof asd)

echo "Setting HPM1 JTAG GPIOs..."
gpioset -m exit $(gpiofind "JTAG_MUX_SEL_DEBUG_R_N")=0
gpioset -m exit $(gpiofind "JTAG_MUX_SEL_HPM_R_N")=1
gpioset -m exit $(gpiofind "JTAG_SCM_MUX_OE_HPM1")=0
gpioset -m exit $(gpiofind "JTAG_SCM_MUX_SEL_HPM1")=1

echo "Launching ASD daemon to HPM1..."
/usr/bin/asd -u --xdp-ignore --cpu-index 1
EOF
)
        ;;
esac

PASS="0penBmc"
# 透過 sshpass 遠端執行
# 加上 -o ConnectTimeout 避免遠端掛掉時腳本卡死
echo "executing: sshpass -p \"$PASS\" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@\"$bmc_ip\" \"$REMOTE_COMMANDS\""
sshpass -p "$PASS" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$bmc_ip" "$REMOTE_COMMANDS"

if [ $? -ne 0 ]; then
    echo "$SEPARATOR"
    echo "Error: Failed to connect or execute commands on $bmc_ip"
    exit 1
fi

echo "$SEPARATOR"
echo "Execution completed successfully."
echo "$SEPARATOR"
