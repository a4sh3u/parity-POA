#!/bin/bash

apt-get install software-properties-common
add-apt-repository -y ppa:ethereum/ethereum
apt-get update
apt-get install bootnode ntpdate
ntpdate -s time.nist.gov # to sysnc the time

mypublicip="$(dig +short myip.opendns.com @resolver1.opendns.com)"
bootnode -genkey bootnode.key
bootnode -nat "extip:${mypublicip}" -nodekey bootnode.key -v5 -verbosity 9 >/var/log/bootnode.log 2>&1 &
