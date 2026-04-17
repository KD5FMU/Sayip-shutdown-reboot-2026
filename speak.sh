#!/bin/bash

NODE=576331
SOUND="/var/lib/asterisk/sounds/custom/test"   # test.ulaw located at /var/lib/asterisk/sounds/custom/test.ulaw

/usr/sbin/asterisk -rx "rpt localplay ${NODE} ${SOUND}"
