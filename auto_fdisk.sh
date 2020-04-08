#!/bin/bash
#Author:hjh
#Date:2014-12-10
#Function:auto partition and format disk


#定义分区格式化挂载函数
CheckDisk()
{
 #DEVICE=$(fdisk -l | grep "\<GB\>" | awk -F":" '{print $1}' | awk '{print $2}')
 DEVICE=$1
 [[ $(echo ${DEVICE} | wc -l) -ne 1 ]] && { echo "More than one disk , check please !" ; exit 0 ;}
 
 if df -h | grep "${DEVICE}" > /dev/null 2>&1 
 then
  echo -e "\033[40;32mThe ${DEVICE} disk is mounted.\033[40;37m" 
  exit 0
 else
  echo "You have a free disk,Now will fdisk it and mount it."
  sleep 5
 fi


#Create partition
 fdisk ${DEVICE} << EOF
n
p
1

+32G
t
82
n
p
2


w
EOF

sleep 5
partprobe ${DEVICE} && echo "partition success!"

#Format partition
 mkswap ${DEVICE}1
 swapon ${DEVICE}1
 mkfs.ext4 ${DEVICE}2
 mkdir -p /jddz
 mount ${DEVICE}2 /jddz
 echo "${DEVICE}1            swap            swap      defaults  0  0" >> /etc/fstab
 echo "${DEVICE}2            /jddz      ext4      defaults  0  0" >> /etc/fstab
 
 echo -e "\033[40;32mMemory Information:\033[40;37m"
 free -m
 echo -e "\033[40;32mDisk Mounted Information:\033[40;37m"
 df -h
 echo -e "\033[40;32m/ect/fstab Information:\033[40;37m"
 cat /etc/fstab
}


################################
#脚本执行入口
################################

ARG1=$1

if [[ $# -eq 1 ]]
then
  CheckDisk ${ARG1}
else
  echo -e "\033[40;32m正确格式：./`basename $0` /dev/xxxx\033[40;37m"
fi
