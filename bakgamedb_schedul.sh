#!/bin/bash
## -------------------------------------------------
## @本地备份game和gametool数据库
## -------------------------------------------------

exe_command()
{
    echo "${plat_sn}" > tmpdirgame/tmp_${plat_sn}
    plat=`awk -F- '{print $1}' tmpdirgame/tmp_${plat_sn}`
    sn=`awk  -F- '{print $2}' tmpdirgame/tmp_${plat_sn}`
    sh /${game_cname}/${plat}/${sn}/crontab/gametool_cron/backmysql.sh bakgamedata
    sh /${game_cname}/${plat}/${sn}/crontab/gametool_cron/backmysql.sh bakgametooldata
}


cd `dirname $0`
start_exe=`date +"%s"`
# 游戏别名
game_cname='jddz'

/usr/local/php/bin/php get_list.php
rm -rf tmpdirgame
mkdir -p tmpdirgame



TMPFILE=$$.fifo
mkfifo $TMPFILE
exec 50<>$TMPFILE
rm -f $TMPFILE
PARALLEL=10


for ((i=0;i<${PARALLEL};i++))
do
        echo
done >&50 


for plat_sn in `cat  plat_sn.txt`
do 
        read <&50
        (   
                exe_command
                echo >&50
        )& 
done

 
wait
exec 50>&-

end_exe=`date +"%s"`
minute=$(( (${end_exe} - ${start_exe})/60 ))
second=$(( (${end_exe} - ${start_exe})%60 ))
echo "执行时间:${minute}分${second}秒"
