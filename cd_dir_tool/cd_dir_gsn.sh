#!/bin/bash
#usage: gsndir
#usage: gsndir 5
#Author KevinCC Chen
export openbmc_home='/home/ericlee/repo_GSN/openbmc'

# 定義一個普通的陣列來存儲目錄
#choicesDir=(
#    "device/renesas/kernel"
#    "device/renesas/kingfisher"
#)
source ~/repo_GSN/dir_choiseDir.sh

echo -e "\033[37;44mOpenbmc_home: $openbmc_home\033[0m"

para=$1

if [[ $para != "" ]]; then
    if [[ $para -le ${#choicesDir[@]} ]]; then
        if [ $para == "0" ]; then
            cd  "$openbmc_home"
            echo "切換到目標目錄: $openbmc_home"
        else    
            target_dir="${choicesDir[$((para-1))]}"
            echo "切換到目標目錄: $target_dir"
            cd "$openbmc_home" && cd "$target_dir" || { echo "無法切換到目標目錄: $target_dir"; popd; exit 1; }
        fi
    else
        echo "無效的選擇，請選擇有效的選項。"
    fi
else
    # Display menu options in order
    echo "請選擇一個選項："
    echo "0. ${openbmc_home}"
    for i in "${!choicesDir[@]}"; do
        echo "$((i+1)). ${choicesDir[$i]}"
    done
    echo

    # Read user input
    read -p "請輸入您的選擇 (0/1/2/3/...): " choice
    echo

    # Validate user input and change to the corresponding directory
    if [[ "$choice" == "0" ]]; then
        echo "切換到 OpenBMC Home: $openbmc_home"
        cd "$openbmc_home" || exit 1
    elif [[ $choice -ge 1 && $choice -le ${#choicesDir[@]} ]]; then
        target_dir="${choicesDir[$((choice-1))]}"
        echo "切換到目標目錄: $target_dir"
        cd "$openbmc_home" && cd "$target_dir" || { echo "無法切換到目標目錄: $target_dir"; popd; exit 1; }
    else
        echo "無效的選擇，請選擇有效的選項。"
    fi
fi
