#!/bin/bash
#2024年3月15日20:55:53
#auto install nginx web.
#by author www.jfedu.net
########################
NGX_VHOST="$*"
NGX_CNF="nginx.conf"
NGX_DIR="/usr/local/nginx"
NGX_URL="http://nginx.org/download"
NGX_ARGS="--user=www --group=www --with-http_stub_status_module"

install_nginx(){
	if [ ! -f $NGX_DIR/sbin/nginx ];then
		shift 1
		#下载Nginx软件包
		wget -c $NGX_URL/nginx-$1.tar.gz -P /usr/src/
		#Cd切换至/usr/src/
		cd /usr/src
		ls -l nginx-$1
		#通过Tar工具对其解压；
		tar -xzvf nginx-$1.tar.gz
		#Cd切换至Nginx源代码目录；
		cd nginx-$1/
		#提前解决编译时所需的依赖环境、库文件；
		yum install -y gcc pcre-devel zlib-devel openssl-devel
		#创建www用户和组；
		useradd -s /sbin/nologin www -M
		#预编译；
		./configure --prefix=$NGX_DIR/ $NGX_ARGS 
		#编译；
		make -j4
		#安装;
		make -j4 install
		#查看Nginx是否部署成功；
		ls -l $NGX_DIR/
		#启动Nginx服务进程；
		$NGX_DIR/sbin/nginx
		#查看Nginx进程；
		ps -ef|grep nginx
		#Firewalld防火墙对外开放80端口；
		#firewall-cmd --add-port=80/tcp --permanent
		#systemctl reload firewalld.service
		setenforce 0
		systemctl stop firewalld.service
	else
		echo -e "\033[32m-------------\033[0m"
		echo -e "\033[32mls -l $NGX_DIR/\033[0m"
		ls -l $NGX_DIR/
		exit
	fi
}

update_nginx(){
	#下载Nginx软件包
	shift 1
        wget -c $NGX_URL/nginx-$1.tar.gz -P /usr/src/
        #Cd切换至/usr/src/
        cd /usr/src
        ls -l nginx-$1.tar.gz 
        #通过Tar工具对其解压；
        tar -xzvf nginx-$1.tar.gz
        #Cd切换至Nginx源代码目录；
        cd nginx-$1/
        #提前解决编译时所需的依赖环境、库文件；
        yum install -y gcc pcre-devel zlib-devel openssl-devel
        #创建www用户和组；
        useradd -s /sbin/nologin www -M
        #预编译；
        ./configure --prefix=$NGX_DIR/ $NGX_ARGS
        #编译；	
	make -j4
	#备份原nginx执行文件；
	\mv $NGX_DIR/sbin/nginx $NGX_DIR/sbin/nginx.old.`date +%F`	
	#拷贝最新的nginx文件覆盖原nginx执行文件；
	\cp objs/nginx $NGX_DIR/sbin/	
	#重启Nginx服务；
	$NGX_DIR/sbin/nginx -s reload
	echo -e "\033[32m-------------\033[0m"
	echo -e "\033[32mNginx$1版本完成，请检查.\033[0m"
	$NGX_DIR/sbin/nginx -v
}

remove_nginx(){
	read -p "请确认是否删除Nginx $NGX_DIR/，删除之后无法恢复？yes or no" INPUT
	if [ $INPUT == "yes" -o $INPUT == "y" ];then
		pkill nginx
		userdel -r www
		rm -rf $NGX_DIR/
		echo -e "\033[32m-------------\033[0m"
		echo -e "\033[32m$NGX_DIR目录删除完毕，请查看.\033[0m"
	fi
}

remove_vhost(){
	shift 1
	echo -e "\033[31m请确认是否删除Nginx虚拟主机 $*，删除之后无法恢复？yes or no\033[0m"
	read INPUT
	if [ $INPUT == "yes" -o $INPUT == "y" ];then
	for NGX_VHOST in $*
	do
	#echo -e "\033[31m请确认是否删除Nginx虚拟主机$NGX_VHOST，删除之后无法恢复？yes or no\033[0m"
		rm -rf $NGX_DIR/conf/domains/$NGX_VHOST
		rm -rf $NGX_DIR/html/$NGX_VHOST
		$NGX_DIR/sbin/nginx -s reload
		echo -e "\033[32m-------------\033[0m"
		echo -e "\033[32m$NGX_VHOST虚拟主机删除完毕，请查看.\033[0m"
		ls -l $NGX_DIR/conf/domains/
	done
	fi
}

add_vhost(){
#配置Nginx虚拟主机
cd $NGX_DIR/conf/
\cp ${NGX_CNF} ${NGX_CNF}.bak
cat>${NGX_CNF}<<EOF
worker_processes  1;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    include domains/*;
}
EOF
mkdir -p domains
cd domains/
shift 1
for NGX_VHOST in $*
do
touch $NGX_VHOST
cat>$NGX_VHOST<<EOF
server {
        listen       80;
        server_name  $NGX_VHOST;
        location / { 
            root   html/$NGX_VHOST;
            index  index.html index.htm;
        }   
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
}
EOF
cat $NGX_VHOST
echo -e "\033[32m-------------\033[0m"
echo -e "\033[32m$NGX_VHOST虚拟主机添加成功，请查看.\033[0m"
mkdir -p $NGX_DIR/html/$NGX_VHOST/
cat>$NGX_DIR/html/$NGX_VHOST/index.html<<EOF
<h1>$NGX_VHOST test pages.</h1>
<hr color=red>
EOF
$NGX_DIR/sbin/nginx -t >>/dev/null 2>&1
$NGX_DIR/sbin/nginx -s reload
done
}

if [ $# -lt 2 ];then
	echo -e "\033[32m1)-I 1.18.0 ,Install nginx.\033[0m"
	echo -e "\033[32m2)-U 1.18.0 ,Update nginx.\033[0m"
	echo -e "\033[32m3)-A 1.18.0 ,Add nginx vhost.\033[0m"
	echo -e "\033[32m4)-d v1.jf.com ,remove nginx vhost\033[0m"
	echo -e "\033[32m5)-D v1.jf.com ,remove nginx web.\033[0m"
	echo -e "\033[32mUsage:{/bin/sh $0 -I|-U|-A|-d|-D|help}\033[0m"
	exit 1
fi

case $1 in
	-i|-I )
	install_nginx $*
	;;
	-D )
	remove_nginx
	;;
	-u|-U )
	update_nginx $*
	;;
	-a|-A )
	add_vhost $*
	;;
	-d )
	remove_vhost $*
	;;
	* )
	echo -e "\033[32m1)-I 1.18.0 ,Install nginx.\033[0m"
	echo -e "\033[32m2)-U 1.18.0 ,Update nginx.\033[0m"
	echo -e "\033[32m3)-A 1.18.0 ,Add nginx vhost.\033[0m"
	echo -e "\033[32m4)-d v1.jf.com ,remove nginx vhost\033[0m"
	echo -e "\033[32m5)-D v1.jf.com ,remove nginx web.\033[0m"
	echo -e "\033[32mUsage:{/bin/sh $0 -I|-U|-A|-d|-D|help}\033[0m"
	exit
esac
