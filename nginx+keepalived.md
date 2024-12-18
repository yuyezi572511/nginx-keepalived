## nginx+keepalived

/bin/bash    auto_config_nginx_vhosts_v5.sh 

（1） 环境准备

| Nginx版本：nginx v1.18.0<br/>Keepalived版本：keepalived v1.2.8<br/>Nginx-1：192.168.26.145 （Master）<br/>Nginx-2：192.168.26.150 （Backup） |
| ------------------------------------------------------------ |

（2） Keepalived安装配置

```shell
tar -xzvf keepalived-1.2.1.tar.gz
cd keepalived-1.2.1
./configure --prefix=/usr/local/keepalived/
--with-kernel-dir=/usr/src/kernels/3.10.0-514.el7.x86_64/
make
make install
DIR=/usr/local/
\cp $DIR/etc/rc.d/init.d/keepalived /etc/rc.d/init.d/
\cp $DIR/etc/sysconfig/keepalived /etc/sysconfig/
mkdir -p /etc/keepalived
\cp $DIR/sbin/keepalived /usr/sbin/
```

（3） 配置Keepalived，两台服务器keepalived.conf内容都为如下，state均设置为backup，Backup服务器需要修改优先级为90。

```shell
! Configuration File for keepalived
global_defs {
notification_email {
support@yyz.net
}
notification_email_from wgkgood@163.com
smtp_server 127.0.0.1
smtp_connect_timeout 30
router_id LVS_DEVEL
}
vrrp_script chk_nginx {
script "/data/sh/check_nginx.sh"
interval 2
weight 2
}
\# VIP1
vrrp_instance VI_1 {
state BACKUP
interface eth0
lvs_sync_daemon_inteface eth0
virtual_router_id 151
priority 100
advert_int 5
nopreempt
authentication {
auth_type PASS
auth_pass 1111

}
virtual_ipaddress {
192.168.0.198
}
track_script {
chk_nginx
}
}
```

如上配置还需要建立check_nginx脚本，用于检查本地Nginx是否存活，如
果不存活，则kill keepalived实现切换。其中check_nginx.sh脚本内容如下：

```shell
\#!/bin/bash
\#auto check nginx process
\#2017-5-26 17:47:12
\#by author jfedu.net
killall -0 nginx
if [[ $? -ne 0 ]]；then
/etc/init.d/keepalived stop
fi
```

在两台Nginx服务器分别新建index.html测试页面，然后启动Nginx服务测试，访问VIP地址，http://192.168.0.198即可。

1.2 Keepalived配置文件参数详解
完整的keepalived的配置文件，其配置文件keepalived.conf可以包含三个文本
块：全局定义块、VRRP实例定义块及虚拟服务器定义块。全局定义块和虚拟服
务器定义块是必须的，如果在只有一个负载均衡器的场合，就不须VRRP实例定
义块。
\#全局定义块
global_defs {
notification_email { #指定keepalived在
发生切换时需要发送email到的对象，一行一个;
wgkgood@gmail.com
}
notification_email_from root@localhost #指定发件人
smtp_server mail.jfedu.net #指定smtp服务器地
址
smtp_connect_timeout 3 #指定smtp连接超时
时间
router_id LVS_DEVEL #运行keepalived机器的
标识
}
\#监控Nginx进程
vrrp_script chk_nginx {
script "/data/script/nginx.sh" #监控服务脚本，脚本x执

行权限；
interval 2 #检测时间间隔(执行脚本
间隔)
weight 2
}
\#VRRP实例定义块
vrrp_sync_group VG_1{ 监控多个网段的实例
group {
VI_1 实例名
VI_2
}
notify_master /data/sh/nginx.sh #指定当切换到master时，
执行的脚本
notify_backup /data/sh/nginx.sh #指定当切换到backup时
，执行的脚本
notify /data/sh/nginx.sh #发生任何切换，均执行的
脚本
smtp_alert #使用global_defs中
提供的邮件地址和smtp服务器发送邮件通知；
}
vrrp_instance VI_1 {
state BACKUP #设置主机状态，

MASTER|BACKUP
nopreempt #设置为不抢占
interface eth0 #对外提供服务的网
络接口
lvs_sync_daemon_inteface eth0 #负载均衡器之间监控
接口;
track_interface { #设置额外的监控，网卡出
现问题都会切换；
eth0
eth1
}
mcast_src_ip #发送多播包的地址，
如果不设置默认使用绑定网卡的primary ip
garp_master_delay #在切换到master状
态后，延迟进行gratuitous ARP请求
virtual_router_id 50 #VRID标记 ,路由ID，可
通过#tcpdump vrrp查看
priority 90 #优先级，高优先级竞选为
master
advert_int 5 #检查间隔，默认5秒
preempt_delay #抢占延时，默认5分钟
debug #debug日志级别

authentication { #设置认证
auth_type PASS #认证方式
auth_pass 1111 #认证密码
}
track_script { #以脚本为监控
chk_nginx；
chk_nginx
}
virtual_ipaddress { #设置vip
192.168.111.188
}
}
注意：使用了脚本监控Nginx或者MYSQL，不需要如下虚拟服务器设置块。
\#虚拟服务器定义块
virtual_server 192.168.111.188 3306 {
delay_loop 6 #健康检查时间间隔
lb_algo rr #调度算法rr|wrr|lc|wlc|lblc|sh|dh
lb_kind DR #负载均衡转发规则
NAT|DR|TUN
persistence_timeout 5 #会话保持时间
protocol TCP #使用的协议
real_server 192.168.1.12 3306 {

weight 1 #默认为1,0为失效
notify_up <string> | <quoted-string> #在检测到
server up后执行脚本；
notify_down <string> | <quoted-string> #在检测到
server down后执行脚本；
TCP_CHECK {
connect_timeout 3 #连接超时时间;
nb_get_retry 1 #重连次数;
delay_before_retry 1 #重连间隔时间;
connect_port 3306 #健康检查的端口;
}
HTTP_GET {
url {
path /index.html #检测url，可写多个
digest 24326582a86bee478bac72d5af25089e #检测效验
码
\#digest效验码获取方法：genhash -s IP -p 80 -u
http://IP/index.html
status_code 200 #检测返回http状态码
}
}
}