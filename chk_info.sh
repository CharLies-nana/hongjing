#!/bin/bash
#Author:zzm
#Date:2015-09-30
#function：
#	1.检查远程备份：显示前一天远程备份少于3，则显示备份错误
#	2.查看平台所在机器内存（涵盖开服个数和游戏服号信息）以及磁盘信息报告

#错误显示
error_print(){
echo -e "\033[33;1m检查硬件：\033[0m"
echo -e "\033[33;1m         $0 平台名 [disk|memory]\033[0m"
echo -e "\033[33;1m检查备份：\033[0m"
echo -e "\033[33;1m         $0 平台名 chkbak [game|gametool|manager|plat|all]\033[0m"
exit 0
}

#求出前日12点时间段和18点时间段CPU的消耗平均值和最小值
average_p(){
	src_path='/yunwei/chkcpu'
	rm -f tmp.txt
	ip=$1
	sums=0
	for i in `cat ${src_path}/${ip}_${lastday}_CPU.txt`;
	do 
		sums=`echo "$sums+$i" | bc`
		#aver=`echo $sums/36 | bc`
		echo $i >> tmp.txt
		
	done
    numbers=`awk '{print NF}' ${src_path}/${ip}_${lastday}_CPU.txt`
	aver=`echo "$sums/$numbers" |bc`

	mix=`sort tmp.txt | sed -n '1p'`
	cpu_num=`cat ${PWD}/memory.txt | grep ${ip}_ | awk -F\: "{print $2}"`
	echo -e "CPU剩余平均值：${aver}\r\nCPU剩余最小值：${mix}\r\n${cpu_num}"
	rm -f tmp.txt


}


#查看物理机器的具体cpu信息
chk_cpu(){

	
	while true
	do
		echo "请输入查看ip或者q退出"
		read  answer
		case ${answer} in 
			q)
				#rm -f iplist.txt
				echo "退出脚本"
				exit
			;;
			*)
				average_p ${answer}
		esac
	done

}

#获得平台下的所开服的物理机器的内存相关值
chkmem() {
    M_IP=$1
    #获得IP开服个数
    kftotal=`cat dlplat_sn_ip.txt | grep ${M_IP} | wc -l`
    #IP下服号
    fnum=`cat dlplat_sn_ip.txt | grep ${M_IP} | awk -F- '{print $2}' | sort -nu`
    #远程获取机器物理内存
    CPU_NUM=`${SSH} ${M_IP} "cat /proc/cpuinfo | grep processor | wc -l"`
    ${SSH} ${M_IP} "/usr/bin/free -m" > ${M_IP}_tmpmem.txt
    echo -e "\033[41;33;1m ${M_IP} \033[0m ==>\n开服个数：${kftotal}\n分别是：" >> memory.txt
    echo $fnum | while read line;do echo $line >> memory.txt;done
    echo "${M_IP}_CPU_NUM: ${CPU_NUM}核" >> memory.txt
    echo "内存=>" >> memory.txt
    cat ${M_IP}_tmpmem.txt >> memory.txt
	
	
    /bin/rm -f ${M_IP}_tmpmem.txt
        

}

