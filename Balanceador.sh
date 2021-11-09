#!/bin/bash

NET1=10.10.1.0/24
IF1=enp8s3
IP1=10.10.1.2
T1=T_ISP1
GW1=10.10.1.1
ISP1_T=3

NET2=10.10.2.0/24
IF2=enp7s0
IP2=10.10.2.2
T2=T_ISP2
GW2=10.10.2.1
ISP2_T=4

filename='pesos.txt'

while read line; do
eval export "$line"
done < $filename

PROB1=$(echo "scale=2; $ISP1 / ($ISP1 + $ISP2)" | bc)
PROB2=$(echo "scale=2; 1 - $PROB1" | bc)


ip route del default
ip rule add fwmark $ISP1_T table $T1 prio 33000
ip rule add fwmark $ISP2_T table $T2 prio 33000

ip route del $NET1 dev $IF1 src $IP1 table $T1
ip route del default via $GW1 table $T1
ip route del $NET2 dev $IF2 src $IP2 table $T2
ip route del default via $GW2 table $T2
ip route add $NET1 dev $IF1 src $IP1 table $T1
ip route add default via $GW1 table $T1
ip route add $NET2 dev $IF2 src $IP2 table $T2
ip route add default via $GW2 table $T2

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -F
iptables -t mangle -F

iptables -t mangle -A PREROUTING -j CONNMARK --restore-mark
iptables -t mangle -A PREROUTING -m mark ! --mark 0 -j ACCEPT
iptables -t mangle -A PREROUTING -j MARK --set-mark $ISP1_T
iptables -t mangle -A PREROUTING -m statistic --mode random --probability $PROB2 -j MARK --set-mark $ISP2_T
iptables -t mangle -A PREROUTING -j CONNMARK --save-mark

ip_balance(){

  while read -r line; do
    readarray -d , -t PARAMS <<< $line
    if [[ ${PARAMS[3]} == 'ISP1' ]]; then
      iptables -t nat -A POSTROUTING -s ${PARAMS[0]} -p ${PARAMS[2]} --dport ${PARAMS[1]} -o $IF1 -j MASQUERADE
      iptables -A FORWARD -s ${PARAMS[0]} -p tcp --dport ${PARAMS} -j ACCEPT
    elif [[ ${PARAMS[3]} == 'ISP2' ]]; then
      iptables -t nat -A POSTROUTING -s ${PARAMS[0]} -p ${PARAMS[2]} --dport ${PARAMS[1]} -o $IF2 -j MASQUERADE
    else
      iptables -t nat -A POSTROUTING -s ${PARAMS[0]} -p ${PARAMS[2]} --dport ${PARAMS[1]} -j MASQUERADE
    fi
  done < 'LBrules.txt'
}


echo "1" > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -j MASQUERADE


