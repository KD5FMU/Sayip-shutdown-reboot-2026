#!/bin/sh

# Notify via voice and halt the system

if [ ! -z "$1" ]; then
    asterisk -rx "rpt localplay $1 /etc/asterisk/local/halt"
    sleep 20
fi

/usr/sbin/poweroff
