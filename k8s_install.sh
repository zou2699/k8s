#!/bin/bash
################################################
# modify：zouhl
# Script update time:2018-08-14
# Version: v1.1
################################################

#===============================公共变量=================================

#Source function library.（添加函数库）
. /etc/init.d/functions
source /etc/profile
#按任意键继续函数
get_char() 
{ 
SAVEDSTTY=`stty -g` 
stty -echo 
stty cbreak 
dd if=/dev/tty bs=1 count=1 2> /dev/null 
stty -raw 
stty echo 
stty $SAVEDSTTY 
} 
#date（设置时间格式）
DATE=`date +"%Y-%m-%d %H:%M:%S"`
DATE_ymd=`date +"%y-%m-%d"`
read -p "请输入本机内网IP：" IPADDR_7
read -p "请输入master端IP：" IPADDR_MASTER
#IPADDR_7=`ip addr show ens36|awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'`
#IPADDR_MASTER="192.168.31.111"
#IPADDR_7=`ifconfig  | grep 'inet'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $2}'`
#hostname（获取主机名）
HOSTNAME=`hostname -s`
#user（获取用户）
USER=`whoami`
#disk_check（获取根目录磁盘已使用容量）
DISK_SDA=`df -h |grep -w "/" |awk '{print $5}'`
#cpu_average_check （检测CPU在1分、3分、5分时的使用率）
cpu_uptime=`cat /proc/loadavg|awk '{print $1,$2,$3}'`
#free (内存使用率)
phymem=`free | grep "Mem:" |awk '{print $2}'`
phymemused=`free | grep "Mem:" |awk '{print $6}'`
free_7=`awk 'BEGIN{printf"%.2f%\n",('$phymemused'/'$phymem')*100}'`
#system vresion（获取系统版本）
sys_vresion_7=`cat /etc/redhat-release | awk '{print $1 " " $4}'`
#cpuUsage(cpu使用率)
cpuUsage_7=`top -n 1 | awk -F '[ %]+' 'NR==3 {print $3}'`

#set LANG（设置系统为UTF-8字符集）
#export LANG=zh_CN.UTF-8
#: > /etc/locale.conf
#cat >>/etc/locale.conf<<EOF
#LANG=zh_CN.UTF-8
#EOF
#Require root to run this script.（验证用户是否为root）
uid=`id | cut -d\( -f1 | cut -d= -f2`
if [ $uid -ne 0 ];then
  action "Please run this script as root." /bin/false
  action "请检查运行脚本的用户是否为ROOT." /bin/false
  exit 1
fi
#echo "安装基本工具,请稍后。。。。。。。。。。"
# yum install -y wget 

