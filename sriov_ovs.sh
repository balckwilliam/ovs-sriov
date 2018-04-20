#!bin/sh
#pipework br1 -i eth0 test1 192.168.2.2/24
haproxycfg() { 
	sleep 1
	rm -rf /haproxy_test
	mkdir /haproxy_test
	echo "输入的参数个数为: $#" #“$#”会显示传给该函数的参数个数	
	echo "所有参数为: $@" #“$@”会显示所有传给函数的参数	
	echo "$1: $1"  
	echo "$2: $2"  
	echo "$3: $3" 
	native_ip=$1
	next_ip1=$2
	next_ip2=$3
	echo "
#---------------------------------------------------------------------
# Example configuration for a possible web application.	 See the
# full configuration options online.
#
#	http://haproxy.1wt.eu/download/1.4/doc/configuration.txt
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
	# to have these messages end up in /var/log/haproxy.log you will
	# need to:
	#
	# 1) configure syslog to accept network log events.	 This is done
	#	 by adding the '-r' option to the SYSLOGD_OPTIONS in
	#	 /etc/sysconfig/syslog
	#
	# 2) configure local2 events to go to the /var/log/haproxy.log
	#	file. A line like the following can be added to
	#	/etc/sysconfig/syslog
	#
	#	 local2.*						/var/log/haproxy.log
	#
	log			127.0.0.1 local2

	chroot		/var/lib/haproxy
	pidfile		/var/run/haproxy.pid
	maxconn		1000000
	user		haproxy
	group		haproxy
	daemon

	# turn on stats unix socket
	stats socket /var/lib/haproxy/stats

#---------------------------------------------------------------------
# main frontend which proxys to the backends
#---------------------------------------------------------------------
frontend haproxy $native_ip:80
	mode			tcp
	log				global
	option			tcplog
	timeout client		3600s
	backlog			4096
	maxconn			1000000
	default_backend		sink

#---------------------------------------------------------------------
# round robin balancing between the various backends
#---------------------------------------------------------------------
backend sink
	balance		roundrobin
	mode  tcp
	option log-health-checks
	option redispatch
	option tcplog
	server	 app1 $next_ip1
	server	 app2 $next_ip2
	#server	 app1 172.88.0.4:80
#	 server	 app1 172.18.60.100:50001
#	 server	 app2 173.168.100.7:50002
#	 server	 app3 173.168.100.7:50003
#	 server	 app4 173.168.100.7:50004
	timeout connect 1s
	timeout queue 5s
	timeout server 3600s
">>/haproxy_test/haproxy.cfg
}
iptablescfg(){
	sleep 1
	#br=$1
	iptables_sriov=$1
	ip=$2
	ip2=$3
	next_ip=$4
	netcard_name1=$5
	netcard_name2=$6
	ip3=$7
	sleep 1
	docker run -itd --privileged=true --net=none --name=$iptables_sriov 6d6fd32fa013 /bin/bash
	sleep 1
	#pipework $br -i eth0 $iptables_br $ip/24'@'$getway
	pipework --direct-phys $netcard_name1 -i eth0 $iptables_sriov $ip/24
	sleep 1
	ovs-docker add-port br0 eth1 $iptables_sriov --ipaddress=$ip2/24
	#pipework $br -i eth1 $iptables_br $ip2/24'@'$getway
	pipework --direct-phys $netcard_name2 -i eth2 $iptables_sriov $ip3/24
	sleep 1
	docker exec -it $iptables_sriov iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j DNAT --to $next_ip:80
	sleep 1
	docker exec -it $iptables_sriov iptables -t nat -A POSTROUTING -j MASQUERADE -o eth1
}
haproxy_run(){
	sleep 1
	haproxy_name=$1
	sriov_ip=$2
	haproxy_next_ip1=$3
	haproxy_next_ip2=$4
	haproxy_netcardname=$5
	ovs_briage=$6
	#ovs_netcard=$7
	ovs_address=$7
	docker run -itd --privileged=true --net=none --name=$haproxy_name 878f003a137e /bin/bash
	pipework --direct-phys $haproxy_netcardname -i eth0 $haproxy_name $sriov_ip/24
	add_ovs_switch $ovs_briage eth1 $haproxy_name $ovs_address
	sleep 1
	docker exec -it $haproxy_name iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j DNAT --to $haproxy_next_ip1:80
	sleep 1
	docker exec -it $haproxy_name iptables -t nat -A POSTROUTING -j MASQUERADE -o eth1
	#docker exec -it $haproxy_name ip route add 192.168.1.0/24 via $sriov_ip
	haproxycfg $ovs_address $haproxy_next_ip1 $haproxy_next_ip2
	docker cp /haproxy_test/haproxy.cfg $haproxy_name:/root/
	docker exec -it $haproxy_name haproxy -f /root/haproxy.cfg  >/dev/null
}
apache_run(){
	sleep 1
	apache2_name=$1
	apache2_ip=$2
	apache_netcardname=$3
	apache_ovs_brige=$4
	apache_ovs_ip=$5
	docker run -itd --privileged=true --net=none --name=$apache2_name 42468c9f6ce6 /bin/bash
	pipework --direct-phys $apache_netcardname -i eth0 $apache2_name $apache2_ip/24
	ovs-docker add-port $apache_ovs_brige eth1 $apache2_name --ipaddress=$apache_ovs_ip/24
	docker exec -it $apache2_name /etc/init.d/apache2 start >/dev/null
	#docker exec -it $apache2_name ip route add 192.168.1.0/24 via $apache2_ip
}
add_ovs_switch(){
	sleep 1
	ovs_briage=$1
	docker_netcard=$2
	docker_name=$3
	docker_ipaddress=$4
	ovs-docker add-port $ovs_briage $docker_netcard $docker_name --ipaddress=$docker_ipaddress/24
	#ovs-docker add-port br0 eth0 haproxy --ipaddress=192.168.30.2/24
}

