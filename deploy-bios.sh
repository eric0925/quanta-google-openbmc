#!/bin/bash
source /home/ericlee/quanta_openbmc_toolbox/ssh_utils.sh
#-----------------------------------------------------------------------------------------
#變數設定
#-----------------------------------------------------------------------------------------
LOCAL_PATH="$BASE_TOOL_PATH/bios_image"  # 改為讓使用者選擇當前目錄下的 BIOS 檔案
PASS="0penBmc"
LINE_LENGTH=60
SEPARATOR=$(printf '%*s' "$LINE_LENGTH" '' | tr ' ' '=')
#-----------------------------------------------------------------------------------------
if [ ! -d "$LOCAL_PATH" ]; then
    echo "Error: Local path $LOCAL_PATH does not exist!"
    exit 1
fi
cd "$LOCAL_PATH" || exit 1

echo "$SEPARATOR"
echo "AVAILABLE BIOS FILES"
echo "$SEPARATOR"

# 搜尋當前目錄下的 .bios 與 .bin 檔案並存入陣列
# 使用 shopt 確保找不到檔案時不會噴原生萬用字元
shopt -s nullglob
FILES=( *.bios *.bin )
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
    echo "No .bios or .bin files found in $LOCAL_PATH!"
    exit 1
fi

COLUMNS=1
select FILE_CHOICE in "${FILES[@]}"; do
    if [ -n "$FILE_CHOICE" ]; then
        BIOS_FILE="$FILE_CHOICE"
        echo "You selected: $BIOS_FILE"
        break
    else
        echo "Invalid choice, please try again."
    fi
done
# 選擇完後可以把 COLUMNS 復原（或是放著不管它，因為腳本快結束了）  <--- 看不太懂
unset COLUMNS

select_machine_from_conf

# 測試連線並建立遠端目錄
sshpass -p "$PASS" ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no root@"$bmc_ip" "mkdir -p /mnt/luks-mmcblk0_fs/bios"

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

echo "Executing: sshpass -p 0penBmc scp \"${BIOS_FILE}\" \"${REMOTE_DEST_0}\""
sshpass -p "$PASS" scp "${BIOS_FILE}" "${REMOTE_DEST_0}"

echo "Executing: sshpass -p 0penBmc scp \"${BIOS_FILE}\" \"${REMOTE_DEST_1}\""
sshpass -p "$PASS" scp "${BIOS_FILE}" "${REMOTE_DEST_1}"


echo "--- [Remote MD5 Check] ---"
echo "image-bios-0 MD5:"
sshpass -p "$PASS" ssh "root@${bmc_ip}" "md5sum ${REMOTE_DIR}/image-bios-0"

echo "image-bios-1 MD5:"
sshpass -p "$PASS" ssh "root@${bmc_ip}" "md5sum ${REMOTE_DIR}/image-bios-1"
echo "--------------------------"


echo "press [Enter] to AC the target"
read -p ""

sshpass -p 0penBmc ssh root@$bmc_ip "/usr/bin/tray_powercycle.sh"