#============================任务栏=================================
memu1(){
echo "一键安装Kubernetes群集_Master端"
echo "===================================================="
echo "正在卸载旧版本Kubernetes，请稍后。。。。。。。。。。"
yum remove docker \
           docker-client \
           docker-client-latest \
           docker-common \
           docker-latest \
           docker-latest-logrotate \
           docker-logrotate \
           docker-selinux \
           docker-engine-selinux \
           docker-engine

if [ $? -eq 0 ];then
	action "旧版本Kubernetes卸载成功！" /bin/true
	sleep 3
	echo "================================================="
	echo "             验证完毕后请按任意键继续！！        "
	echo "================================================="
	char=`get_char`
else
	action "旧版本Kubernetes卸载失败！"  /bin/false
	sleep 3
	echo "================================================="
	echo "       程序即将退出，请处理后重新运行脚本！！    "
	echo "================================================="
	char=`get_char`
	exit 1
fi

if [ ! -e "./kubernetes-server-linux-amd64.tar.gz" ];then
    wget https://dl.k8s.io/v1.8.13/kubernetes-server-linux-amd64.tar.gz
else 
    echo "使用当前目录下的安装包kubernetes-server-linux-amd64.tar.gz"
fi

# yum安装,后续也改为二进制的形式
yum install -y etcd 
sed -i 's/ETCD_LISTEN_CLIENT_URLS="http:\/\/localhost:2379"/ETCD_LISTEN_CLIENT_URLS="http:\/\/0.0.0.0:2379"/g' /etc/etcd/etcd.conf
sed -i 's/ETCD_ADVERTISE_CLIENT_URLS="http:\/\/localhost:2379"/ETCD_ADVERTISE_CLIENT_URLS="http:\/\/0.0.0.0:2379"/g' /etc/etcd/etcd.conf
systemctl enable etcd
systemctl start etcd
if [ $? -eq 0 ];then
	echo "================================================="
	echo "         etcd安装成功，请按任意键继续！！        "
	echo "================================================="
	char=`get_char`
else
	echo "================================================="
	echo "         etcd安装失败，请按任意键退出！！        "
	echo "================================================="
	char=`get_char`
	exit 1
fi

# tar zxvf kubernetes-server-linux-amd64.tar.gz
mkdir /etc/kubernetes/
mv kubernetes/server/bin/{kube-apiserver,kube-scheduler,kube-controller-manager,kubectl} /usr/bin/
cat >/etc/kubernetes/kube-apiserver<< EOF 
# 启用日志标准错误
KUBE_LOGTOSTDERR="--logtostderr=true"
# 日志级别
KUBE_LOG_LEVEL="--v=4"
# Etcd服务地址
KUBE_ETCD_SERVERS="--etcd-servers=http://$IPADDR_7:2379"
# API服务监听地址
KUBE_API_ADDRESS="--insecure-bind-address=0.0.0.0"
# API服务监听端口
KUBE_API_PORT="--insecure-port=8080"
# 对集群中成员提供API服务地址
KUBE_ADVERTISE_ADDR="--advertise-address=$IPADDR_7"
# 允许容器请求特权模式，默认false
KUBE_ALLOW_PRIV="--allow-privileged=false"
# 集群分配的IP范围
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.10.10.0/24"
EOF
cat >/lib/systemd/system/kube-apiserver.service<< EOF 
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-/etc/kubernetes/kube-apiserver
#ExecStart=/usr/bin/kube-apiserver ${KUBE_APISERVER_OPTS}
ExecStart=/usr/bin/kube-apiserver \
\${KUBE_LOGTOSTDERR} \
\${KUBE_LOG_LEVEL} \
\${KUBE_ETCD_SERVERS} \
\${KUBE_API_ADDRESS} \
\${KUBE_API_PORT} \
\${KUBE_ADVERTISE_ADDR} \
\${KUBE_ALLOW_PRIV} \
\${KUBE_SERVICE_ADDRESSES}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-apiserver
systemctl restart kube-apiserver
if [ $? -eq 0 ];then
	echo "================================================="
	echo "   kube-apiserver安装成功，请按任意键继续！！    "
	echo "================================================="
	char=`get_char`
else
	echo "================================================="
	echo "   kube-apiserver安装失败，请按任意键退出！！    "
	echo "================================================="
	char=`get_char`
	exit 1
fi

cat >/etc/kubernetes/kube-scheduler<< EOF 
===============================================================================
KUBE_LOGTOSTDERR="--logtostderr=true"
KUBE_LOG_LEVEL="--v=4"
KUBE_MASTER="--master=$IPADDR_7:8080"
KUBE_LEADER_ELECT="--leader-elect"
EOF

cat >/lib/systemd/system/kube-scheduler.service<< EOF 
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-/etc/kubernetes/kube-scheduler
ExecStart=/usr/bin/kube-scheduler \
\${KUBE_LOGTOSTDERR} \
\${KUBE_LOG_LEVEL} \
\${KUBE_MASTER} \
\${KUBE_LEADER_ELECT}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-scheduler
systemctl restart kube-scheduler
if [ $? -eq 0 ];then
	echo "================================================="
	echo "   kube-scheduler安装成功，请按任意键继续！！    "
	echo "================================================="
	char=`get_char`
else
	echo "================================================="
	echo "   kube-scheduler安装失败，请按任意键退出！！    "
	echo "================================================="
	char=`get_char`
	exit 1
fi

cat >/etc/kubernetes/kube-controller-manager<< EOF 
KUBE_LOGTOSTDERR="--logtostderr=true"
KUBE_LOG_LEVEL="--v=4"
KUBE_MASTER="--master=$IPADDR_MASTER:8080"
EOF
cat >/lib/systemd/system/kube-controller-manager.service<< EOF 
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-/etc/kubernetes/kube-controller-manager
ExecStart=/usr/bin/kube-controller-manager \
\${KUBE_LOGTOSTDERR} \
\${KUBE_LOG_LEVEL} \
\${KUBE_MASTER} \
\${KUBE_LEADER_ELECT}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-controller-manager
systemctl restart kube-controller-manager
if [ $? -eq 0 ];then
	echo "===================================================="
	echo "kube-controller-manager安装成功，请按任意键继续！！ "
	echo "===================================================="
	char=`get_char`
else
	echo "===================================================="
	echo "kube-controller-manager安装失败，请按任意键退出！！ "
	echo "===================================================="
	char=`get_char`
	exit 1
fi

# 简易检测, 后续改进 todo
echo "ps aux | grep kube"
flag=`ps aux | grep kube | grep -v grep | wc -l`
if [ $flag -eq 3 ];then
	echo "========================================================="
	echo "         Master节点安装完毕,请按任意键继续 ！！！！！    "
	echo "========================================================="
	char=`get_char`
else
	echo "========================================================="
	echo "         Master节点安装失败,请按任意键退出 ！！！！！    "
	echo "========================================================="
	char=`get_char`
	exit 1
fi
}