haproxy_run_ovs(){
	sleep 1
	haproxy_name=$1
	current_ip=$2
	haproxy_next_ip1=$3
	haproxy_next_ip2=$4
	ovs_briage=$5
	netcardname=$6
	ip_sriov=$7
	docker run -itd --privileged=true --net=none --name=$haproxy_name 878f003a137e /bin/bash
	ovs-docker add-port $ovs_briage eth0 $haproxy_name --ipaddress=$current_ip/24
	pipework --direct-phys $netcardname -i eth1 $haproxy_name $ip_sriov/24
	haproxycfg $current_ip $haproxy_next_ip1 $haproxy_next_ip2
	docker cp /haproxy_test/haproxy.cfg $haproxy_name:/root/
	docker exec -it $haproxy_name haproxy -f /root/haproxy.cfg  >/dev/null
	#docker exec -it $haproxy_name ip route add 192.168.1.0/24 via $ip_sriov
}
on_start(){
	#ip route add 192.168.1.0/24 via 10.0.0.3
	#enp9s19f6
	iptablescfg iptables_sriov 192.168.1.3 172.17.1.2 172.17.1.3 enp9s21f6 enp9s22 192.168.1.21
	haproxy_run_ovs haproxy_sriov3 172.17.1.3 172.17.1.4 172.17.1.5 br0 enp9s27f6 192.168.1.22
	haproxy_run haproxy_sriov4 192.168.1.23 172.17.1.6 172.17.1.6 enp9s28 br0 172.17.1.4
	haproxy_run haproxy_sriov5 192.168.1.24 172.17.1.6 172.17.1.6 enp9s28f2 br0 172.17.1.4
	haproxy_run haproxy_sriov6 192.168.1.25 172.17.1.7 172.17.1.7 enp9s28f4 br0 172.17.1.5
	haproxy_run haproxy_sriov7 192.168.1.26 172.17.1.8 172.17.1.8 enp9s28f6 br0 172.17.1.6
	haproxy_run haproxy_sriov8 192.168.1.27 172.17.1.9 172.17.1.9 enp9s29 br0 172.17.1.7
	haproxy_run haproxy_sriov9 192.168.1.28 172.17.1.10 172.17.1.10 enp9s29f2 br0 172.17.1.8
	haproxy_run haproxy_sriov10 192.168.1.29 172.17.1.11 172.17.1.11 enp9s29f4 br0 172.17.1.9
	haproxy_run haproxy_sriov11 192.168.1.30 172.17.1.12 172.17.1.12 enp9s29f6 br0 172.17.1.10
	haproxy_run haproxy_sriov12 192.168.1.31 172.17.1.13 172.17.1.13 enp9s30 br0 172.17.1.11
	haproxy_run haproxy_sriov13 192.168.1.32 172.17.1.14 172.17.1.14 enp9s30f2 br0 172.17.1.12
	haproxy_run haproxy_sriov14 192.168.1.33 172.17.1.15 172.17.1.15 enp9s30f4 br0 172.17.1.13
	haproxy_run haproxy_sriov15 192.168.1.34 172.17.1.16 172.17.1.16 enp9s30f6 br0 172.17.1.14
	haproxy_run haproxy_sriov16 192.168.1.35 172.17.1.17 172.17.1.17 enp9s16 br0 172.17.1.15
	haproxy_run haproxy_sriov17 192.168.1.36 172.17.1.18 172.17.1.18 enp9s16f4 br0 172.17.1.16
	haproxy_run haproxy_sriov18 192.168.1.37 172.17.1.19 172.17.1.19 enp9s16f6 br0 172.17.1.17
	haproxy_run haproxy_sriov19 192.168.1.38 172.17.1.20 172.17.1.20 enp9s17 br0 172.17.1.18
	haproxy_run haproxy_sriov20 192.168.1.39 172.17.1.21 172.17.1.21 enp9s17f2 br0 172.17.1.19
	apache_run apaches21_sriov1 192.168.1.40 enp9s17f4 br0 172.17.1.20
	apache_run apaches22_sriov2 192.168.1.41 enp9s17f6 br0 172.17.1.21
	
	#haproxy_run haproxy_sriov3 10.0.0.3 10.0.0.4 10.0.0.5 enp9s18
	# haproxy_run haproxy_sriov4 10.0.0.4 10.0.0.6 10.0.0.6 enp9s19
	# haproxy_run haproxy_sriov5 10.0.0.5 10.0.0.7 10.0.0.7 enp9s20
	# haproxy_run haproxy_sriov6 10.0.0.6 10.0.0.8 10.0.0.8 enp9s21
	# haproxy_run haproxy_sriov7 10.0.0.7 10.0.0.9 10.0.0.9 enp9s16f2
	# haproxy_run haproxy_sriov8 10.0.0.8 10.0.0.10 10.0.0.10 enp9s16f4
	# haproxy_run haproxy_sriov9 10.0.0.9 10.0.0.11 10.0.0.11 enp9s16f6
	# haproxy_run haproxy_sriov10 10.0.0.10 10.0.0.12 10.0.0.12 enp9s17f2
	# haproxy_run haproxy_sriov11 10.0.0.11 10.0.0.13 10.0.0.13 enp9s17f4
	# haproxy_run haproxy_sriov12 10.0.0.12 10.0.0.14 10.0.0.14 enp9s17f6
	# haproxy_run haproxy_sriov13 10.0.0.13 10.0.0.15 10.0.0.15 enp9s18f2
	# haproxy_run haproxy_sriov14 10.0.0.14 10.0.0.16 10.0.0.16 enp9s18f4
	# haproxy_run haproxy_sriov15 10.0.0.15 10.0.0.17 10.0.0.17 enp9s18f6
	# haproxy_run haproxy_sriov16 10.0.0.16 10.0.0.18 10.0.0.18 enp9s19f2
	# haproxy_run haproxy_sriov17 10.0.0.17 10.0.0.19 10.0.0.19 enp9s19f6
	#enp9s21f2
	# haproxy_run haproxy_sriov18 10.0.0.18 10.0.0.20 10.0.0.20 enp9s20f2
	# haproxy_run haproxy_sriov19 10.0.0.19 10.0.0.21 10.0.0.21 enp9s21f2
	
	
}
on_start
#iptables
# enp9s16: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s17: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
#haproxy
# enp9s18: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s19: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s20: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s21: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s16f2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s16f4: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s16f6: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s17f2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s17f4: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s17f6: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s18f2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s18f4: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s18f6: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s19f2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s19f4: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s19f6: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s20f2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
#apache
# enp9s20f4: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s20f6: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s21f2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
# enp9s21f4: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
