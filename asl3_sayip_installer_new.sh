#!/bin/bash

# ASL3 SayIP / Public IP / Reboot / Halt installer
# Corrected and hardened for Debian / AllStarLink 3

set -u

# ----- Settings -----
CONF_FILE="/etc/asterisk/rpt.conf"
TARGET_DIR="/etc/asterisk/local"
SERVICE_FILE="/etc/systemd/system/allstar-sayip.service"
BASE_URL="https://raw.githubusercontent.com/KD5FMU/Sayip-shutdown-reboot-2026/main"

# Added speaktext.sh because public-IP handling may depend on it
FILES_TO_DOWNLOAD=(
  "halt.pl"
  "reboot.pl"
  "sayip.pl"
  "saypublicip.pl"
  "speaktext.pl"
  "speaktext.sh"
  "halt.ulaw"
  "reboot.ulaw"
  "ip-address.ulaw"
  "public-ip-address.ulaw"
)

# ----- Functions -----
die() {
    echo "ERROR: $1" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

insert_function_if_missing() {
    local key="$1"
    local line="$2"

    if grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$CONF_FILE"; then
        echo "Function ${key} already exists in $CONF_FILE, leaving it unchanged."
    else
        echo "Adding ${key} to [functions] in $CONF_FILE ..."
        sed -i "/^\[functions\]/a ${line}" "$CONF_FILE" || die "Failed to insert ${key} into $CONF_FILE"
    fi
}

reload_asterisk() {
    if command -v asterisk >/dev/null 2>&1; then
        echo "Reloading Asterisk dialplan/app_rpt..."
        asterisk -rx "rpt reload" >/dev/null 2>&1 || true
        asterisk -rx "dialplan reload" >/dev/null 2>&1 || true
        asterisk -rx "module reload app_rpt.so" >/dev/null 2>&1 || true
    fi

    if systemctl is-active --quiet asterisk; then
        echo "Asterisk service is active."
    else
        echo "Warning: Asterisk service does not appear to be active right now."
    fi
}

# ----- Preflight -----
if [ "$(id -u)" -ne 0 ]; then
    die "This script must be run as root or with sudo."
fi

if [ "$#" -ne 1 ]; then
    die "Usage: $0 <NodeNumber>"
fi

NODE_NUMBER="$1"

echo "$NODE_NUMBER" | grep -Eq '^[0-9]+$' || die "NodeNumber must be numeric."

[ -f "$CONF_FILE" ] || die "Config file not found: $CONF_FILE"

need_cmd apt-get
need_cmd curl
need_cmd sed
need_cmd grep
need_cmd systemctl
need_cmd chown
need_cmd chmod
need_cmd mkdir

# ----- Install dependencies -----
echo "Updating package lists..."
apt-get update || die "apt-get update failed."

echo "Installing required packages..."
apt-get install -y curl libnet-ifconfig-wrapper-perl || die "Failed to install required packages."

# ----- Prepare target directory -----
echo "Creating target directory if needed: $TARGET_DIR"
mkdir -p "$TARGET_DIR" || die "Failed to create $TARGET_DIR"

if id asterisk >/dev/null 2>&1; then
    chown asterisk:asterisk "$TARGET_DIR" || die "Failed to set ownership on $TARGET_DIR"
else
    echo "Warning: user 'asterisk' not found yet. Skipping ownership change on $TARGET_DIR."
fi

cd "$TARGET_DIR" || die "Failed to change directory to $TARGET_DIR"

# ----- Download files -----
for FILE in "${FILES_TO_DOWNLOAD[@]}"; do
    echo "Downloading $FILE ..."
    curl -fL --retry 3 --connect-timeout 15 -o "$FILE" "$BASE_URL/$FILE" || die "Failed to download $FILE from $BASE_URL"
done

# ----- Permissions -----
echo "Setting file permissions..."
chmod 750 ./*.pl 2>/dev/null || true
chmod 750 ./*.sh 2>/dev/null || true
chmod 640 ./*.ulaw 2>/dev/null || true

if id asterisk >/dev/null 2>&1; then
    chown asterisk:asterisk ./*.pl ./*.sh ./*.ulaw 2>/dev/null || true
fi

# ----- Create systemd service -----
echo "Creating systemd service: $SERVICE_FILE"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=AllStar SayIP Service
After=asterisk.service network-online.target
Wants=network-online.target
Requires=asterisk.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'sleep 8 && /etc/asterisk/local/sayip.pl $NODE_NUMBER'
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload || die "systemctl daemon-reload failed"
systemctl enable allstar-sayip.service || die "Failed to enable allstar-sayip.service"
systemctl start allstar-sayip.service || echo "Warning: service enable succeeded, but service start did not."

# ----- Backup config -----
BACKUP_FILE="${CONF_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
cp "$CONF_FILE" "$BACKUP_FILE" || die "Failed to create backup of $CONF_FILE"
echo "Backup created: $BACKUP_FILE"

# ----- Insert DTMF functions individually -----
insert_function_if_missing "A1" "A1 = cmd,/etc/asterisk/local/sayip.pl $NODE_NUMBER"
insert_function_if_missing "A3" "A3 = cmd,/etc/asterisk/local/saypublicip.pl $NODE_NUMBER"
insert_function_if_missing "B1" "B1 = cmd,/etc/asterisk/local/halt.pl $NODE_NUMBER"
insert_function_if_missing "B3" "B3 = cmd,/etc/asterisk/local/reboot.pl $NODE_NUMBER"

# ----- Reload Asterisk -----
reload_asterisk

echo
echo "Installation complete for node $NODE_NUMBER"
echo "Files installed in: $TARGET_DIR"
echo "Service enabled: allstar-sayip.service"
echo "Backup of rpt.conf: $BACKUP_FILE"
echo
echo "DTMF functions intended:"
echo "  *A1  -> Say local IP"
echo "  *A3  -> Say public IP"
echo "  *B1  -> Halt node"
echo "  *B3  -> Reboot node"
echo
echo "You may want to test these from the Asterisk CLI:"
echo "  asterisk -rvvv"
echo "Then key the commands and watch for execution."
