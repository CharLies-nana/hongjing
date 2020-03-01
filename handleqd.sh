#!/bin/bash
#test
GetConf()
{
	echo `cat ${2} | grep ${1}= | awk -F= '{print $2}'`
}

ErrorPrint()
{
	echo -e "\033[33;1m参数无效，请使用以下方式调用:\033[0m"
	echo -e "\033[33;1m 平台名 服务器号 [qingdang|stop|start|status]\033[0m"
}

ServerCommand()
{
	module=${1}
	case ${module} in
		status)
            command="sudo ${SERVERPATH}/upload/server_ctrl.sh status_all"
            ssh -i ${SSH_KEY} -l${SSH_USER} -p${REMOTE_SSH_PORT} ${SRV_IP} "${command}"
        ;;
        stop)
            if [[ -f /usr/local/nagios/etc/servers/${PLAT}_s${SN}.cfg ]];then
               echo "关闭监控的报警功能"
               /bin/sed -i "s/notifications_enabled.*/notifications_enabled 0/g"  /usr/local/nagios/etc/servers/${PLAT}_s${SN}.cfg
               /sbin/service nagios reload
            fi         
            command="sudo ${SERVERPATH}/upload/server_ctrl.sh stop_all"
            ssh -i ${SSH_KEY} -l${SSH_USER} -p${REMOTE_SSH_PORT} ${SRV_IP} "${command}"
            
            #comdel="sudo /bin/rm -rf ${SERVERPATH}/runtime/base/out/arena/;sudo /bin/mkdir -p ${SERVERPATH}/runtime/base/out/arena/"
            #ssh -i ${SSH_KEY} -l${SSH_USER} -p${REMOTE_SSH_PORT} ${SRV_IP} "${comdel}"
            
        ;;
        start)
            command="sudo ${SERVERPATH}/upload/server_ctrl.sh start_all"
            ssh -i ${SSH_KEY} -l${SSH_USER} -p${REMOTE_SSH_PORT} ${SRV_IP} "${command}"
                
            if [[ -f /usr/local/nagios/etc/servers/${PLAT}_s${SN}.cfg ]];then
               echo "开启监控的报警功能"
               /bin/sed -i "s/notifications_enabled.*/notifications_enabled 1/g"  /usr/local/nagios/etc/servers/${PLAT}_s${SN}.cfg
               /sbin/service nagios reload
            fi
        ;;
		 bakplatdata)
            command="sudo ${PLATPATH}/plat/crond/backmysql.sh ${module}"
            ssh -i ${SSH_KEY} -l${SSH_USER} -p${REMOTE_SSH_PORT} ${PLAT_IP} "${command}"
        ;;
        bakmanagerdata)
            command="sudo ${PLATPATH}/manager/crond/backmysql.sh ${module}"
            ssh -i ${SSH_KEY} -l${SSH_USER} -p${REMOTE_SSH_PORT} ${MANAGER_IP} "${command}"
        ;;
        bakgamedata|bakgametooldata)
            command="sudo /bin/bash ${SERVERPATH}/crontab/gametool_cron/backmysql.sh ${module}"
            ssh -i ${SSH_KEY} -l${SSH_USER} -p${REMOTE_SSH_PORT} ${SRV_IP} "${command}"
        ;;
        bakgamelogdata)
            command="sudo /usr/local/php/bin/php ${SERVERPATH}/crontab/log_cron/bakgamelogdata.php"
            ssh -i ${SSH_KEY} -l${SSH_USER} -p${REMOTE_SSH_PORT} ${LOG_IP} "${command}"
        ;;
		 clearplatdata)
            echo "开始清理 ${PLAT}_${GAME_CNAME}_plat..."
            /usr/local/php/bin/php ${SUB_SCRIPT_PATH}/db_reinit.php ${PLAT} ${SN} $PLAT_IP "${DB_PORT}" $PLAT_DB_PWD plat ${PLAT_LANG} ${S_OPENDAY}
            /usr/local/php/bin/php ${SUB_SCRIPT_PATH}/clear_memcached.php ${PLAT}
        ;;
        clearmanagerdata)
            echo "开始清理 ${PLAT}_${GAME_CNAME}_manager..."
            /usr/local/php/bin/php ${SUB_SCRIPT_PATH}/db_reinit.php ${PLAT} ${SN} $MANAGER_IP "${DB_PORT}" $MANAGER_DB_PWD manager ${PLAT_LANG} ${S_OPENDAY} 
        ;;
        cleargamedata)
            echo "开始清理 ${PLAT}_${SN}_${GAME_CNAME}_game..."
            /usr/local/php/bin/php ${SUB_SCRIPT_PATH}/db_reinit.php ${PLAT} ${SN} $SRV_IP "${DB_PORT}" $DB_SN game ${PLAT_LANG} ${S_OPENDAY} 
        ;;
        cleargametooldata)
            echo "开始清理 ${PLAT}_${SN}_${GAME_CNAME}_gametool..."
            /usr/local/php/bin/php ${SUB_SCRIPT_PATH}/db_reinit.php ${PLAT} ${SN} $SRV_IP "${DB_PORT}" $DB_SN gametool ${PLAT_LANG} ${S_OPENDAY}  
        ;;
        cleargamelogdata)
            echo "开始清理 ${PLAT}_${SN}_${GAME_CNAME}_gamelog..."
            /usr/local/php/bin/php ${SUB_SCRIPT_PATH}/db_reinit.php ${PLAT} ${SN} $LOG_IP "${LOG_DB_PORT}" $LOG_DB_PWD gamelog ${PLAT_LANG} ${S_OPENDAY} 
        ;;
        rm_gamesrvlog)
            command="sudo /bin/mkdir -p /qingdang_bak${SERVERPATH}/log/; \
            sudo /bin/mkdir -p /qingdang_bak${SERVERPATH}/backup/; \
            sudo /bin/rm -rf /qingdang_bak${SERVERPATH}/log/; \
            sudo /bin/rm -rf /qingdang_bak${SERVERPATH}/backup/; \
            sudo /bin/cp -rf ${SERVERPATH}/log/  /qingdang_bak${SERVERPATH}/; \
            sudo /bin/cp -rf ${SERVERPATH}/backup/  /qingdang_bak${SERVERPATH}/; \
            sudo /bin/rm -rf ${SERVERPATH}/log/; \
            sudo /bin/mkdir -p ${SERVERPATH}/log/server_log; \
            sudo /bin/mkdir -p ${SERVERPATH}/log/gametool_log/pay; \
            sudo /bin/mkdir -p ${SERVERPATH}/log/gametool_log/present; \
            sudo /bin/mkdir -p ${SERVERPATH}/log/gametool_log/script; \
            sudo /bin/chown -R nobody.nobody ${SERVERPATH}/log/gametool_log; \
            sudo /bin/rm -rf ${SERVERPATH}/backup/log_backup/*; \
            sudo /bin/rm -rf ${SERVERPATH}/backup/db_backup/*;"
            ssh -i ${SSH_KEY} -l${SSH_USER} -p${REMOTE_SSH_PORT} ${SRV_IP} "${command}"
        ;;
		*)
			echo "ServerCommand传参错误!"
			exit
		;;
	esac
}


