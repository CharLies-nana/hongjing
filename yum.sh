#!/bin/bash

[[ $# -ne 1 ]] && { echo "执行格式错误，正确格式如下：" ; echo "$0 <physical|cloud>" ; echo -e "1.所有云服务器，都使用 cloud 选项;\n2.公司自有的大陆物理机器，使用 physical 选项;\n3.合作商提供的大陆机器，使用 physical 选项;\n4.自有或合作商提供的海外机器，使用 cloud 选项" ; exit ; }

cd `dirname $0`
SCRIPT_DIR=`pwd`

FILE_DIR='files'
PACKAGE_DIR='packages'
CDATE=`date '+%Y-%m-%d_%H-%M-%S'`

MACHINE_TYPE=$1

cd ${SCRIPT_DIR}

#判断是使用系统自带的yum源还是使用163.com的yum源配置
if [[ "${MACHINE_TYPE}" == 'physical' ]]
then
	/bin/mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak.${CDATE}
	#/usr/bin/wget http://mirrors.163.com/.help/CentOS6-Base-163.repo
	/bin/cp ${FILE_DIR}/CentOS6-Base-163.repo /etc/yum.repos.d/CentOS-Base.repo
elif [[ "${MACHINE_TYPE}" == 'cloud' ]]
then
	echo "使用系统自带的yum源配置！"
else
	echo "参数错误，正确格式：$0 <physical|cloud>"
	exit
fi

/usr/bin/yum clean all
/usr/bin/yum makecache
/usr/bin/yum -y update bash

/usr/bin/yum -y install autoconf automake bash bind-utils bison \
	bzip2 bzip2-devel cmake curl curl-devel *curses* dos2unix e2fsprogs e2fsprogs-devel \
	elfutils-devel flex fontconfig fontconfig-devel \
	freetype freetype-devel gcc  gcc-c++  glib2 glib2-devel \
	glibc glibc-devel krb5-devel libevent-devel libidn libidn-devel libjpeg libjpeg-devel \
	libpcap libpcap-devel libpng libpng-devel libtool libtool-ltdl libtool-ltdl-devel \
	libxml2 libxml2-devel libXpm libXpm-devel lm_sensors* lrzsz mysql-devel MySQL-python \
	ncurses ncurses-devel net-snmp* nmap ntp openldap openldap-clients openldap-devel openldap-servers \
	openssh-clients openssl *openssl* openssl-devel pam-devel perl-CPAN python-devel redhat-lsb \
	rsync screen sendmail subversion sysstat telnet unixODBC unixODBC-devel \
	unzip vim wget xinetd yajl zip zlib zlib-devel