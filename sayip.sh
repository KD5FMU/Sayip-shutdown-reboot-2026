#!/bin/sh
#
# sayip.sh  <node> <interface>
# Say local IP address
# Node is required
# Call from command line or DTMF function
# WA3DSP 8/2014
# $Id: sayip.sh 22 2016-01-30 02:07:39Z w0anm $
#
# ---------------
# Copyright (C) 2015, 2016 Doug Crompton, WA3DSP
#
# Modified to say IP of all found interfaces. KB4FXC 06/20/2017
# Modified to work with ASL3. W5GLE 11/15/2024
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see http://www.gnu.org/licenses/.
# ---------------

if [ -z "$1" ]; then
    echo "No node number supplied - sayip.sh <node>"
    exit 1
fi

asterisk -rx "rpt localplay $1 /etc/asterisk/local/ip-address"

for i in $(ip link show | grep " UP " | grep -v lo | grep -v "link/ether" | awk '{print $2}' | sed -e 's/://g'); do
    DEVICE="$i"
    ip=$(ip addr show "$DEVICE" | awk '/inet / {print $2}' | awk 'BEGIN { FS = "/" } {print $1}')
    /usr/bin/sleep 5
    /etc/asterisk/local/speaktext.sh "$ip" "$1"
done