IS_QINGDANG()
{
	#查询该游戏服的状态
	STATUS=`echo "select status from game_server_list where plat_cname='${PLAT}' and server_id=${SN} and game_id=${GAME_ID}" | ${MYSQL} 2> /dev/null | sed -n '2p'`
	#echo "状态是：${STATUS}"
	#是否合服，若无合服值为1
	COUNTS=`echo "select status from game_server_list where plat_cname='${PLAT}' and server_id=${SN} and game_id=${GAME_ID}" | ${MYSQL} 2> /dev/null |grep -v "status" | wc -l`
	#echo "数量的大小是:${COUNTS}"
	#if [[ ${COUNTS} -ne 1 ]];then
	#	echo -e "\033[31;1m${PLAT}_${SN}合过服，不能清档！！\033[0m"
	#	exit
	if [[ ${STATUS} != 40 ]];then
		echo -e "\033[32;1m游戏状态不为初始化状态,开服时间为：${S_OPENDAY}\r\n是否继续清档？(yes/no)\033[0m"
		read answer
		case "${answer}" in 
				yes)
							echo -e "\033[32;1m开始清档\033[0m"
				;;
				no)
							echo -e "\033[31;1m${PLAT}_${SN}退出清档！！！\033[0m"	
							exit
				;;
				*)
							echo "输入错误！(yes/no)"
							exit
				;;
		esac
	fi

}


################
# 开始执行脚本 #
################

cd `dirname $0`
SCRIPT_PATH=`pwd`
CDATE=`date '+%Y-%m-%d_%H-%M-%S'`
PLAT=${1}
SN=${2}
MODULE=${3}
MODULEACT=${4}

