#!/bin/sh

# Script to speak letters and numbers from Asterisk sounds
# over a radio node using simpleusb
# by Ramon Gonzalez KP4TR 2014
# Modified to work with ASL3 by Jory Pratt W5GLE 2024

ASTSND=/usr/share/asterisk/sounds/en
LOCALSND=/tmp/localmsg

speak() {
    SPEAKTEXT=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    SPEAKLEN=$(echo "$SPEAKTEXT" | wc -m)
    SPEAKLEN=$(expr "$SPEAKLEN" - 1)
    COUNTER=0
    rm -f "${LOCALSND}.ulaw"
    touch "${LOCALSND}.ulaw"

    while [ "$COUNTER" -lt "$SPEAKLEN" ]; do
        COUNTER=$(expr "$COUNTER" + 1)
        CH=$(echo "$SPEAKTEXT" | cut -c"$COUNTER")

        case "$CH" in
            [A-Za-z_])
                cat "${ASTSND}/letters/${CH}.ulaw" >> "${LOCALSND}.ulaw"
                ;;
            [0-9])
                cat "${ASTSND}/digits/${CH}.ulaw" >> "${LOCALSND}.ulaw"
                ;;
            .)
                cat "${ASTSND}/letters/dot.ulaw" >> "${LOCALSND}.ulaw"
                ;;
            -)
                cat "${ASTSND}/letters/dash.ulaw" >> "${LOCALSND}.ulaw"
                ;;
            =)
                cat "${ASTSND}/letters/equals.ulaw" >> "${LOCALSND}.ulaw"
                ;;
            /)
                cat "${ASTSND}/letters/slash.ulaw" >> "${LOCALSND}.ulaw"
                ;;
            "!")
                cat "${ASTSND}/letters/exclaimation-point.ulaw" >> "${LOCALSND}.ulaw"
                ;;
            "@")
                cat "${ASTSND}/letters/at.ulaw" >> "${LOCALSND}.ulaw"
                ;;
            "$")
                cat "${ASTSND}/letters/dollar.ulaw" >> "${LOCALSND}.ulaw"
                ;;
        esac
    done

    asterisk -rx "rpt localplay $2 ${LOCALSND}"
}

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: speaktext.sh \"abc123\" node#"
    exit 1
fi

speak "$1" "$2"

sleep 3
rm -f "${LOCALSND}.ulaw"
