#!/bin/bash
source /home/ericlee/quanta_openbmc_toolbox/ssh_utils.sh

# 固定長度的分隔線
LINE_LENGTH=60
SEPARATOR=$(printf '%*s' "$LINE_LENGTH" '' | tr ' ' '=')

usage() {
    cat << EOF
Usage: ${0##*/} ip=<BMC_IP> hpm=<0|1>

Connect to the specified BMC and configure ASD JTAG for HPM0 or HPM1.

Arguments:
  ip=<BMC_IP>   Target BMC IP address
  hpm=0         Select HPM0
  hpm=1         Select HPM1

Options:
  -h, --help    Show this help message

Note:
  一次 asd 只能執行一次，不能同時對兩個 CPU 做測試。
  本腳本會在啟動前自動結束已存在的 asd 程序。
EOF
}

bmc_ip=""
hpm=""

for arg in "$@"; do
    case "$arg" in
        ip=*)
            bmc_ip="${arg#ip=}"
            ;;
        hpm=*)
            hpm="${arg#hpm=}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument: $arg" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [ -z "$bmc_ip" ]; then
    echo "Error: ip=<BMC_IP> is required." >&2
    usage >&2
    exit 1
fi

if [ "$hpm" != "0" ] && [ "$hpm" != "1" ]; then
    echo "Error: hpm must be 0 or 1." >&2
    usage >&2
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
