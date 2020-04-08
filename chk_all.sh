#!/bin/bash
#function：
#	1.检查所有平台备份情况
	

#错误显示
print_error(){
    echo -e "\033[33;1m检查所有平台备份：\033[0m"
    echo -e "\033[33;1m         $0 CENTER chkbak all\033[0m"
    exit 0
}

#开始脚本
cd `dirname $0`
CENTER_NAME=$1
#获取服务器列表
/usr/bin/php get_plat.php
if [[ $# != 3 ]];then
    print_error
    exit
fi
#CENTER_PLATS=(uc yyb paojiao sqzf 921yyb 921mix smzf 921apple smzf wamzf lwzf 921pgzf2 ywzf 49you 921myapp wmizf)
TRAD_PLATS=(hwmix)
echo -e "\033[33;1m检查当天数据库备份规则：\r\n         [09:00-12:00]:备份1次则成功\r\n         [14:00-18:00]:备份2次则成功\r\n         [20:00-24:00]:备份3次则成功\033[0m"
case ${CENTER_NAME} in
    center)
	    #number=${#CENTER_PLATS[@]}
		
	    #for ((i=0;i<${number};i++))
             for plat in `cat dlplat.txt | grep -v hwmix | grep -v hwjc`	     
	    do
			    #plat=${CENTER_PLATS[$i]}
			    /bin/bash /jddz/center/maintain/chkinfo/chk_info.sh ${plat} chkbak all >> tmp_chk.txt
			done
		;;
	trad)
	    number=${#TRAD_PLATS[@]}
		
	    for ((i=0;i<=${number};i++))
		    do
			    plat=${TRAD_PLATS[$i]}
			    /bin/bash /jddz/trad/maintain/chkinfo/chk_info.sh ${plat} chkbak all
			done
		;;
	*)
	    print_error
	;;
esac

cat tmp_chk.txt | egrep '远程备份失败|无效' && rm -f tmp_chk.txt
