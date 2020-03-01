#!/bin/bash
#2015/5/11 
#根据冒险岛的install_sys安装脚本修改
#修改内容主要包括：
#mysql-5.6.15   ===> mysql-5.5.30
#otp_src_R15B02 ===> otp_src_R16B03-1
#nginx-1.4.4
#新增安装软件包：Berkeley DB、memcacheq
#mysql保持原来剑道的配置，只改变路径

########## 增加用户和key ##########
Add_Users()
{
    cd ${SCRIPT_DIR}
    /bin/cp -f /etc/sudoers /etc/sudoers.bak.${CDATE}
    chmod 777 /etc/sudoers
    # 修改文件
    sed -i 's/^Defaults    requiretty/#Defaults    requiretty/g'  /etc/sudoers
    #sed -i 's/^# %wheel ALL=(ALL)   ALL/%wheel  ALL=(ALL)   ALL/g'  /etc/sudoers
    #grep "%wheel\sALL=(ALL)\sALL" /etc/sudoers  || echo "%wheel  ALL=(ALL)   ALL" >> /etc/sudoers 
    echo "%wheel  ALL=(ALL)   ALL" >> /etc/sudoers 

    grep "gamepub ALL=(ALL) NOPASSWD: ALL" /etc/sudoers || echo "gamepub ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    grep "nagios ALL=(ALL) NOPASSWD: ALL" /etc/sudoers || echo "nagios ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers 
    chmod 440 /etc/sudoers

    for user_name in `ls ${KEY_DIR}`
    do
        if [[ "${user_name}" == "passwd.TXT" ]];then
            continue
        fi
        /usr/sbin/useradd -g wheel ${user_name} 2>/dev/null     
        echo ` cat ${KEY_DIR}/passwd.TXT | grep "${user_name}=" | awk -F= '{print $2}' ` | passwd --stdin ${user_name}
        /usr/sbin/pwconv
        /bin/mkdir -p /home/${user_name}/.ssh/ 2>/dev/null
        /bin/cp -f ${KEY_DIR}/${user_name}/authorized_keys /home/${user_name}/.ssh/
        chown -R ${user_name}.wheel /home/${user_name}/.ssh/
        chmod 600 /home/${user_name}/.ssh/authorized_keys
        chmod 700 /home/${user_name}/.ssh/
    done
    cd ${SCRIPT_DIR}
}

########## 配置SSH ##########
Config_SSH()
{
    cd ${SCRIPT_DIR}
    /bin/cp -f /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.${CDATE}
    sed -i 's/#Port.*/Port 62920/g' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config
    sed -i 's/#LoginGraceTime.*/LoginGraceTime 10m/g' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config
    sed -i 's/GSSAPIAuthentication.*/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
    sed -i 's/#UseDNS.*/UseDNS no/g' /etc/ssh/sshd_config
    sed -i 's/#MaxStartups.*/MaxStartups 1000/g' /etc/ssh/sshd_config

    /bin/cp -f /etc/ssh/ssh_config /etc/ssh/ssh_config.bak.${CDATE}
    grep "StrictHostKeyChecking no" /etc/ssh/ssh_config || echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config

    chmod 600 /etc/ssh/sshd_config  
    /sbin/service sshd restart
    cd ${SCRIPT_DIR}    
}

########## 配置rsync ##########
Config_Rsync()
{
    sed -i "s/^rsync.*//g" /etc/services
    echo "rsync           9789/tcp                         # rsync"  >> /etc/services
    echo "rsync           9789/udp                         # rsync"  >> /etc/services
    /bin/cp -vf ${SCRIPT_DIR}/${FILE_DIR}/xinetd.conf   /etc/xinetd.conf
    /bin/cp -vf ${SCRIPT_DIR}/${FILE_DIR}/rsync   /etc/xinetd.d/rsync
    /sbin/service xinetd restart

    /bin/cp -rvf ${SCRIPT_DIR}/${FILE_DIR}/rsyncd.conf /etc/
    /bin/cp -rvf ${SCRIPT_DIR}/${FILE_DIR}/rsyncd.password /etc/
    /bin/cp -rvf ${SCRIPT_DIR}/${FILE_DIR}/rsyncd.password_client /etc/ 
    chmod 644 /etc/rsyncd.conf
    chmod 600 /etc/rsyncd.password
    chmod 600 /etc/rsyncd.password_client

    if [[ "`grep "\[yunwei\]" /etc/rsyncd.conf`" == "" ]];then
        echo "" >> /etc/rsyncd.conf
        echo "[yunwei]" >> /etc/rsyncd.conf
        echo "comment = 'welcome to service'" >> /etc/rsyncd.conf
        echo "path = /yunwei" >> /etc/rsyncd.conf
        echo "#ignore errors" >> /etc/rsyncd.conf
        echo "read only = no" >> /etc/rsyncd.conf
        echo "write only = no" >> /etc/rsyncd.conf 
        echo "list = no" >> /etc/rsyncd.conf 
        echo "#transfer logging = yes" >> /etc/rsyncd.conf
        echo "#log format = \"%o %h [%a] %m (%u) %f %l\"" >> /etc/rsyncd.conf
        echo "#hosts allow = 192.168.2.142/255.255.255.0" >> /etc/rsyncd.conf
        echo "auth users = root" >> /etc/rsyncd.conf 
        echo "secrets file = /etc/rsyncd.password" >> /etc/rsyncd.conf
        echo "uid = root" >> /etc/rsyncd.conf 
        echo "gid = root" >> /etc/rsyncd.conf
    fi
    /sbin/service xinetd restart
}

########## 配置iptable ##########
Conf_Iptable()
{
# 开启iptable
cat > /etc/sysconfig/iptables << "EOF"
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# 允许loopback!(不然会导致DNS无法正常关闭等问题)
-A INPUT -i lo -j ACCEPT
# 如果是发出的回应包,则ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
# 允许ping
-A INPUT -p icmp -m icmp -j ACCEPT
# http
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
# https
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
# mysql
-A INPUT -p tcp -m tcp --dport 4580 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 5888:5900 -j ACCEPT
# ssh
-A INPUT -p tcp -m tcp --dport 62920 -j ACCEPT
# rsync
-A INPUT -p tcp -m tcp --dport 9789 -j ACCEPT 
# zabbix
-A INPUT -p tcp -m tcp --dport 5778 -j ACCEPT
# nagios
-A INPUT -p tcp -m tcp --dport 5666 -j ACCEPT
# cacti
-A INPUT -p udp -m udp --dport 161 -j ACCEPT
-A INPUT -p udp -m udp --dport 199 -j ACCEPT
# memcache端口
-A INPUT -p tcp -m tcp --dport 9900:10000 -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
COMMIT
EOF

    # 重启防火墙
    service iptables restart
    service iptables save
    service iptables restart
    /sbin/chkconfig iptables on
}

