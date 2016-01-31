#!/bin/bash
. /opt/farm/scripts/functions.custom

path="/etc/local/.config"

if [ "$1" = "" ]; then
	echo "usage: $0 <hostname[:port]>"
	exit 1
elif ! [[ $1 =~ ^[a-z0-9.-]+[.][a-z0-9]+([:][0-9]+)?$ ]]; then
	echo "error: parameter $1 not conforming hostname format"
	exit 1
fi

server=$1
if [ -z "${server##*:*}" ]; then
	host="${server%:*}"
	port="${server##*:}"
else
	host=$server
	port=22
fi

if [ "`getent hosts $host`" = "" ]; then
	echo "error: host $host not found"
	exit 1
elif [ "`cat $path/*.hosts |grep \"^$host$\"`" != "" ]; then
	echo "error: host $host already added"
	exit 1
fi

sshkey=`ssh_management_key_storage_filename $host`
ssh -i $sshkey -p $port -o StrictHostKeyChecking=no -o PasswordAuthentication=no root@$host uptime >/dev/null 2>/dev/null

if [[ $? != 0 ]]; then
	echo "error: host $server denied access"
	exit 1
fi

/opt/sf-farm-manager/add-dedicated-key.sh $server root
/opt/sf-farm-manager/add-dedicated-key.sh $server backup

if [ -x /opt/sf-backup-collector/add-backup-host.sh ]; then
	/opt/sf-backup-collector/add-backup-host.sh $server
fi

hwtype=`ssh -i $sshkey -p $port root@$host /opt/farm/scripts/config/detect-hardware-type.sh`
openvz=`ssh -i $sshkey -p $port root@$host "cat /proc/vz/version 2>/dev/null"`
netmgr=`ssh -i $sshkey -p $port root@$host "ls /etc/NetworkManager 2>/dev/null"`

if [ "$netmgr" != "" ]; then
	echo $server >>"$path/workstation.hosts"
elif [ $hwtype = "physical" ]; then
	echo $server >>"$path/physical.hosts"
elif [ $hwtype = "guest" ]; then
	echo $server >>"$path/virtual.hosts"
fi

if [ "$openvz" != "" ]; then
	echo $server >>"$path/openvz.hosts"
fi

# TODO: implement checking, if added host runs also Xen / LXC / Docker containers
