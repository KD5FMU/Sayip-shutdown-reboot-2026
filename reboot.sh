#!/bin/sh

# Notify via voice and reboot the system 

if [ ! -z "$1" ]; then
    asterisk -rx "rpt localplay $1 /etc/asterisk/local/reboot"
    sleep 20
fi

/usr/sbin/reboot