########## 安装系统所需包和工具，优化系统 ##########
Install_Package_Optimize()
{
    cd ${SCRIPT_DIR}    

	#通过判断某一个软件是否安装来判断是否执行过yum安装脚本,
	rpm -qa | grep freetype-devel
    [[ "$?"  != 0 ]] && { echo "yum 安装软件失败，请单独执行yum.sh" ; exit 1 ; }
	#存在问题或不存在的软件包：epel-release.noarch beecrypt-devel gcc44* gcc-g77 librrd* remi-release.noarch


    /usr/bin/scp -r /usr/lib64/libldap* /usr/lib/
    cp  -frp /usr/lib64/libjpeg.* /usr/lib/
    cp -frp /usr/lib64/libpng* /usr/lib/

    # 重启一些系统服务
    /sbin/chkconfig rsync on
    /sbin/chkconfig xinetd on   ; /sbin/service xinetd restart
    /sbin/chkconfig crond on    ; /sbin/service crond restart
    /sbin/chkconfig sendmail on ; /sbin/service sendmail restart

    # 关闭某些系统服务  
    SERVICES="abrt-ccpp abrt-oops abrtd acpid atd auditd cpuspeed cups ip6tables kdump netconsole portreserve postfix psacct quota_nld rdisc restorecond saslauthd smartd snmpd iptables"
    for service in $SERVICES
    do
        /sbin/chkconfig $service off
        /sbin/service $service stop
    done

    # 关闭selinux
    sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux
    sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    /usr/sbin/setenforce 0

    # 配置snmp
    /bin/mv -f /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.bak.${CDATE}
    /bin/cp -f ${FILE_DIR}/snmpd.conf /etc/snmp/
    sed -i   "s#OPTIONS\=\"\-Lsd \-p \/var\/run\/snmptrapd.pid\"#\#OPTIONS\=\"\-Lsd \-p \/var\/run\/snmptrapd.pid\"#g"  /etc/init.d/snmptrapd
    /sbin/service snmpd restart
    /sbin/chkconfig snmpd on

    cd ${PACKAGE_DIR}

    # 安装pv
    rpm -Uvh pv-1.3.1-1.el5.rf.x86_64.rpm

    # 安装vnstat，监控流量
    tar -zxf vnstat-1.11.tar.gz
    cd vnstat-1.11/
    make ${JOBS} && make install
    cd .. && rm -rf vnstat-1.11

    # 监控流量工具
    tar -zxvf iftop-0.17.tar.gz
    cd iftop-0.17
    ./configure
    make ${JOBS} && make install
    cd .. && rm -rf iftop-0.17

    # 安装nali  mtr的ip显示地区
    tar -zxf nali-0.2.tar.gz
    cd nali-0.2
    ./configure
    make ${JOBS} && make install
    cd .. && rm -rf nali-0.2
    /bin/cp -vf ${SCRIPT_DIR}/${FILE_DIR}/QQWry.Dat  /usr/local/share/QQWry.Dat

    # 设置时区
    rm -f /etc/localtime
    /bin/cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    /usr/sbin/ntpdate time.windows.com
    grep "UTC=false" /etc/sysconfig/clock || echo "UTC=false" >> /etc/sysconfig/clock
    grep "ARC=false" /etc/sysconfig/clock || echo "ARC=false" >> /etc/sysconfig/clock

    # 定时同步时间
    grep "ntpdate time.nist.gov" /var/spool/cron/root || echo "17 4 * * * /usr/sbin/ntpdate time.nist.gov && /sbin/hwclock --systohc" >> /var/spool/cron/root

    # 添加dns
    grep "nameserver 8.8.8.8" /etc/resolv.conf || echo "nameserver 8.8.8.8" >> /etc/resolv.conf

    # 设置history命令
    grep "HISTFILESIZE=2000" /etc/bashrc || echo "HISTFILESIZE=2000" >> /etc/bashrc
    grep "HISTSIZE=2000" /etc/bashrc || echo "HISTSIZE=2000" >> /etc/bashrc
    grep "export HISTTIMEFORMAT" /etc/bashrc || echo "export HISTTIMEFORMAT=\"%F %T \"" >> /etc/bashrc

    # 设置语言  
    grep "export LANG=en_US.UTF-8" /root/.bashrc || echo "export LANG=en_US.UTF-8" >> /root/.bashrc
	grep 'LANG="en_US.UTF-8"' /etc/sysconfig/i18n || { sed -i "/LANG=.*/d" /etc/sysconfig/i18n ; echo 'LANG="en_US.UTF-8"' >> /etc/sysconfig/i18n ; }
	grep 'SYSFONT="latarcyrheb-sun16"' /etc/sysconfig/i18n || { sed -i "/SYSFONT=.*/d" /etc/sysconfig/i18n ; echo 'SYSFONT="latarcyrheb-sun16"' >> /etc/sysconfig/i18n ; }

    # 增大系统打开文件数限制
    grep "* soft nofile 65535" /etc/security/limits.conf || echo '* soft nofile 65535' >> /etc/security/limits.conf
    grep "* hard nofile 65535" /etc/security/limits.conf || echo '* hard nofile 65535' >> /etc/security/limits.conf

    # 增大系统打开进程数限制
    sed -i '/1024/d' /etc/security/limits.d/90-nproc.conf
    grep "* soft nproc 65535" /etc/security/limits.d/90-nproc.conf || echo "* soft nproc 65535" >> /etc/security/limits.d/90-nproc.conf
    grep "* hard nproc 65535" /etc/security/limits.d/90-nproc.conf || echo "* hard nproc 65535" >> /etc/security/limits.d/90-nproc.conf

    # ssh登录后需要显示的信息
    grep "df -lh" /root/.bash_profile || echo "df -lh" >> /root/.bash_profile

    # vim编辑器显示行数
    grep "set nu" /etc/vimrc || echo "set nu" >> /etc/vimrc

    # 添加开机启动项
    grep "/usr/sbin/setenforce 0" /etc/rc.d/rc.local || echo "/usr/sbin/setenforce 0" >> /etc/rc.d/rc.local
    grep "ulimit -SHn 65535" /etc/rc.d/rc.local || echo "ulimit -SHn 65535" >> /etc/rc.d/rc.local
    grep "/sbin/sysctl -p" /etc/rc.d/rc.local || echo "/sbin/sysctl -p" >> /etc/rc.d/rc.local
    grep "/root/memcached_start" /etc/rc.d/rc.local || echo "/root/memcached_start" >> /etc/rc.d/rc.local
    grep "/root/nrpe_start" /etc/rc.d/rc.local || echo "/root/nrpe_start" >> /etc/rc.d/rc.local

    # 优化内核参数
    /sbin/modprobe nf_conntrack
    /sbin/modprobe ip_conntrack
    echo "" >> /etc/sysctl.conf
    grep "net.ipv4.tcp_syncookies = 1" /etc/sysctl.conf || echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf
    grep "net.ipv4.tcp_max_syn_backlog = 10000" /etc/sysctl.conf || echo "net.ipv4.tcp_max_syn_backlog = 10000" >> /etc/sysctl.conf
    grep "net.ipv4.tcp_synack_retries = 3" /etc/sysctl.conf || echo "net.ipv4.tcp_synack_retries = 3" >> /etc/sysctl.conf
    grep "net.ipv4.tcp_syn_retries = 3" /etc/sysctl.conf || echo "net.ipv4.tcp_syn_retries = 3" >> /etc/sysctl.conf
    grep "net.nf_conntrack_max = 655360" /etc/sysctl.conf || echo "net.nf_conntrack_max = 655360" >> /etc/sysctl.conf
    grep "net.netfilter.nf_conntrack_max = 655360" /etc/sysctl.conf || echo "net.netfilter.nf_conntrack_max = 655360" >> /etc/sysctl.conf
    grep "net.netfilter.nf_conntrack_tcp_timeout_established = 1200" /etc/sysctl.conf || echo "net.netfilter.nf_conntrack_tcp_timeout_established = 1200" >> /etc/sysctl.conf
    grep "net.ipv4.ip_local_port_range = 35000 65000" /etc/sysctl.conf || echo "net.ipv4.ip_local_port_range = 35000 65000" >> /etc/sysctl.conf
    grep "net.core.netdev_max_backlog = 262144" /etc/sysctl.conf || echo "net.core.netdev_max_backlog = 262144" >> /etc/sysctl.conf
    grep "net.core.somaxconn = 262144" /etc/sysctl.conf || echo "net.core.somaxconn = 262144" >> /etc/sysctl.conf
    grep "net.ipv4.tcp_tw_reuse = 1" /etc/sysctl.conf || echo "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.conf
    grep "kernel.sem = 250 64000 32 256" /etc/sysctl.conf || echo "kernel.sem = 250 64000 32 256" >> /etc/sysctl.conf
    grep "vm.swappiness = 10" /etc/sysctl.conf || echo "vm.swappiness = 10" >> /etc/sysctl.conf
	grep "kernel.shmmax = 68719476736" /etc/sysctl.conf || { sed -i "/kernel.shmmax =.*/d" /etc/sysctl.conf ; echo "kernel.shmmax = 68719476736" >> /etc/sysctl.conf ; }
	grep "kernel.shmall = 4294967296" /etc/sysctl.conf || { sed -i "/kernel.shmall =.*/d" /etc/sysctl.conf ; echo "kernel.shmall = 4294967296" >> /etc/sysctl.conf ; }
    /sbin/sysctl -p

    cd ${SCRIPT_DIR}
}


