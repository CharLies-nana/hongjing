#!/bin/bash
#function:
#		1.在任务计划中设置17点30分进行检查第二日开服域名是否解析成功
#		2.使用dig命令判断域名是否解析
#		3.判定时间是距离当前时间17点30分的12个小时和70个小时之类游戏服的开服时间


GetConf()
{
	echo `cat ${2} | grep ${1}= | awk -F= '{print $2}'`
}

ErrorPrint()
{
	echo "参数无效，请使用以下方式调用:"
	echo "	$0 [center|trad]"
	exit
}

digChk()
{
		dchkgame=`dig $S_CHK_DOMAIN +short`
		#echo "域名是${dchkgame}"
		if [[ -z $dchkgame ]];then
			local ret=1
		else
			local ret=0
		fi
		echo $ret
}
sendWarn()
{
	result=$(digChk)
	if [[ $result == 0 ]]; then
		echo "OK,There is no problem!"
	else
		#echo -e "\033[32m域名解析问题,请查看!  \033[0"
		/usr/bin/printf "%b" " ${S_CHK_DOMAIN} dnsport problem! Please check!" | /usr/local/bin/sendEmail -f zhanxiansh@163.com -t $contactMail -s smtp.163.com -u "** dnsport problem! **" -xu zhanxiansh@163.com -xp zhanxian988 -l /var/log/sendEmail.log
fi
}

domainChk()
{
		case ${CENTER_PLAT} in 
			'center')
				        CENTER_NUMS=${#CENTER[@]}
					for (( i=0;i<${CENTER_NUMS};i++ ))
					do
						plat=${CENTER[i]}
						P_DB_PWD=(`GetConf P_DB_MYSQL_PW ${CNF_DIR}/${plat}/plat.cnf`)
						P_IP=(`GetConf P_IP ${CNF_DIR}/${plat}/plat.cnf`)
						S_CHK_DOMAIN=`echo "select server_url from server where open_time between ${MIN_CHK_TIME} and ${MAX_CHK_TIME};" | mysql -h${P_IP} -uroot -p${P_DB_PWD} ${plat}_${GAME_NAME}_plat | sed -n '2p'`
						if [[ -n ${S_CHK_DOMAIN} ]];then
							sendWarn
						fi
					done
			;;
			'trad')
					TRAD_NUMS=${#TRAD[@]}
					for (( i=0;i<${TRAD_NUMS};i++ )) 
					do
						plat=${TRAD[i]}
						P_DB_PWD=(`GetConf P_DB_MYSQL_PW ${CNF_DIR}/${plat}/plat.cnf`)
						P_IP=(`GetConf P_IP ${CNF_DIR}/${plat}/plat.cnf`)
						S_CHK_DOMAIN=`echo "select server_url from server where open_time between ${MIN_CHK_TIME} and ${MAX_CHK_TIME};" | mysql -h${P_IP} -uroot -p${P_DB_PWD} ${plat}_${GAME_NAME}_plat | sed -n '2p'`
						if [[ -e ${S_CHK_DOMAIN} ]];then
							sendWarn
						fi
					done
			;;
			*)
					ErrorPrint	
			;;
		esac
}

cd `dirname $0`
SCRIPT_PATH=`pwd`
CENTER_PLAT=${1}
GAME_NAME='jddz'
#定义中央服对应的正式服
CENTER=(yyb uc txzf paojiao kuafu)
TRAD=(hwmix hwkuafu)
#检查开服时间的最大时间和最小时间
NOW_TIME=`date +%s`
MIN_CHK_TIME=`echo ${NOW_TIME} + 43200 |bc`
MAX_CHK_TIME=`echo ${NOW_TIME} + 252000 |bc`
#MAX_CHK_TIME=`echo ${NOW_TIME} + 104800 |bc`

#定义报警配置
CNF_DIR="conf"
contactMail="18320031549@139.com"


#开始检查
if [[ $# != 1 ]] ; then
	ErrorPrint
fi

domainChk ${CENTER_PLAT}
