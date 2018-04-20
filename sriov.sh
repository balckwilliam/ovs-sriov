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
	sleep 1
	docker run -itd --privileged=true --net=none --name=$iptables_sriov 6d6fd32fa013 /bin/bash
	sleep 1
	#pipework $br -i eth0 $iptables_br $ip/24'@'$getway
	pipework --direct-phys $netcard_name1 -i eth0 $iptables_sriov $ip/24
	sleep 1
	#pipework $br -i eth1 $iptables_br $ip2/24'@'$getway
	pipework --direct-phys $netcard_name2 -i eth1 $iptables_sriov $ip2/24
	sleep 1
	docker exec -it $iptables_sriov iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j DNAT --to $next_ip:80
	sleep 1
	docker exec -it $iptables_sriov iptables -t nat -A POSTROUTING -j MASQUERADE -o eth1
}
haproxy_run(){
	sleep 1
	haproxy_name=$1
	current_ip=$2
	haproxy_next_ip1=$3
	haproxy_next_ip2=$4
	haproxy_netcardname=$5
	docker run -itd --privileged=true --net=none --name=$haproxy_name b4c08bf3a3aa /bin/bash
	pipework --direct-phys $haproxy_netcardname -i eth0 $haproxy_name $current_ip/24
	#pipework br1 -i eth1 $haproxy_name $current_ip/24'@'$haproxy_getway
	haproxycfg $current_ip $haproxy_next_ip1 $haproxy_next_ip2
	docker cp /haproxy_test/haproxy.cfg $haproxy_name:/root/
	docker exec -it $haproxy_name haproxy -f /root/haproxy.cfg  
}
apache_run(){
	sleep 1
	apache2_name=$1
	apache2_ip=$2
	apache_netcardname=$3
	docker run -itd --privileged=true --net=none --name=$apache2_name 42468c9f6ce6 /bin/bash
	#pipework br1 -i eth0 $apache2_name $apache2_ip/24'@'$apache_getway
	pipework --direct-phys $apache_netcardname -i eth0 $apache2_name $apache2_ip/24
	docker exec -it $apache2_name /etc/init.d/apache2 start
}

# muti_haproxy_run(){
	# a=$1
	# haproxy_muti_getway=$2
	# for((i=a;i<19;i++)){
		# ((temp=i+2))
		# haproxy_run haproxys"$i"_sriov 192.168.2.$i 192.168.2.$temp 192.168.2.$temp $2
		# sleep 1
	# }
# }
#haproxy_run haproxy_name current_ip haproxy_next_ip1 haproxy_next_ip2 haproxy_netcardname
#iptablescfg iptables_sriov ip ip2 next_ip netcard_name1 netcard_name2
#apache_run apache2_name apache2_ip apache_netcardname 
#
on_start(){

	iptablescfg iptables_sriov 192.168.1.3 10.0.0.2 10.0.0.3 enp9s16 enp9s17
	haproxy_run haproxy_sriov3 10.0.0.3 10.0.0.4 10.0.0.5 enp9s18
	
	haproxy_run haproxy_sriov4 10.0.0.4 10.0.0.6 10.0.0.6 enp9s19
	haproxy_run haproxy_sriov5 10.0.0.5 10.0.0.7 10.0.0.7 enp9s20
	haproxy_run haproxy_sriov6 10.0.0.6 10.0.0.8 10.0.0.8 enp9s21
	haproxy_run haproxy_sriov7 10.0.0.7 10.0.0.9 10.0.0.9 enp9s16f2
	haproxy_run haproxy_sriov8 10.0.0.8 10.0.0.10 10.0.0.10 enp9s16f4
	haproxy_run haproxy_sriov9 10.0.0.9 10.0.0.11 10.0.0.11 enp9s16f6
	haproxy_run haproxy_sriov10 10.0.0.10 10.0.0.12 10.0.0.12 enp9s17f2
	haproxy_run haproxy_sriov11 10.0.0.11 10.0.0.13 10.0.0.13 enp9s17f4
	haproxy_run haproxy_sriov12 10.0.0.12 10.0.0.14 10.0.0.14 enp9s17f6
	haproxy_run haproxy_sriov13 10.0.0.13 10.0.0.15 10.0.0.15 enp9s18f2
	haproxy_run haproxy_sriov14 10.0.0.14 10.0.0.16 10.0.0.16 enp9s18f4
	haproxy_run haproxy_sriov15 10.0.0.15 10.0.0.17 10.0.0.17 enp9s18f6
	haproxy_run haproxy_sriov16 10.0.0.16 10.0.0.18 10.0.0.18 enp9s19f2
	haproxy_run haproxy_sriov17 10.0.0.17 10.0.0.19 10.0.0.19 enp9s19f6
	#enp9s21f2
	haproxy_run haproxy_sriov18 10.0.0.18 10.0.0.20 10.0.0.20 enp9s20f2
	haproxy_run haproxy_sriov19 10.0.0.19 10.0.0.21 10.0.0.21 enp9s21f2
	
	apache_run apaches21_sriov1 10.0.0.20 enp9s20f4
	apache_run apaches22_sriov2 10.0.0.21 enp9s20f6
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