########## 安装mysql+php+nginx ##########
Install_NMP()
{
    cd ${SCRIPT_DIR}
    cd ${PACKAGE_DIR}

    # 安装jpegsrc.v6b
    tar -zxf jpegsrc.v6b.tar.gz
    cd  jpeg-6b/
    CFLAGS="-O3 -fPIC" ./configure
    make install-lib
    cd ../ && rm -rf jpeg-6b

    # 安装libpng
    tar zxf libpng-1.6.7.tar.gz
    cd libpng-1.6.7
    ./configure
    make ${JOBS} && make install
    cd ../ && rm -rf libpng-1.6.7

    # 安装gd
    tar -zxf gd-2.0.35.tar.gz
    cd gd-2.0.35
    ./configure --prefix=/usr/local/gd2 --mandir=/usr/share/man
    make clean
    make ${JOBS} && make install
    cd ../ && rm -rf gd-2.0.35

    # 安装 libmcrypt
    tar zxf libmcrypt-2.5.8.tar.gz
    cd libmcrypt-2.5.8/
    ./configure
    make ${JOBS} && make install
    ldconfig
    cd libltdl/
    ./configure --enable-ltdl-install
    make ${JOBS} && make install
    cd ../../  && /bin/rm -rf libmcrypt-2.5.8/

    # 安装 mhash
    tar zxf mhash-0.9.9.tar.gz
    cd mhash-0.9.9/
    ./configure
    make ${JOBS} && make install
    cd ../ && /bin/rm -rf mhash-0.9.9/

    # 安装libunwind
    tar -zxf libunwind-1.1.tar.gz
    cd libunwind-1.1/
    CFLAGS=-fPIC ./configure
    make clean
    make CFLAGS=-fPIC ${JOBS} 
    make CFLAGS=-fPIC install
    cd ../ && /bin/rm -rf libunwind-1.1

    # 安装google-perftools
    tar zxf google-perftools-1.7.tar.gz
    cd google-perftools-1.7
    CHOST="x86_64-pc-linux-gnu"
    CFLAGS="-mtune=native -march=native -O2 -pipe" 
    CXXFLAGS="-mtune=native -march=native -O2 -pipe"
    ./configure
    make clean
    make ${JOBS} && make install
    echo "/usr/local/lib" > /etc/ld.so.conf.d/usr_local_lib.conf
    /sbin/ldconfig
    cd ../ && rm -rf google-perftools-1.7

    # 安装libiconv
    tar zxf libiconv-1.14.tar.gz
    cd libiconv-1.14/
    ./configure --prefix=/usr/local
    make ${JOBS} && make install
    cd ../ && /bin/rm -rf libiconv-1.14/

    # 安装libevent
    tar zxf libevent-2.0.21-stable.tar.gz
    cd libevent-2.0.21-stable/
    CHOST="x86_64-pc-linux-gnu"
    CFLAGS="-mtune=native -march=native -O2 -pipe" 
    CXXFLAGS="-mtune=native -march=native -O2 -pipe"
    ./configure
    make ${JOBS} && make install
    echo '/usr/local/lib/' > /etc/ld.so.conf.d/libevent.conf
    ldconfig
    cd ../ && rm -rf libevent-2.0.21-stable/

    ################ 安装MySQL ##########################
    # 安装mysql
    useradd -M -s /sbin/nologin mysql 
    mkdir -p /data/mysql
    mkdir -p /data/mysql/binlog/
    mkdir -p /data/mysql/relaylog/
    chown -R mysql:mysql /data/mysql/
    
    tar zxf mysql-5.5.30.tar.gz
    cd mysql-5.5.30/
    CHOST="x86_64-pc-linux-gnu"
    CFLAGS="-mtune=native -march=native -O2 -pipe" 
    CXXFLAGS="-mtune=native -march=native -O2 -pipe" 
    /usr/bin/cmake . -DCMAKE_INSTALL_PREFIX=/usr/local/mysql/ \
    -DSYSCONFDIR=/etc \
    -DMYSQL_DATADIR=/data/mysql \
    -DMYSQL_TCP_PORT=4580 \
    -DMYSQL_UNIX_ADDR=/data/mysql/mysql.sock \
    -DMYSQL_USER=mysql \
    -DDEFAULT_CHARSET=utf8 \
    -DDEFAULT_COLLATION=utf8_general_ci \
    -DEXTRA_CHARSETS=all \
    -DWITH_SSL=system \
    -DWITH_EMBEDDED_SERVER=1 \
    -DENABLED_LOCAL_INFILE=1 \
    -DWITH_PARTITION_STORAGE_ENGINE=1 \
    -DWITH_INNOBASE_STORAGE_ENGINE=1 \
    -DWITH_MYISAM_STORAGE_ENGINE=1 \
    -DWITH_MYISAMMRG_STORAGE_ENGINE=1 \
    -DENABLE_DTRACE=OFF 

    make ${JOBS} 
    make install

    /usr/local/mysql/scripts/mysql_install_db --user=mysql --basedir=/usr/local/mysql/ --datadir=/data/mysql/ --defaults-file=/etc/my.cnf

    sed -i 's@# executing mysqld_safe@#executing mysqld_safe\nexport LD_PRELOAD=/usr/local/lib/libtcmalloc.so\n@' /usr/local/mysql/bin/mysqld_safe  
    cp -f /usr/local/mysql/support-files/mysql.server  /etc/init.d/mysqld
    /bin/mv -f /etc/my.cnf /etc/my.cnf.bak.${CDATE}
    /bin/cp -vf ${SCRIPT_DIR}/${FILE_DIR}/my.cnf /etc/
    /sbin/service mysqld restart
    /sbin/chkconfig mysqld on
    ln -s /usr/local/mysql/bin/mysql /usr/bin
    ln -fs /usr/local/mysql/bin/mysqldump /usr/bin
    ln -s /usr/local/mysql/lib/libmysqlclient.so.18 /usr/lib64/libmysqlclient.so.18
    ln -s /usr/local/mysql/bin/mysql /usr/local/bin/mysql
    ln -s /usr/local/mysql/bin/mysqlimport /usr/local/bin/mysqlimport
    ln -s /usr/local/mysql/bin/mysqldump /usr/local/bin/mysqldump
    ln -s /usr/local/mysql/bin/mysql_config  /usr/local/bin/mysql_config
    ln -s /usr/local/mysql/include/* /usr/local/include/

    cd ../  && rm -rf  mysql-5.5.30/
   ################ 结束安装MySQL ######################

#   ################ 安装apache ##########################
#   yum -y install httpd.x86_64 httpd-devel.x86_64
#   service httpd stop
#   配置php时加上这个：--with-apxs2=/usr/sbin/apxs \

#   配置完php后：
#   在/etc/httpd/conf/httpd.conf
#   将 DirectoryIndex index.html index.html.var 替换为 DirectoryIndex index.php index.html index.html.var
#   在 AddType text/html .shtml 和 AddOutputFilter INCLUDES .shtml之间添加以下4行
#   AddType application/x-httpd-php .php
#   AddType application/x-httpd-php-source .phps
#   AddType text/html .shtml
#   AddOutputFilter INCLUDES .shtml

#   重启httpd
#   ################ 结束安装apache ######################

    # 安装PHP5.4.23
    tar -jxf php-5.4.23.tar.bz2
    cd php-5.4.23/
    CHOST="x86_64-pc-linux-gnu" 
    CFLAGS="-mtune=native -march=native -O2 -pipe" 
    CXXFLAGS="-mtune=native -march=native -O2 -pipe"
    ./configure --prefix=/usr/local/php \
    --with-config-file-path=/etc \
    --with-mysql=/usr/local/mysql \
    --with-mysqli=/usr/local/mysql/bin/mysql_config \
    --with-iconv-dir=/usr/local \
    --with-freetype-dir \
    --with-jpeg-dir \
    --with-png-dir \
    --with-zlib \
    --with-libxml-dir=/usr \
    --enable-xml \
    --disable-rpath \
    --enable-discard-path \
    --enable-safe-mode \
    --enable-bcmath \
    --enable-shmop \
    --enable-sysvsem \
    --enable-inline-optimization \
    --with-curl= \
    --with-curlwrappers \
    --enable-mbregex  \
    --with-gettext \
    --enable-force-cgi-redirect \
    --enable-mbstring \
    --with-mcrypt \
    --with-gd \
    --enable-gd-native-ttf \
    --with-openssl \
    --with-mhash \
    --enable-fpm \
    --enable-pcntl \
    --enable-sockets \
    --with-ldap \
    --with-ldap-sasl \
    --with-xmlrpc \
    --enable-zip \
    --enable-soap \
    --with-pdo-mysql=/usr/local/mysql

    make ZEND_EXTRA_LIBS='-liconv' ${JOBS} 
    make install
    cd ../ && rm -rf php-5.4.23/
    mv /etc/php.ini /etc/php.ini.bak.${CDATE}
    /bin/cp -rvf ${SCRIPT_DIR}/${FILE_DIR}/php.ini /etc/

    mv /usr/local/php/etc/php-fpm.conf /usr/local/php/etc/php-fpm.conf.bak.${CDATE}
    /bin/cp -rvf ${SCRIPT_DIR}/${FILE_DIR}/php-fpm.conf  /usr/local/php/etc/php-fpm.conf
    /bin/cp -rvf ${SCRIPT_DIR}/${FILE_DIR}/php-fpm /etc/init.d/
    chmod 755 /etc/init.d/php-fpm
    /sbin/chkconfig --add php-fpm
    /sbin/chkconfig php-fpm on

    mv -f /usr/bin/php /usr/bin/php_old
    ln -s /usr/local/php/bin/php /usr/bin/php

    # 安装 PDO_MYSQL
    tar zxf PDO_MYSQL-1.0.2.tgz
    cd PDO_MYSQL-1.0.2/
    /usr/local/php/bin/phpize
    ./configure --with-php-config=/usr/local/php/bin/php-config --with-pdo-mysql=/usr/local/mysql
    make ${JOBS} && make install
    cd ../ && rm -rf PDO_MYSQL-1.0.2/

    # 安装 php 插件 eaccelerator
    tar zxf eaccelerator-eaccelerator-42067ac.tar.gz
    cd eaccelerator-eaccelerator-42067ac/
    /usr/local/php/bin/phpize
    CHOST="x86_64-pc-linux-gnu"
    CFLAGS="-mtune=native -march=native -O2 -pipe" 
    CXXFLAGS="-mtune=native -march=native -O2 -pipe"
    ./configure --enable-eaccelerator \
    --with-php-config=/usr/local/php/bin/php-config \
    --with-eaccelerator-shared-memory \
    --with-eaccelerator-sessions \
    --without-eaccelerator-encoder
    make clean
    make ${JOBS} && make install
    cd .. && rm -rf eaccelerator-eaccelerator-42067ac/

    test -d /dev/shm/eaccelerator/ || mkdir -p /dev/shm/eaccelerator/
    chown -R nobody:nobody /dev/shm/eaccelerator/
    chmod -R 777 /dev/shm/eaccelerator/

    sed -i '/.*dev\/shm\/eaccelerator.*/d' /etc/rc.d/rc.local
    echo '' >> /etc/rc.d/rc.local
    echo 'mkdir -p /dev/shm/eaccelerator/' >> /etc/rc.d/rc.local
    echo 'chown -R nobody:nobody /dev/shm/eaccelerator/' >> /etc/rc.d/rc.local
    echo 'chmod -R 777 /dev/shm/eaccelerator/' >> /etc/rc.d/rc.local
    echo '' >> /etc/rc.d/rc.local

    # 安装xdebug
    tar xzf xdebug-2.2.3.tgz
    cd xdebug-2.2.3/
    /usr/local/php/bin/phpize
    CHOST="x86_64-pc-linux-gnu"
    CFLAGS="-mtune=native -march=native -O2 -pipe" 
    CXXFLAGS="-mtune=native -march=native -O2 -pipe"
    ./configure --enable-xdebug --with-php-config=/usr/local/php/bin/php-config
    make ${JOBS} && make install
    mkdir -p /var/xdebug
    chmod -R 777 /var/xdebug
    cd ../ && rm -rf xdebug-2.2.3

    # 安装amfext扩展,提高flex与PHP数据交互的速度
    tar zxf amfext-php-5.4.x.tgz
    cd amfext-php-5.4.x/
    /usr/local/php/bin/phpize
    ./configure --with-php-config=/usr/local/php/bin/php-config
    make ${JOBS} && make install
    cd ../ && rm -rf amfext-php-5.4.x/

    ##### 安装nginx
    # 安装Nginx所需的pcre库
    tar jxf pcre-8.34.tar.bz2
    cd pcre-8.34/
    CHOST="x86_64-pc-linux-gnu"
    CFLAGS="-mtune=native -march=native -O2 -pipe" 
    CXXFLAGS="-mtune=native -march=native -O2 -pipe"
    ./configure
    make ${JOBS} && make install
    cd ../ && rm -rf pcre-8.34/

    # 安装nginx
    mkdir -p /var/www/html
    chown -R nobody.nobody /var/www/html/   
    tar zxf nginx-1.4.4.tar.gz
    cd nginx-1.4.4/
    mkdir -p /usr/local/nginx
    # 在编译时，Nginx默认以debug模式进行，此模式下会插入很多跟踪和ASSERT之类的信息
    # 将CFLAGS="$CFLAGS -g"修改为CFLAGS="$CFLAGS"或者直接删除这一行
    sed -i 's#CFLAGS="$CFLAGS -g"#CFLAGS="$CFLAGS "#' auto/cc/gcc
    make clean
    CHOST="x86_64-pc-linux-gnu"
    CFLAGS="-mtune=native -march=native -O2 -pipe" 
    CXXFLAGS="-mtune=native -march=native -O2 -pipe"
    ./configure --user=nobody --group=nobody \
    --prefix=/usr/local/nginx \
    --with-http_stub_status_module \
    --with-google_perftools_module \
    --with-cc-opt="-I /usr/include/openssl" \
    --with-http_ssl_module 

    make ${JOBS} && make install
    cd ../ && rm -rf nginx-1.4.4/
    ln -s /usr/local/lib/libpcre.so.1  /lib64/

    # 安装phpmyadmin
    tar jxf phpmyadmin.tar.bz2
    /bin/mv -f phpmyadmin/ /var/www/html/
    cp -f /var/www/html/phpmyadmin/config.sample.inc.php  /var/www/html/phpmyadmin/config.inc.php
    sed -i "s#?>##g"  /var/www/html/phpmyadmin/config.inc.php

    sed -i '/.*ProtectBinary.*/d' /var/www/html/phpmyadmin/config.inc.php
    echo "\$cfg['ProtectBinary'] = false;" >> /var/www/html/phpmyadmin/config.inc.php

    sed -i '/.*DisplayBinaryAsHex.*/d' /var/www/html/phpmyadmin/config.inc.php
    echo "\$cfg['DisplayBinaryAsHex'] = false;" >> /var/www/html/phpmyadmin/config.inc.php

    echo "\$cfg['VersionCheck'] = false;" >> /var/www/html/phpmyadmin/config.inc.php


    cd ${SCRIPT_DIR}
    mkdir -p /usr/local/nginx/conf/vhost/ 2>/dev/null
    /bin/cp -rvf ${FILE_DIR}/nginx.conf /usr/local/nginx/conf/
    /bin/cp -rvf ${FILE_DIR}/example.conf /usr/local/nginx/conf/
    /bin/cp -rvf ${FILE_DIR}/nginx /etc/init.d/

    # 在/usr/local/nginx/conf目录中创建fcgi.conf文件
    cat > /usr/local/nginx/conf/fcgi.conf << "EOF"
fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
fastcgi_param  SERVER_SOFTWARE    nginx;

fastcgi_param  QUERY_STRING       $query_string;
fastcgi_param  REQUEST_METHOD     $request_method;
fastcgi_param  CONTENT_TYPE       $content_type;
fastcgi_param  CONTENT_LENGTH     $content_length;

fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name;
fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
fastcgi_param  REQUEST_URI        $request_uri;
fastcgi_param  DOCUMENT_URI       $document_uri;
fastcgi_param  DOCUMENT_ROOT      $document_root;
fastcgi_param  SERVER_PROTOCOL    $server_protocol;

fastcgi_param  REMOTE_ADDR        $remote_addr;
fastcgi_param  REMOTE_PORT        $remote_port;
fastcgi_param  SERVER_ADDR        $server_addr;
fastcgi_param  SERVER_PORT        $server_port;
fastcgi_param  SERVER_NAME        $server_name;
fastcgi_param  REMOTE_USER        $remote_user; 
# PHP only, required if PHP was built with --enable-force-cgi-redirect
# fastcgi_param  REDIRECT_STATUS    200;
EOF

    # 增加安卓和苹果的mime类型
    cp -f /usr/local/nginx/conf/mime.types.default /usr/local/nginx/conf/mime.types
    sed -i '/}/d' /usr/local/nginx/conf/mime.types
    echo "application/vnd.android.package-archive apk;" >> /usr/local/nginx/conf/mime.types
    echo "application/iphone pxl ipa;" >> /usr/local/nginx/conf/mime.types
    echo "}" >> /usr/local/nginx/conf/mime.types

    chmod 755 /etc/init.d/nginx
    /sbin/chkconfig --add nginx
    /sbin/chkconfig nginx on
    echo "<?phpinfo();?>" > /var/www/html/123.php
    cd ${SCRIPT_DIR}
}


