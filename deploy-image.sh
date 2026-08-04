#!/bin/bash
source /home/ericlee/quanta_openbmc_toolbox/ssh_utils.sh
#-----------------------------------------------------------------------------------------
#變數設定
#-----------------------------------------------------------------------------------------
LOCAL_PATH="$BASE_TOOL_PATH/bios_image"  # 改為讓使用者選擇當前目錄下的 BIOS 檔案
PASS="0penBmc"
LINE_LENGTH=60
SEPARATOR=$(printf '%*s' "$LINE_LENGTH" '' | tr ' ' '=')
IMAGE_BMC_PATH=
#-----------------------------------------------------------------------------------------
if [ ! -d "$LOCAL_PATH" ]; then
    echo "Error: Local path $LOCAL_PATH does not exist!"
    exit 1
fi
cd "$LOCAL_PATH" || exit 1

select_machine_from_conf

sshpass -p "$PASS" scp  -o ConnectTimeout=3 -o StrictHostKeyChecking=no root@"$bmc_ip" "mkdir -p /mnt/luks-mmcblk0_fs/bios"

if [ $? -ne 0 ]; then
    echo "Error: SSH connection timed out or failed to execute command on $bmc_ip"
    exit 1
fi

REMOTE_DIR="/mnt/luks-mmcblk0_fs/bios"

echo "--- [Local MD5 Check] ---"
md5sum "${BIOS_FILE}"
echo "-------------------------"

REMOTE_DEST_0="root@${bmc_ip}:${REMOTE_DIR}/image-bios-0"
REMOTE_DEST_1="root@${bmc_ip}:${REMOTE_DIR}/image-bios-1"

echo "Executing: sshpass -p \"$PASS\" scp \"${BIOS_FILE}\" \"${REMOTE_DEST_0}\""
sshpass -p "$PASS" scp "${BIOS_FILE}" "${REMOTE_DEST_0}"

echo "Executing: sshpass -p \"$PASS\" scp \"${BIOS_FILE}\" \"${REMOTE_DEST_1}\""
sshpass -p "$PASS" scp "${BIOS_FILE}" "${REMOTE_DEST_1}"


echo "--- [Remote MD5 Check] ---"
echo "image-bios-0 MD5:"
sshpass -p "$PASS" ssh "root@${bmc_ip}" "md5sum ${REMOTE_DIR}/image-bios-0"

echo "image-bios-1 MD5:"
sshpass -p "$PASS" ssh "root@${bmc_ip}" "md5sum ${REMOTE_DIR}/image-bios-1"
echo "--------------------------"


echo "press [Enter] to AC the target"
read -p ""
echo "commit the sync_bios_dram_to_emmc temporarily"
sshpass -p "$PASS" ssh root@$bmc_ip "sed -i 's/^\([[:space:]]*\)sync_bios_dram_to_emmc/\1# sync_bios_dram_to_emmc/'  /usr/bin/tray_powercycle.sh"

AC_cmd="rm -r /run/initramfs/rw/cow/* && /usr/bin/tray_powercycle.sh"
echo $AC_cmd
sshpass -p "$PASS" ssh root@$bmc_ip $AC_cmd