memu2(){
echo "正在检测本机是否安装了docker服务"
systemctl status docker
if [ $? -eq 0 ];then
	echo "========================================================="
	echo "          docker服务已存在,请按任意键继续 ！！！！！     "
	echo "========================================================="
	char=`get_char`
else
	echo "========================================================="
	echo "docker服务未存在,请按任意键退出安装docker服务 ！！！！！ "
	echo "========================================================="
	char=`get_char`
	exit 1
fi

echo "一键安装Kubernetes群集_slave端"
if [ ! -e "./kubernetes-node-linux-amd64.tar.gz" ];then
    wget https://dl.k8s.io/v1.8.13/kubernetes-node-linux-amd64.tar.gz
else 
    echo "使用当前目录下的安装包kubernetes-server-linux-amd64.tar.gz"
fi
tar zxvf kubernetes-node-linux-amd64.tar.gz
mkdir /etc/kubernetes
mv kubernetes/node/bin/{kubectl,kubefed,kubelet,kube-proxy} /usr/bin/

cat >/etc/kubernetes/kubelet.kubeconfig<< EOF 
apiVersion: v1
kind: Config
clusters:
  - cluster:
      server: http://$IPADDR_MASTER:8080
    name: local
contexts:
  - context:
      cluster: local
    name: local
current-context: local
EOF

cat >/etc/kubernetes/kubelet << EOF 
# 启用日志标准错误
KUBE_LOGTOSTDERR="--logtostderr=true"
# 日志级别
KUBE_LOG_LEVEL="--v=4"
# Kubelet服务IP地址
NODE_ADDRESS="--address=$IPADDR_7"
# Kubelet服务端口
NODE_PORT="--port=10250"
# 自定义节点名称
NODE_HOSTNAME="--hostname-override=$IPADDR_7"
# kubeconfig路径，指定连接API服务器
KUBELET_KUBECONFIG="--kubeconfig=/etc/kubernetes/kubelet.kubeconfig"
# 允许容器请求特权模式，默认false
KUBE_ALLOW_PRIV="--allow-privileged=false"
# DNS信息
KUBELET_DNS_IP="--cluster-dns=10.10.10.2"
KUBELET_DNS_DOMAIN="--cluster-domain=cluster.local"
# 禁用使用Swap
KUBELET_SWAP="--fail-swap-on=false"
EOF

cat >/lib/systemd/system/kubelet.service<< EOF 
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=-/etc/kubernetes/kubelet
ExecStart=/usr/bin/kubelet \
\${KUBE_LOGTOSTDERR} \
\${KUBE_LOG_LEVEL} \
\${NODE_ADDRESS} \
\${NODE_PORT} \
\${NODE_HOSTNAME} \
\${KUBELET_KUBECONFIG} \
\${KUBE_ALLOW_PRIV} \
\${KUBELET_DNS_IP} \
\${KUBELET_DNS_DOMAIN} \
\${KUBELET_SWAP}
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet
systemctl restart kubelet
if [ $? -eq 0 ];then
	echo "===================================================="
	echo "          kubelet安装成功，请按任意键继续！！       "
	echo "===================================================="
	char=`get_char`
else
	echo "===================================================="
	echo "          kubelet安装失败，请按任意键退出！！       "
	echo "===================================================="
	char=`get_char`
	exit 1
fi

cat >/etc/kubernetes/kube-proxy<< EOF 
# 启用日志标准错误
KUBE_LOGTOSTDERR="--logtostderr=true"
# 日志级别
KUBE_LOG_LEVEL="--v=4"
# 自定义节点名称
NODE_HOSTNAME="--hostname-override=$IPADDR_7"
# API服务地址
KUBE_MASTER="--master=http://$IPADDR_MASTER:8080"
EOF

cat >/lib/systemd/system/kube-proxy.service<< EOF 
[Unit]
Description=Kubernetes Proxy
After=network.target

[Service]
EnvironmentFile=-/etc/kubernetes/kube-proxy
ExecStart=/usr/bin/kube-proxy \
\${KUBE_LOGTOSTDERR} \
\${KUBE_LOG_LEVEL} \
\${NODE_HOSTNAME} \
\${KUBE_MASTER}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-proxy
systemctl restart kube-proxy
if [ $? -eq 0 ];then
	echo "===================================================="
	echo "        kube-proxy安装成功，请按任意键继续！！      "
	echo "===================================================="
	char=`get_char`
else
	echo "===================================================="
	echo "        kube-proxy安装失败，请按任意键退出！！      "
	echo "===================================================="
	char=`get_char`
	exit 1
fi

echo "ps aux | grep kube"
flag=`ps aux | grep kube | grep -v grep | wc -l`
if [ $flag -eq 2 ];then
	echo "========================================================="
	echo "         slave节点安装完毕,请按任意键继续 ！！！！！     "
	echo "========================================================="
	char=`get_char`
else
	echo "========================================================="
	echo "         slave节点安装失败,请按任意键退出 ！！！！！     "
	echo "========================================================="
	char=`get_char`
	exit 1
fi
}