########## 安装mysql的IBDB引擎 ##########
Install_IBDB()
{
    cd ${SCRIPT_DIR}
    cd ${PACKAGE_DIR}/
    # 安装 boost
    tar -jxf boost_1_42_0.tar.bz2
    cd boost_1_42_0
    ./bootstrap.sh --prefix=/usr/local/boost
    ./bjam install  
    export BOOST_ROOT=/usr/local/boost  
    echo "/usr/local/boost/lib" > /etc/ld.so.conf.d/boost-x86_64.conf  
    ldconfig  
    cd ../
    rm -rf boost_1_42_0

    # 安装infobright
    groupadd mysql
    /usr/sbin/useradd -g mysql mysql

    tar -zxf infobright-4.0.7-0-src-ice.tar.gz
    cd infobright-4.0.7
    make ${JOBS} EDITION=community release 
    make ${JOBS} EDITION=community install-release
    cp -f src/build/pkgmt/my-ib.cnf /etc/

    sed -i '/skip-name-resolve/d' /etc/my-ib.cnf
    sed -i '/max_connections=.*/d' /etc/my-ib.cnf
    sed -i "s#\[mysqld\]#\[mysqld\]\nskip-name-resolve\nmax_connections=6000#g" /etc/my-ib.cnf

    /usr/local/infobright/bin/mysql_install_db --defaults-file=/etc/my-ib.cnf --user=mysql &
    cd ../
    rm -rf infobright-4.0.7
    cd /usr/local/infobright
    chown -R root  .  
    chown -R mysql var cache  
    chgrp -R mysql . 
    cp -f share/mysql/mysql.server /etc/init.d/mysqld-ib
    sed -i 's/^conf=.*/conf=\/etc\/my-ib\.cnf/g'    /etc/init.d/mysqld-ib
    sed -i 's/^user=.*/user=mysql/g'    /etc/init.d/mysqld-ib
    cp -rf ${SCRIPT_DIR}/${FILE_DIR}/ib_manager.sh  /usr/local/infobright
    chmod 755 /usr/local/infobright/ib_manager.sh
    # /sbin/service mysqld-ib restart
    # /sbin/chkconfig --add mysqld-ib
    # /sbin/chkconfig mysqld-ib on
    cd ${SCRIPT_DIR}
}


