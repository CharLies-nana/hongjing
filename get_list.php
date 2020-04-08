<?php

// 定义变量
$host = '583fc8875f75c.sh.cdb.myqcloud.com:5845';
$user = 'php_user';
$pwd = 'ZNMvFr5ebACxHRUX';
$db_name = 'game_manager';
$game_id = '8';
$game_status = '40';
$game_status_1 = '70';
$inputfile = 'plat_sn.txt';
$inputlogfile = 'plat_sn_log.txt';

$con = mysql_connect($host,$user,$pwd,$db_name);
if (!$con)
{
        die('Could not connect: ' . mysql_error());
}

$db_selected = mysql_select_db($db_name, $con);
if (!$db_selected)
{
        die ("Can\'t use $db_name : " . mysql_error());
}


//获取本机ip
//$strshell = "/sbin/ifconfig  | grep 'inet addr:' | grep 'Bcast:' | head -1 | awk  '{print $2}' | awk -F: '{print $2}'";
$strshell = "curl http://getlocalip.jddz.ffcai.com/get_localip.php 2>&1";
exec($strshell,$out);
$local_ip = end($out);

//获取未下架的服信息，并写入到plat_sn.txt
$strsql="SELECT `id`  FROM  `physical_server_list`  WHERE `game_id` = \"{$game_id}\" and `server_ip` = \"{$local_ip}\" ";
$query = mysql_query($strsql,$con);
$id_arr = ""; 
while ($row = mysql_fetch_array($query))
{   
        $id_arr[] = $row['id'];
}

$plat_sn_arr = "";

if(!empty($id_arr) && is_array($id_arr))
{
    foreach ($id_arr as $id)
    {   
            $strsql="SELECT `g`.`plat_cname`,`g`.`server_id`  FROM `game_server_list` as `g` inner join `physical_server_list` as `p`  WHERE `g`.`game_id` = \"{$game_id}\" and `p`.`game_id` = \"{$game_id}\" and `g`.`physical_server_id` = `p`.`id` and `g`.`status` >= \"{$game_status}\" and `g`.`status` < \"{$game_status_1}\" and `g`.`physical_server_id` = \"{$id}\" ";
            $query = mysql_query($strsql,$con);
            while ($row = mysql_fetch_row($query))
            {   
                    $plat_sn_arr[] = $row;
            }
    }
}
$strcmd = "rm -f {$inputfile}";
exec($strcmd);

if(!empty($plat_sn_arr) && is_array($plat_sn_arr))
{
    foreach ($plat_sn_arr as $plat_sn)
    {
           file_put_contents("$inputfile","$plat_sn[0]-$plat_sn[1]\n",FILE_APPEND);
    }
}
//获取未下架的服信息，并写入到plat_sn_log.txt
$strsql="SELECT `id`  FROM  `db_server_list`  WHERE `game_id` = \"{$game_id}\" and `server_ip` = \"{$local_ip}\" ";
$query = mysql_query($strsql,$con);
$id_log_arr = ""; 
while ($row = mysql_fetch_array($query))
{   
        $id_log_arr[] = $row['id'];
}

$plat_sn_log_arr = ""; 

if(!empty($id_log_arr) && is_array($id_log_arr))
{
    foreach ($id_log_arr as $id)
    {   
            $strsql="SELECT `g`.`plat_cname`,`g`.`server_id`  FROM `game_server_list` as `g` inner join `db_server_list` as `p`  WHERE `g`.`game_id` = \"{$game_id}\" and `p`.`game_id` = \"{$game_id}\" and `g`.`db_server_id` = `p`.`id` and `g`.`status` >= \"{$game_status}\" and `g`.`status` < \"{$game_status_1}\" and `g`.`db_server_id` = \"{$id}\" ";
            $query = mysql_query($strsql,$con);
            while ($row = mysql_fetch_row($query))
            {   
                    $plat_sn_log_arr[] = $row;
            }   
    }
}

$strcmd = "rm -f {$inputlogfile}";
exec($strcmd);

if(!empty($plat_sn_log_arr) && is_array($plat_sn_log_arr))
{
    foreach ($plat_sn_log_arr as $plat_sn)
    {
           file_put_contents("$inputlogfile","$plat_sn[0]-$plat_sn[1]\n",FILE_APPEND);
    }
}
mysql_close($con);

?>