SUB_SCRIPT_PATH="${SCRIPT_PATH}/script"
GAME_ID='8'
GAME_CNAME='jddz'
RSYNC_PORT='9789'
DB_PORT='4580'
CNF_DIR="conf"
SRC_PLAT_DIR="../"
PLATPATH="/${GAME_CNAME}/${PLAT}"
SERVERPATH="/${GAME_CNAME}/${PLAT}/${SN}"
test -d log_game_ctrl ||  mkdir -p log_game_ctrl
LOG_DIR='log_game_ctrl'
TMPDIR_MODFILE="tmp_modfile"

# 数据库变量
HOST='583fc8875f75c.sh.cdb.myqcloud.com'
USER='khf_user'
PWD='czS8u9BtZqxwzRhW'
DB_NAME='game_manager'
DB_PORT=5845
MYSQL="mysql -h ${HOST} -u ${USER} -p${PWD}  ${DB_NAME}" 


# ssh变量
SSH_KEY='key/gamepub_rsa'
SSH_USER='gamepub'
SSH_PORT='62920'



if [[ $# != 3 ]];then
	ErrorPrint
	exit
fi



# 更新游戏服和对应的日志服
if [[ $# == 3 && "${PLAT}" != "" && "${SN}" != "" && "${MODULE}" != "" ]];then
	if [[ ! -f ${CNF_DIR}/${PLAT}/${SN}.cnf ]];then
		echo  "${PLAT} 没有 ${SN}.cnf 请检查! "
		exit
	fi
	
	if [[ ! -f ${CNF_DIR}/${PLAT}/manager.cnf ]];then
		echo  "${PLAT} 没有 manager.cnf 请检查! "
		exit
	fi
	

	# 读取配置
	SRV_IP=(`GetConf S_IP ${CNF_DIR}/${PLAT}/${SN}.cnf`)
	DB_SN=(`GetConf S_DB_PWD ${CNF_DIR}/${PLAT}/${SN}.cnf`)
	REMOTE_SSH_PORT=(`GetConf S_SSH_PORT ${CNF_DIR}/${PLAT}/${SN}.cnf`)
	LOG_IP=(`GetConf S_LOGSRV_IP ${CNF_DIR}/${PLAT}/${SN}.cnf`)
	LOG_DB_PWD=(`GetConf S_LOGSRV_DB_PWD ${CNF_DIR}/${PLAT}/${SN}.cnf`)
	LOG_DB_PORT=(`GetConf S_LOGSRV_DB_PORT ${CNF_DIR}/${PLAT}/${SN}.cnf`)
	MANAGER_DB_PWD=(`GetConf M_DB_PWD ${CNF_DIR}/${PLAT}/manager.cnf`)
	MANAGER_IP=(`GetConf M_IP ${CNF_DIR}/${PLAT}/manager.cnf`)
	PLAT_IP=(`GetConf P_IP ${CNF_DIR}/${PLAT}/plat.cnf`)
	PLAT_DB_PWD=(`GetConf P_DB_MYSQL_PW ${CNF_DIR}/${PLAT}/plat.cnf`)
	S_OPENDAY=(`GetConf S_OPENDAY ${CNF_DIR}/${PLAT}/${SN}.cnf`)
	PLAT_LANG=(`GetConf P_LANG ${CNF_DIR}/${PLAT}/plat.cnf`)

	#echo "已经进入清档内部"
	if [ ${MODULE} == 'qingdang' ];then
		#判断是否可以清档
		IS_QINGDANG
		#echo "已经进入清档内部"
		ServerCommand stop | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		ServerCommand bakgamedata | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		ServerCommand bakgametooldata | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		ServerCommand bakgamelogdata | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		ServerCommand bakmanagerdata | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		ServerCommand bakplatdata | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		ServerCommand cleargamedata | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		ServerCommand cleargametooldata | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		ServerCommand cleargamelogdata | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		ServerCommand clearmanagerdata | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		ServerCommand clearplatdata | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		ServerCommand rm_gamesrvlog | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		# 判断数据库是否清理成功
		count_dbinit=`grep "数据库清理成功" ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log | wc -l`
		if [[ ${count_dbinit} != 5 ]];then
			echo  "数据库清理失败，请查看日志：${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log"
		fi
		
	elif [ ${MODULE} == 'stop' ];then
		ServerCommand stop | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		
	elif [ ${MODULE} == 'start' ];then
		ServerCommand start | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		
	elif [ ${MODULE} == 'status' ];then
		ServerCommand status | tee -a ${LOG_DIR}/${PLAT}-${SN}-${MODULE}-${CDATE}.log
		
	else
		ErrorPrint
	fi
fi
