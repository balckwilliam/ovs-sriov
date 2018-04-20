#!/bin/sh
function check_ip() {
    local IP=$1
    VALID_CHECK=$(echo $IP|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $IP|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >/dev/null; then
        if [ $VALID_CHECK == "yes" ]; then
         echo "IP $IP  available!"
            return 0
        else
            echo "IP $IP 不可用!"
            return 1
        fi
    else
        echo "IP 格式错误!"
        return 1
    fi
}
echo "请选择序号"
echo "1.安装docker"
echo "2.安装openvswitch"
echo "3.安装dpdk"
echo "4.安装netperf"
echo "5.启动netperf服务端,请先安装netperf"
echo "6.启动netperf客户端,请先安装netperf"
echo "7.下载docker gns3/openvswitch镜像,请先安装docker"
echo "8.下载docker centos:7.4.1708镜像,请先安装docker"
echo "9.更改net.ipv4.ip_forward=1设置"
echo "10.开启docker服务"
echo "11.更换4.14内核"
echo "12.docker与openvswitch结合"
echo "13.安装ipconfig(在docker里使用)"
echo "14.安装ssh(在docker里使用)"
echo "请输入序号"
read _select
case $_select in
	1) echo "安装docker..."
	yum install docker
	service docker start
	chkconfig docker on
	;;
	2) echo "安装openvswitch..."
	yum -y install openssl-devel wget kernel-devel
	yum groupinstall "Development Tools"
	wget http://openvswitch.org/releases/openvswitch-2.5.1.tar.gz
	tar xfz openvswitch-2.5.1.tar.gz
	mkdir -p ~/rpmbuild/SOURCES
	sed 's/openvswitch-kmod, //g' openvswitch-2.5.1/rhel/openvswitch.spec >openvswitch-2.5.1/rhel/openvswitch_no_kmod.spec
	cp openvswitch-2.5.1.tar.gz rpmbuild/SOURCES
	rpmbuild -bb --without=check ~/openvswitch-2.5.1/rhel/openvswitch_no_kmod.spec
	cd ~
	yum localinstall ./rpmbuild/RPMS/x86_64/openvswitch-2.5.1-1.x86_64.rpm
	systemctl start openvswitch.service
	systemctl -l status openvswitch.service
	;;
	3) echo "安装dpdk..."
	yum install make gcc libpcap libpcap-devel -y
	yum install numactl-devel
	sudo yum install e2fsprogs-devel
	sudo yum install uuid-devel
	sudo yum install libuuid-devel
	sudo yum install ibaio-devel
	wget https://fast.dpdk.org/rel/dpdk-17.11.tar.xz
	tar xf dpdk-17.11.tar.xz
	cd dpdk-17.11/
	yum info kernel-devel
	uname -r
	echo "查看系统版本(任意键继续 ctrl+c结束)"
	read _ena
	echo "更换为kernel-devel-3.10.0-693.11.1.el7.x86_64吗?(ctrl+c退出，任意键继续)"
	read _ena
	wget http://www.rpmfind.net/linux/centos/7.4.1708/updates/x86_64/Packages/kernel-devel-3.10.0-693.11.1.el7.x86_64.rpm
	rpm -Uvh --oldpackage kernel-devel-3.10.0-693.11.1.el7.x86_64.rpm
	ln -fs /usr/src/kernels/3.10.0-693.11.1.el7.x86_64/ /lib/modules/3.10.0-693.el7.x86_64/build
	cd ~
	cd dpdk-17.11
	make config T=x86_64-native-linuxapp-gcc
	sed -ri 's,(PMD_PCAP=).*,\1y,' build/.config
	make
	cd ~
	cd dpdk-17.11
	make -C examples RTE_SDK=$(pwd) RTE_TARGET=build O=$(pwd)/build/examples
	echo "dpdka安装完成！生成的testpmd在 build/app里，生成的examples在build里"
	;;
	4) echo "安装netperf..."
	yum install gcc 
	yum install wget
	wget repo.iotti.biz/CentOS/7/x86_64/netperf-2.7.0-1.el7.lux.x86_64.rpm
	rpm -Uvh netperf-2.7.0-1.el7.lux.x86_64.rpm
	yum install netperf
	echo "netperf安装完成"
	;;
	5) echo "启动netperf服务端"
	netserver -D -p 8888
	echo "启动成功，端口为8888"
	;;
	6) echo "启动netperf客户端"
	echo "netperf -H 服务端ip -p 端口 -l 测试时间"
	;;
	7) echo "docker pull gns3/openvswitch镜像"
	docker pull gns3/openvswitch
	echo "ns3/openvswitch镜像下载完成，请使用docker run -ti ID /bin/bash运行"
	;;
	8) echo "docker pull centos:7.4.1708"
	docker pull centos:7.4.1708
	docker images
	echo "centos7.4下载完成，请使用docker run -ti ID /bin/bash运行"
	;;
	9) echo "添加代码：net.ipv4.ip_forward=1中"
	echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
	echo "重启network服务中"
	systemctl restart network
	echo "如果返回为“net.ipv4.ip_forward = 1”则表示成功了,请查看是否为1"
	sysctl net.ipv4.ip_forward
	echo "修改完成"
	;;
	10) echo "开启docker服务"
	service docker start
	echo "开启成功"
	;;
	11) echo "开始更换内核"
	echo "请查看内核版本(以任意键继续,以ctrl+c结束)"
	uname -r
	read _uname
	rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
	yum --enablerepo=elrepo-kernel install  kernel-ml-devel kernel-ml
	echo "请查看启动顺序，以ctrl+c结束"
	awk -F\' '$1=="menuentry " {print $2}' /etc/grub2.cfg
	echo "任意键继续"
	read _grup
	echo "请输入启动顺序，以0开始"
	read _set_1
	echo "您输入的启动顺序是{$_set_1},继续吗？(y/n)"
	read _set_2
	case $_set_2 in
	    [yY][eE][sS]|[yY])
			echo "Yes"
			grub2-set-default $_set_1
			echo "是否重启？(Y/N)"
			read _reboot
			case $_reboot in 
				[yY][eE][sS]|[yY])
					echo "重启中...(重启后请输入uname -r查看内核，并且输入yum remove kernel删除旧内核)"
					reboot;;
				[nN][oO]|[nN])
					echo "No"
					echo "请输入reboot命令重启机器，即可更换成功"
					echo "(重启后请输入uname -r查看内核，并且输入yum remove kernel删除旧内核)"
					;;
				esac
			;;
	    [nN][oO]|[nN])
			echo "No"
			echo "启动顺序未更改"
	       		;;
	    *)
		echo "Invalid input..."
		;;
	esac
	;;
	12) 
	cd ~
	rm ./dockernet.sh
	yum install git
	git clone https://github.com/jpetazzo/pipework
	cp ~/pipework/pipework /usr/local/bin/
	echo "请输入新增网卡名称"
	read _br0
	echo "增加{$_br0}"
	ovs-vsctl add-br $_br0
	ifconfig
	echo "请输入要配置的网卡名称"
	read _enp9s0
	ovs-vsctl add-port $_br0 $_enp9s0
	ifconfig $_enp9s0 0.0.0.0
	echo "请输入要配置的ip地址"
	while true; do
		read _enp9s0_ip
		check_ip $_enp9s0_ip
		[ $? -eq 0 ] && break
	done
	ifconfig $_br0 $_enp9s0_ip netmask 255.255.0.0 broadcast 0.0.0.0
	echo "停止docker服务"
	service docker stop
	echo "删除docker0网卡"
	ip link set dev docker0 down
	brctl delbr docker0
	sed -i 's/--selinux-enabled --log-driver=journald --signature-verification=false/--selinux-enabled -b=$_br0' /etc/sysconfig/docker -i
	echo "启动docker服务"
	service docker start
	docker images
	echo "输入docker镜像id，没有的请先下载镜像"
	read _docker_id
	echo "输入docker name，不能重复"
	read _docker_name
	docker run -itd --net=none --name=$_docker_name $_docker_id /bin/bash
	ifconfig
	echo "请输入要配置的docker的ip地址[注:必须与之前$_br0的ip地址一个网段]"
	while true; do
		read _docker_ip
		check_ip $_docker_ip
		[ $? -eq 0 ] && break
	done
	pipework $_br0 $_docker_name $_docker_ip/24@$_enp9s0_ip
	docker attach $_docker_name
	echo "#\!/bin/bash" >> ./dockernet.sh
	echo "ip link set dev docker0 down"
	echo "brctl delbr docker0"
	echo "ovs-vsctl add-br $_br0">> ./dockernet.sh
	echo "ovs-vsctl add-port $_br0 $_enp9s0">> ./dockernet.sh
	echo "ifconfig $_enp9s0 0.0.0.0">> ./dockernet.sh
	echo "ifconfig $_br0 $_enp9s0_ip netmask 255.255.0.0 broadcast 0.0.0.0">> ./dockernet.sh
	echo "docker ps -a">> ./dockernet.sh
	echo "echo \"请输入docker name\"">> ./dockernet.sh
	echo "read _docker_1_name">> ./dockernet.sh
	echo "docker images">> ./dockernet.sh
	echo "echo \"请输入docker id\"">> ./dockernet.sh
	echo "read _docker_1_id">> ./dockernet.sh
	echo "docker run -itd --net=none --name=\$_docker_1_name \$_docker_1_id /bin/bash">> ./dockernet.sh
	echo "pipework $_br0 \$_docker_1_name $_docker_ip/24@$_enp9s0_ip">> ./dockernet.sh
	echo "docker attach \$_docker_1_name">> ./dockernet.sh
	;;
	13)echo "正在安装net-tools" 
	yum search ifconfig  
	yum install net-tools.x86_64 
	;;
	14) echo "正在安装ssh"
	yum install passwd openssl openssh-server -y
	ssh-keygen -q -t rsa -b 2048 -f /etc/ssh/ssh_host_rsa_key -N ''  
	ssh-keygen -q -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ''
	ssh-keygen -t dsa -f /etc/ssh/ssh_host_ed25519_key  -N ''
	passwd root
	sed -i 's/#Port 22/Port 23' /etc/ssh/sshd_config  -i
	cd ~
	echo "#\!/bin/bash" >> ./ssh.sh
	echo "/usr/sbin/sshd -D" >> ./ssh.sh
	chmod +x ./ssh.sh
	;;
	esac