memu3(){
echo "安装docker依赖"
yum install -y yum-utils device-mapper-persistent-data lvm2
#官方安装（推荐）
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce
systemctl enable docker
systemctl start docker
if [ $? -eq 0 ];then
	echo "========================================================="
	echo "         docker-ce安装完毕,请按任意键继续 ！！！！！     "
	echo "========================================================="
	char=`get_char`
else
	echo "========================================================="
	echo "         docker-ce安装失败,请按任意键退出 ！！！！！     "
	echo "========================================================="
	char=`get_char`
	exit 1
fi
echo "添加国内加速器"
cat >/etc/docker/daemon.json << EOF
{
        "registry-mirrors": ["https://bxt6wamw.mirror.aliyuncs.com"]
}
EOF
}

#============================菜单栏=================================
while true
do
clear
echo "========================================"
echo "          Linux Optimization            "   
echo "========================================"
cat << EOF
|-----------System Infomation-----------
| DATE       :$DATE
| HOSTNAME   :$HOSTNAME
| USER       :$USER
| IP         :$IPADDR_7
| CPU Usage  :$cpuUsage_7
| CPU_AVERAGE:$cpu_uptime
| DISK_USED /:$DISK_SDA
| MEMORY  USE:$free_7
| RUNNING ENV:$sys_vresion_7
----------------------------------------
|****Please Enter Your Choice:[0-3]****|
----------------------------------------
(1) 一键安装Kubernetes群集_Master端
(2) 一键安装Kubernetes群集_slave端
(3) 一键安装docker容器服务
(0) 退出
EOF
#choice
read -p "Please enter your choice[0-3]: " input1
case "$input1" in
1)
  echo "+++++++++++++++开始时间：$DATE+++++++++++++++++" 2>&1 | tee -a /memu2.log
  memu1 2>&1 | tee -a /memu2.log
  echo "+++++++++++++++结束时间：$DATE+++++++++++++++++" 2>&1 | tee -a /memu2.log
  ;;
2)
  echo "+++++++++++++++开始时间：$DATE+++++++++++++++++" 2>&1 | tee -a /memu2.log
  memu2 2>&1 | tee -a /memu2.log
  echo "+++++++++++++++结束时间：$DATE+++++++++++++++++" 2>&1 | tee -a /memu2.log
  ;;
3)
  echo "+++++++++++++++开始时间：$DATE+++++++++++++++++" 2>&1 | tee -a /memu3.log
  memu3 2>&1 | tee -a /memu3.log
  echo "+++++++++++++++结束时间：$DATE+++++++++++++++++" 2>&1 | tee -a /memu3.log
  ;;
0)
  clear
  break
  ;;
*)
  echo "----------------------------------"
  echo "|          Warning!!!            |"
  echo "|   Please Enter Right Choice!   |"
  echo "----------------------------------"
  for i in `seq -w 3 -1 1`
      do
        echo -ne "\b\b$i";
        sleep 1;
      done
  clear
esac
done