########## 安装python等工具 ##########
Install_Python()
{
    cd ${SCRIPT_DIR}
    cd ${PACKAGE_DIR}/  
    # 安装setuptools
    tar -zxf setuptools-0.6c11.tar.gz
    cd setuptools-0.6c11
    python setup.py install
    cd ../ && rm -rf setuptools-0.6c11
        
    # 安装MySQL-python
    tar -zxf MySQL-python-1.2.3.tar.gz
    cd MySQL-python-1.2.3
    python setup.py build
    python setup.py install
    cd ../ && rm -rf MySQL-python-1.2.3 
    cd ${SCRIPT_DIR}
}


########## 安装监控软件的客户端 ##########
Install_Monitor()
{
    cd ${SCRIPT_DIR}
    ##### 安装nagios_client
    /usr/sbin/groupadd nagios
    /usr/sbin/useradd -g nagios nagios
    cd ${PACKAGE_DIR}/monitor_cli/
    # 安装nagios-plugins
    tar -zxf nagios-plugins-1.4.15.tar.gz
    cd nagios-plugins-1.4.15
    ./configure --prefix=/usr/local/nagios --with-nagios-user=nagios --with-nagios-group=nagios
    make ${JOBS} && make install
    cd ..
    rm -rf nagios-plugins-1.4.15
    # 安装nrpe
    tar zxf nrpe-2.12.tar.gz
    cd nrpe-2.12
    ./configure
    make all
    make install-plugin
    make install-daemon  
    make install-daemon-config
    cd ..
    rm -rf nrpe-2.12

    ln -s /usr/local/nagios/bin/nrpe /usr/bin/nrpe
    cp -rf /usr/local/nagios/etc/nrpe.cfg  /usr/local/nagios/etc/nrpe.cfg.bak.${CDATE}
    sed -i "s/allowed_hosts=.*/allowed_hosts=127.0.0.1,${CENTER_IP}/g" /usr/local/nagios/etc/nrpe.cfg


    sed -i '/^command\[check_users\].*/d' /usr/local/nagios/etc/nrpe.cfg
    sed -i '/^command\[check_load\].*/d' /usr/local/nagios/etc/nrpe.cfg
    sed -i '/^command\[check_hda1\].*/d' /usr/local/nagios/etc/nrpe.cfg
    sed -i '/^command\[check_zombie_procs\].*/d' /usr/local/nagios/etc/nrpe.cfg
    sed -i '/^command\[check_total_procs\].*/d' /usr/local/nagios/etc/nrpe.cfg

    echo "command[cpu_load]=/usr/local/nagios/libexec/check_load -w 30,30,30 -c 35,35,35" >> /usr/local/nagios/etc/nrpe.cfg
    echo "command[disk_free]=/usr/local/nagios/libexec/check_disk -w 20% -c 10% -p /dev/sda3" >> /usr/local/nagios/etc/nrpe.cfg
    echo "command[ping_repo]=/usr/local/nagios/libexec/check_ping -H ${CENTER_IP} -w 100,20% -c 200,30% -p 5 -t 10" >>/usr/local/nagios/etc/nrpe.cfg
    echo "command[swap_free]=/usr/local/nagios/libexec/check_swap -w 50% -c 30%" >> /usr/local/nagios/etc/nrpe.cfg

    echo "command[check_raid]=/usr/bin/sudo /usr/local/nagios/etc/check_scripts/check_raid.sh" >> /usr/local/nagios/etc/nrpe.cfg
    echo "command[check_mysql]=/usr/bin/sudo /usr/local/nagios/etc/check_scripts/check_mysqld.sh" >> /usr/local/nagios/etc/nrpe.cfg
	echo "command[check_inode]=/usr/bin/sudo /usr/local/nagios/etc/check_scripts/check_inode.sh" >> /usr/local/nagios/etc/nrpe.cfg

    test -d /usr/local/nagios/etc/check_scripts || mkdir -p /usr/local/nagios/etc/check_scripts
    cp -rf check_scripts/* /usr/local/nagios/etc/check_scripts/
    chmod +x /usr/local/nagios/etc/check_scripts/*

    # 启动NRPE
    /usr/local/nagios/bin/nrpe -c /usr/local/nagios/etc/nrpe.cfg -d

    echo "/usr/bin/nrpe -c /usr/local/nagios/etc/nrpe.cfg -d" > /root/nrpe_start
    echo "pkill -9 nrpe" > /root/nrpe_stop
    echo "pkill -9 nrpe" > /root/nrpe_restart
    echo "sleep 2" >> /root/nrpe_restart
    echo "/usr/bin/nrpe -c /usr/local/nagios/etc/nrpe.cfg -d" >> /root/nrpe_restart
    /bin/chmod +x /root/nrpe*

    ##### 安装zabbix_client
    #/usr/sbin/groupadd zabbix
    #/usr/sbin/useradd -g zabbix zabbix
    #test -d /usr/local/zabbix || mkdir -p /usr/local/zabbix
    #tar -zxf zabbix_agents_2.0.0.linux2_6.amd64.tar.gz -C /usr/local/zabbix
    #cp -rf zabbix_agentd.conf /usr/local/etc/
    #cp -rf zabbix_agentd /etc/init.d/zabbix_agentd
    #chmod +x  /etc/init.d/zabbix_agentd
    #chkconfig --add zabbix_agentd
    #chkconfig zabbix_agentd on
    #cd ${SCRIPT_DIR}
    ## 在zabbix自动注册服务器信息
    #server_ip=`/sbin/ifconfig | grep "inet addr:" | sed -n '1p' | awk '{print $2}' | awk -F: '{print $2}'`
    #sed -i "s#Hostname=.*#Hostname=IP-${server_ip}#g" /usr/local/etc/zabbix_agentd.conf
    #/etc/init.d/zabbix_agentd restart

    #安装cacti-io插件
    cd ${SCRIPT_DIR}/${PACKAGE_DIR}/snmpdiskio-0.9.6/
    cp -raf snmpdiskio /usr/local/bin/
    chmod +x /usr/local/bin/snmpdiskio
    #cacti服务端配置
    mkdir -p /var/www/html/cacti/resource/snmp_queries/
    cp -raf partition.xml /var/www/html/cacti/resource/snmp_queries/
    echo "extend .1.3.6.1.4.1.2021.54 hdNum /bin/sh /usr/local/bin/snmpdiskio hdNum" >> /etc/snmp/snmpd.conf
    echo "extend .1.3.6.1.4.1.2021.55 hdIndex /bin/sh /usr/local/bin/snmpdiskio hdIndex" >> /etc/snmp/snmpd.conf
    echo "extend .1.3.6.1.4.1.2021.56 hdDescr /bin/sh /usr/local/bin/snmpdiskio hdDescr" >> /etc/snmp/snmpd.conf
    echo "extend .1.3.6.1.4.1.2021.57 hdInBlocks /bin/sh /usr/local/bin/snmpdiskio hdInBlocks" >> /etc/snmp/snmpd.conf
    echo "extend .1.3.6.1.4.1.2021.58 hdOutBlocks /bin/sh /usr/local/bin/snmpdiskio hdOutBlocks" >> /etc/snmp/snmpd.conf
    /etc/init.d/snmpd restart

    #安装MegaCli
    cd ${SCRIPT_DIR}/${PACKAGE_DIR}
    rpm -ivh MegaCli-8.07.10-1.noarch.rpm
}


########## 安装memcached ##########
Install_Memcached()
{
    cd ${SCRIPT_DIR}
    cd ${PACKAGE_DIR}/
    
    tar zxf memcached-1.4.17.tar.gz
    cd memcached-1.4.17
    CHOST="x86_64-pc-linux-gnu"
    CFLAGS="-mtune=native -march=native -O2 -pipe" 
    CXXFLAGS="-mtune=native -march=native -O2 -pipe"
    ./configure --with-libevent=/usr
    make ${JOBS} && make install
    cd ../ && rm -rf memcached-1.4.17

    tar zxf memcache-2.2.7.tgz
    cd memcache-2.2.7
    CHOST="x86_64-pc-linux-gnu"
    CFLAGS="-mtune=native -march=native -O2 -pipe" 
    CXXFLAGS="-mtune=native -march=native -O2 -pipe"
    /usr/local/php/bin/phpize
    ./configure --enable-memcache --with-php-config=/usr/local/php/bin/php-config --with-zlib-dir
    make ${JOBS} && make install
    cd ../ && rm -rf memcache-2.2.7

    echo "killall memcached" > /root/memcached_stop
    echo "/usr/local/bin/memcached -d -m 1024 -c 4096 -p 9900 -u root" > /root/memcached_start
    cat > /root/memcached_restart << "EOF"
#!/bin/bash
./memcached_stop
if [[ `ps -ef | grep "/usr/local/bin/memcached" | grep -v grep | wc -l` == 0 ]];then
    echo "memcached已关闭"
fi
sleep 1
./memcached_start
if [[ `ps -ef | grep "/usr/local/bin/memcached" | grep -v grep | wc -l` != 0 ]];then
    echo "memcached已开启"
fi
EOF
    /bin/chmod +x /root/memcached*

    #安装memcacheq 依赖: Berkeley DB
    tar zxf db-5.0.21.NC.tar.gz
    cd db-5.0.21.NC/build_unix/
    CFLAGS="-O3" CXX=gcc CXXFLAGS="-O3 -felide-constructors -fno-exceptions -fno-rtti" ../dist/configure
    sed -i 's/CC = gcc/CC = gcc -fPIC/g' Makefile
    make ${JOBS} && make install
    cd ../../ && rm -rf db-5.0.21.NC/
    echo "/usr/local/BerkeleyDB.5.0/lib" > /etc/ld.so.conf.d/BerkeleyDB.5.0.conf
    ldconfig

    #安装memcacheq
    cd ${PACKAGE_DIR}/
    tar zxf memcacheq-0.2.0.tar.gz
    cd memcacheq-0.2.0/
    ./configure  --with-bdb=/usr/local/BerkeleyDB.5.0 --enable-threads
    make ${JOBS} && make install
    cd ../ && rm -rf memcacheq-0.2.0/
    mkdir -p /data/memcacheq/
    chown -R nobody:nobody /data/memcacheq/

    #生成memcacheq脚本
    echo "memcacheq -d -c 4096 -p 22201 -u nobody -t 10 -r -B 8192 -A 16384 -H /data/memcacheq -N -v > /var/log/mq_error.log 2>&1 " > /root/mq_start
    echo "pkill -9 memcacheq" > /root/mq_stop
    ! grep "sleep 1" /root/mq_reset > /dev/null && echo "sleep 1" >> /root/mq_reset
    ! grep "/data/memcacheq/" /root/mq_reset > /dev/null && echo "/bin/rm -rf /data/memcacheq/*" >> /root/mq_reset
    ! grep "/root/mq_start" /root/mq_reset > /dev/null && echo "/root/mq_start" >> /root/mq_reset
    chmod 700 /root/mq_*

    cd ${SCRIPT_DIR}
}


########## 安装erlang和peb ##########
Install_Erlang()
{
    cd ${SCRIPT_DIR}
    cd ${PACKAGE_DIR}/

    #此erlang版本otp_src_R16B03-1需要先编译安装openssl，centos 6.4自带openssl-1.0.1e
    /bin/rm -rf openssl-1.0.1f
    tar zxvf openssl-1.0.1f.tar.gz
    cd openssl-1.0.1f
    ./config --prefix=/usr/local/ssl
    ##config之后，会生成Makefile，打开Makefile找到gcc，在CFLAG参数列表里加上-fPIC
    sed -i 's/CFLAG= -DOPENSSL_THREADS/CFLAG= -fPIC -DOPENSSL_THREADS/g' Makefile
    make && make install
    cd ../ && rm -rf openssl-1.0.1f

    ##替换新安装的openssl
    mv /usr/bin/openssl /usr/bin/openssl.${CDATE}
    mv /usr/include/openssl /usr/include/openssl.${CDATE}
    ln -sf /usr/local/ssl/bin/openssl /usr/bin/openssl
    ln -sf /usr/local/ssl/include/openssl /usr/include/openssl
    ##配置库文件搜索路径
    echo "/usr/local/ssl/lib/" >> /etc/ld.so.conf
    ldconfig -v 
    openssl version -a

    /bin/rm -rf otp_src_R16B03-1
    tar zxvf otp_src_R16B03-1.tar.gz
    cd otp_src_R16B03-1
    ./configure --enable-kernel-poll --enable-threads --enable-smp-support --enable-hipe --with-ssl=/usr/local/ssl/
    make ${JOBS} && make install
    ln -s /usr/local/bin/erl /usr/bin/
    cd ../ && rm -rf otp_src_R16B03-1/

    ##安装peb插件
    #rm -rf peb_release/
    #tar xzvf peb-0.20b.tar.gz
    #cd peb_release
    #/usr/local/php/bin/phpize
    #./configure --with-php-config=/usr/local/php/bin/php-config --enable-peb
    #./configure CC="gcc -L /usr/local/lib/erlang/lib/erl_interface-3.7.8/lib -I/usr/local/lib/erlang/lib/erl_interface-3.7.8/include" --with-php-config=/usr/local/php/bin/php-config
    #/bin/cp -rvf /usr/local/lib/erlang/lib/erl_interface-3.7.15/include/* ./
    #/bin/cp -rvf /usr/local/lib/erlang/lib/erl_interface-3.7.15/lib/* /usr/local/lib/
    #/bin/cp -rvf /usr/local/lib/erlang/lib/erl_interface-3.7.15/lib/* /usr/local/lib64/
    #make ${JOBS} && make install
    #cd ../ && rm -rf peb_release

    ##修改php文件添加peb.so
    ##目前魔神和剑道ERLANG服务端跟PHP已经没有通信，所以可以不添加peb.so扩展
    #! grep "peb.so" /usr/local/php/etc/php.ini > /dev/null && sed -i '/memcache.so/a extension= "peb.so"' /usr/local/php/etc/php.ini

    cd ${SCRIPT_DIR}
}


########## 输出检测信息 ##########
Check_Config()
{
echo "=================检测信息======================"
echo "Mysql启动信息"
/sbin/service mysqld restart    
echo "==============================================="
echo "Mysql-ib启动信息"
/sbin/service mysqld-ib restart
echo "==============================================="
echo "nginx启动信息"
/sbin/service nginx restart 
echo "==============================================="
echo "php-fpm启动信息"
/sbin/service php-fpm restart 
echo "==============================================="
echo "磁盘信息:"
/bin/df -lh
echo "==============================================="
/usr/sbin/ntpdate time.nist.gov
/sbin/hwclock --systohc
cdate=`date +'%Y年%m月%d日%H时%M分%S秒'`
echo "服务器时间:${cdate}"
}

################
# 开始执行脚本 #
################

start_install=`date +"%s"`
cd `dirname $0`
SCRIPT_DIR=`pwd`

KEY_DIR='keys'
FILE_DIR='files'
PACKAGE_DIR='packages'
CDATE=`date '+%Y-%m-%d_%H-%M-%S'`

CENTER_IP='121.201.11.201'

JOBS='-j8'
# 安装系统
Install_Package_Optimize
Install_NMP
#Install_Python
#Install_IBDB
Install_Memcached
Install_Erlang
Install_Monitor 

Add_Users
Config_SSH
Config_Rsync
#Conf_Iptable
Check_Config

end_install=`date +"%s"`
minute=$(( (${end_install} - ${start_install})/60 ))
second=$(( (${end_install} - ${start_install})%60 ))
echo "执行时间:${minute}分${second}秒"
