#!/bin/bash
source $BASE_TOOL_PATH/ssh_utils.sh
#-----------------------------------------------------------------------------------------
#變數設定
#-----------------------------------------------------------------------------------------
PASS="0penBmc"
LINE_LENGTH=60
SEPARATOR=$(printf '%*s' "$LINE_LENGTH" '' | tr ' ' '=')
IMAGE_BMC_PATH="/home/ericlee/repo_GSN/build-gsn/tmp/deploy/images/gsn/image-bmc"
REMOTE_DIR="/run/initramfs/"
#-----------------------------------------------------------------------------------------
if [ ! -f "$IMAGE_BMC_PATH" ]; then
    echo "Error: image-bmc path $IMAGE_BMC_PATH does not exist!"
    exit 1
fi
cd "$LOCAL_PATH" || exit 1

select_machine_from_conf

# 測試連線並建立遠端目錄

SCP_CMD="sshpass -p $PASS scp -o ConnectTimeout=3 -o StrictHostKeyChecking=no $IMAGE_BMC_PATH root@${bmc_ip}:${REMOTE_DIR}"
echo "Executing: $SCP_CMD"
$SCP_CMD


if [ $? -ne 0 ]; then
    echo "Error: SSH connection timed out or failed to execute command on $bmc_ip"
    exit 1
fi

echo "BMC image transferred successfully."

LS_CMD="sshpass -p $PASS ssh root@$bmc_ip ls -alh $REMOTE_DIR"
echo "Executing: $LS_CMD"
$LS_CMD

echo "press [Enter] to AC the target"
read -p ""

AC_cmd="rm -r /run/initramfs/rw/cow/* && /usr/bin/tray_powercycle.sh"
echo $AC_cmd
sshpass -p $PASS ssh root@$bmc_ip $AC_cmd  #"rm -r /run/initramfs/rw/cow/* && /usr/bin/tray_powercycle.sh"