is_kaifu(){
	M_IP=$1
	#平台所在的ip
	plat_ip=` cat dlplat_sn_ip.txt | grep '\-1\-' |  awk -F- '{print $3}'`
	#echo "平台所在的ip${plat_ip}"
	#上一个游戏服的ip
	#last_sn_ip=`sort -t- -k 2 dlplat_sn_ip.txt | tail -1 | awk -F- '{print $3}'`
	last_two_ip=`sort -t- -k2 dlplat_sn_ip.txt | tail -2 | awk -F- '{print $2}'`
	cmp1=`echo ${last_two_ip} | awk '{print $2}'`
	cmp2=`echo ${last_two_ip} | awk '{print $1}'`
	if [[ ${cmp1} -lt ${cmp2} ]];then
		last_sn_ip=`sort -t- -k2 dlplat_sn_ip.txt | grep "\-\${cmp2}\-" | awk -F- '{print $3}'`
	else
		last_sn_ip=`sort -t- -k2 dlplat_sn_ip.txt | grep "\-\${cmp1}\-" | awk -F- '{print $3}'`
	fi
	#最后五个服所占比例
	last_five_ip_num=`sort -t- -k 2 dlplat_sn_ip.txt | tail -5 | awk -F- '{print $3}' | grep ${M_IP} | wc -l `
	#获得IP开服个数
    	kftotal=`cat dlplat_sn_ip.txt | grep ${M_IP} | wc -l`
	#总共内存
	mem_total=`${SSH} ${M_IP} "/usr/bin/free -m | sed  -n 2p " | awk '{print $2}'`
	#剩余物理内存
	mem_free=`${SSH} ${M_IP} "/usr/bin/free -m | sed  -n 2p " | awk '{print $4}'`
	#剩余缓存
	mem_free_cache=`${SSH} ${M_IP} "/usr/bin/free -m | sed  -n 3p " | awk '{print $4}'`
	#剩余缓存所占百分比
	free_cache_percent=`echo "sclae=3;(${mem_free_cache}*100/${mem_total})" | bc `

	if [[ ${mem_free} -gt 2000 && ${free_cache_percent} -gt 55 && ${M_IP} != ${plat_ip} && ${M_IP} != ${last_sn_ip} && ${last_five_ip_num} -le 2 ]];then
		echo -e "\e[1;31m一方式=>${M_IP}\e[0m"
	fi
	if [[ ${mem_free} -gt 2500 && ${free_cache_percent} -gt 80 ]];then
		echo -e "\e[1;31m二方式=>${M_IP}\e[0m"
	fi
	rm -f iplist.txt
	

	

}

