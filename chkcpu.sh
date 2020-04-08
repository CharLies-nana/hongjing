#!/bin/bash
#判断参数合法性
if [[ $# != 1 ]];then
	echo "正确操作：$0 中央服"
	exit

fi
CENTER=$1
PLATS="center trad"
isdo=0

for plat in ${PLATS}
do
	if [[ ${plat} == ${CENTER} ]];then
		isdo=1
		break
	fi
	
done

if [[ ${isdo} == 0 ]];then
	echo "正确操作：$0 中央服"
	exit
fi


num=$(ps -ef | grep 'chkcpu.sh' | grep -v grep | wc -l)
#echo ${num}
((num=$num-1))
echo ${num}
if [[ ${num} -gt 1 ]];then
	echo -e "已经有进程在运行\r\n正在退出..."
	exit

fi
#创建存放检查cpu的目录
[ -d /yunwei/chkcpu ] || mdkir -p /yunwei/chkcpu

 exe_file="/jddz/${CENTER}/maintain/chkinfo/chkcpu.py"
 /usr/bin/python  ${exe_file} ${CENTER}