#获得平台下所在物理机的磁盘使用情况
chkdisk(){
	DISK_IP=$1
	${SSH} ${DISK_IP} "df -hl" >${DISK_IP}_tmpdisk.txt
	#${SCP} ${KEY_USER}@$i:${GAMEPUB_PATH}/${TARGET_IP}_tmpdisk.txt ${PWD} > /dev/null
	#根目录磁盘剩余大小
	GENG_SIZE=`grep '/$' ${DISK_IP}_tmpdisk.txt | awk '{print $5}' | awk -F% '{print $1}'`
	#主磁盘剩余大小
	MAINTAIN_SIZE=`grep "${GNAME_CNAME}" ${DISK_IP}_tmpdisk.txt | awk '{print $5}' | awk -F% '{print $1}'`
	if [[ ${GENG_SIZE} -gt 80 || ${MAINTAIN_SIZE} -gt 80 ]];then
		echo -e "\e[1;31m ${DISK_IP}磁盘不足，磁盘存储情况如下：\e[0m"
		echo ""
		${SSH} ${DISK_IP} "df -hl"
	fi
	echo -e "\033[41;33;1m ${DISK_IP} \033[0m ==>\n硬盘信息显示：" >>disk.txt
	cat ${DISK_IP}_tmpdisk.txt >>disk.txt
	rm -f ${DISK_IP}_tmpdisk.txt
}
#执行远程备份检查
do_chk_remtebak(){
	TYPE=$1
	
	case ${TYPE} in 
		game|gametool)
			for snum in `cat dlplat_sn_ip.txt | awk -F- '{print $2}'`
			do
				NOW_HOUR=`date +%H`
				BAKCOUNTS=`ls -l ${BAK_SRC_PATH}/${PLAT_NAME}/${snum}/ 2> /dev/null | grep "_${TYPE}_" | grep "${TODAY}" | wc -l`
				NEED_BAK=`echo ${NOW_HOUR} / 7|bc`
				if [[ ${BAKCOUNTS} -lt ${NEED_BAK} ]];then
					OPEN_TIME=`cat ${MAINTAIN_PATH}/conf/${PLAT_NAME}/${snum}.cnf | grep S_OPENDAY_TIMESTAMP | awk -F= '{print $2}'`
					NOW_TIME=`date +%s`
					DISTANCE_TIME=`echo ${NOW_TIME} - ${OPEN_TIME}|bc`
					if [[ ${DISTANCE_TIME} -gt 86400 ]];then
						echo -e "\033[31;1m${PLAT_NAME}_${snum}_${TYPE}远程备份失败，请检查！\033[0m" | tee -a chkbak/${TYPE}_chk.txt
						#报警设置
						# if [[ ${NOW_HOUR} == 12 || ${NOW_HOUR} == 17 || ${NOW_HOUR} == 21 ]];then
						# /usr/bin/printf "%b" "bak ${PLAT_NAME}_${snum}_${TYPE} problem! " | /usr/local/bin/sendEmail -f ${MONITOR_SEND_MAIL} -t ${MONITOR_RECEIVE_MAI} -s smtp.163.com -u "**bak problem! **" -xu ${MONITOR_USER} -xp ${MONITOR_PWD} -l /var/log/sendEmail.log
						# fi
					fi
				fi
			done
		;;
		manager|plat)
			NOW_HOUR=`date +%H`
			BAKCOUNTS=`ls -l ${BAK_SRC_PATH}/${PLAT_NAME}/${TYPE}/ | grep "_${TYPE}_" | grep "${TODAY}" | wc -l`
			NEED_BAK=`echo ${NOW_HOUR} / 7|bc`
			if [[ ${BAKCOUNTS} -lt ${NEED_BAK} ]];then
				echo -e "\033[31;1m${PLAT_NAME}_${TYPE}远程备份失败，请检查！\033[0m" | tee -a chkbak/${TYPE}_chk.txt
				#报警设置
				# if [[ ${NOW_HOUR} == 12 || ${NOW_HOUR} == 16 || ${NOW_HOUR} == 21 ]];then
					# /usr/bin/printf "%b" "bak ${PLAT_NAME}_${TYPE} problem! " | /usr/local/bin/sendEmail -f ${MONITOR_SEND_MAIL} -t ${MONITOR_RECEIVE_MAI} -s smtp.163.com -u "**bak problem! **" -xu ${MONITOR_USER} -xp ${MONITOR_PWD} -l /var/log/sendEmail.log
				# fi
			fi
		;;
	esac
}
#检查远程备份
chk_remtebak(){
	MODE=$1
	#LASTDAY=`date -d"1 day ago" +%Y-%m-%d`
	
	test -d chkbak || mkdir -p chkbak 
	rm -f chkbak/*.txt
	echo -e "\033[33;1m检查当天数据库备份规则：\r\n  	[09:00-12:00]:备份1次则成功\r\n  	[14:00-18:00]:备份2次则成功\r\n  	[20:00-24:00]:备份3次则成功\033[0m"
	case ${MODE} in
		game|gametool)
			
				do_chk_remtebak ${MODE} 
	
		;;
		manager)
	
				do_chk_remtebak ${MODE}
		;;
		plat)
				
				do_chk_remtebak ${MODE}
		;;
		all)
				do_chk_remtebak plat | tee -a chkbak/${MODE}_chk.txt
				do_chk_remtebak manager | tee -a chkbak/${MODE}_chk.txt
				do_chk_remtebak game | tee -a chkbak/${MODE}_chk.txt
				do_chk_remtebak gametool | tee -a chkbak/${MODE}_chk.txt
		;;
		*)
				error_print
		;;
	esac
			

}



##########开始执行脚本########
PLAT_NAME=$1
flag=0
#路径变量
PWD=`dirname $0`
cd ${PWD}
MAINTAIN_PATH=`dirname ${PWD}`
GNAME_CNAME='jddz'
#KEY变量
KEY_USER='gamepub'
KEY='../key/gamepub_rsa'
#SSH变量
SSH_PORT=62920
SSH="ssh -i ${KEY} -l${KEY_USER} -p${SSH_PORT}"
SCP="scp -i ${KEY} -P${SSH_PORT}"
# 报警设置
MONITOR_SEND_MAIL='shgame_kaifu@163.com'
MONITOR_RECEIVE_MAI='18320031549@139.com'
MONITOR_USER='shgame_kaifu'
MONITOR_PWD='sdzkaifu'
#中央服对应正式服平台
CENTER=(uc yyb txzf paojiao sqzf 921yyb 921mix smzf 921apple smzf wamzf lwzf 921pgzf2 ywzf 49you 921myapp 921wmi qtldzf)
TRAD=(hwmix hwkuafu)

#判断参数正确性
if [[ $# -lt 2 ]];then
	 error_print
else
	ALLOW_PLAT=(uc yyb txzf paojiao sqzf 921yyb 921mix smzf 921apple smzf wamzf lwzf 921pgzf2 ywzf 49you 921myapp hwmix hwkuafu 921wmi qtldzf shenhe hwjc yyzf)
	A_NUM=${#ALLOW_PLAT[@]}
	for ((i=0;i<=${A_NUM};i++))
	do
		if [[ ${ALLOW_PLAT[$i]} == ${PLAT_NAME} ]];then
			flag=1
			break
	        fi
	done
fi
#判断平台合法性
if [[ $flag == 0 ]];then
	echo -e "\e[1;31m该平台${PLAT_NAME}无效 \e[0m"
	exit 1
fi
TODAY=`date +%Y%m%d`
#判断数据远程备份路径
if [[ `df -hl | grep -c "/${GNAME_CNAME}"` -eq 1 ]];then
	BAK_SRC_PATH="/${GNAME_CNAME}/yunwei/bakgamedb_remote/data"
else
	BAK_SRC_PATH="/yunwei/bakgamedb_remote/data"
fi
# if [[ ${PLAT_NAME} == 'gt' || ${PLAT_NAME} == 'efun' ]];then
	
	# BAK_SRC_PATH="/${GNAME_CNAME}/remote_bakdb/data"
# fi





#读出该平台开服的机器
/usr/bin/php get_gxlist.php ${PLAT_NAME} 
rm -f iplist.txt
/bin/cat dlplat_sn_ip.txt | awk -F- '{print $3}' | sort -u > iplist.txt


if [[ $# == 2 && $2 != 'chkbak' ]];then
   MODULE=$2
#多进程处理
   # TMPFILE=$$.fifo
   # mkfifo ${TMPFILE}
   # exec 8<>${TMPFILE}
   # rm -f ${TMPFILE}
   # PROCESS=10
   # for ((i=0;i<=${PROCESS};i++))
   # do
	# echo 
   # done >&8
   
   # lastday=`date -d "1 day ago" +"%Y-%m-%d"`
   case ${MODULE} in
		disk)
			rm -f disk.txt
			echo -e "\e[1;31m ${PLAT_NAME}: \e[0m" > disk.txt
			if [[ -e iplist.txt ]];then
				for d_ip in `cat iplist.txt`
				do
					# read <&8
					# (
						# chkdisk ${d_ip}
						# echo >&8
					# )&
					chkdisk ${d_ip}
				done
			else
				echo "没有生成iplist.txt文件！！"
				exit 1
			fi
		;;
		memory)
			ips=`awk -F- '{print $3}' dlplat_sn_ip.txt | sort -u `
			echo $ips | while read line;do echo $line >> tmp_numfu.txt;done
			echo -e "\033[33;1m${PLAT_NAME}平台的开服物理机器:"
			cat tmp_numfu.txt && rm -f tmp_numfu.txt
			rm -f memory.txt
			echo -e "\e[1;31m ${PLAT_NAME}：\e[0m" > memory.txt
			echo -e "\e[1;31m开新服机器推荐方法：\r\n	  【方式一：内存Mem > 2G,剩余buffers/cache > 55%,非plat及非上个游戏服所在机器】 \n	  【方式二: 内存Mem > 2.5G,剩余buffers/cache > 80】 \e[0m"
			for m_ip in `cat iplist.txt`
			do
			# read <&8
				# (	
					# chkmem ${m_ip}
					# echo >&8
				# )&
				chkmem ${m_ip}
				is_kaifu ${m_ip}
			done
			chk_cpu
		;;
		*)
			error_print
		;;
  	
   esac
   echo -e "\e[1;31m 检查完毕，请查看${MODULE}.txt \e[0m"
   wait
   exec 8>&-
elif [[ $# == 3 && $2 == 'chkbak' && $3 != '' ]];then 
  CHK_TYPE=$3
  chk_remtebak ${CHK_TYPE}
  test -f chkbak/${CHK_TYPE}_chk.txt && chk_fail_num=`cat ${PWD}/chkbak/${CHK_TYPE}_chk.txt | grep '备份失败' | wc -l`
  if [[ ${chk_fail_num} -ge 1 ]];then
	  echo -e "\e[1;31m ${PLAT_NAME}备份出错，请查看${PWD}/chkbak/${CHK_TYPE}_chk.txt \e[0m"
  else
	  echo -e "\e[1;31m ${PLAT_NAME}全平台备份成功！\e[0m"
  fi
else
  error_print
fi
rm -f iplist.txt
