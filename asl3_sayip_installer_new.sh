#!/bin/bash

# ASL3 SayIP / Public IP / Reboot / Halt Installer
# Corrected for Debian / AllStarLink 3
# Repository: https://github.com/KD5FMU/Sayip-shutdown-reboot-2026

set -u

# ----- Settings -----
CONF_FILE="/etc/asterisk/rpt.conf"
TARGET_DIR="/etc/asterisk/local"
SERVICE_FILE="/etc/systemd/system/allstar-sayip.service"
BASE_URL="https://raw.githubusercontent.com/KD5FMU/Sayip-shutdown-reboot-2026/main"

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
        sed -i "/^\[functions\]/a ${line}" "$CONF_FILE" \
            || die "Failed to insert ${key} into $CONF_FILE"
    fi
}

ensure_node_uses_functions() {
    local node="$1"

    echo "Checking that node [$node] uses the [functions] stanza..."

    if ! grep -q "^\[$node\]" "$CONF_FILE"; then
        die "Node stanza [$node] was not found in $CONF_FILE"
    fi

    # Check only inside the selected node stanza.
    if awk -v node="[$node]" '
        $0 == node { in_node=1; next }
        /^\[/ && in_node { in_node=0 }
        in_node && /^[[:space:]]*functions[[:space:]]*=/ { found=1 }
        END { exit found ? 0 : 1 }
    ' "$CONF_FILE"; then
        echo "Node [$node] already has a functions line. Leaving it unchanged."
    else
        echo "Adding 'functions = functions' to node [$node]..."
        sed -i "/^\[$node\]/a functions = functions" "$CONF_FILE" \
            || die "Failed to add functions = functions to node [$node]"
    fi
}

ensure_functions_stanza_exists() {
    if grep -q "^\[functions\]" "$CONF_FILE"; then
        echo "[functions] stanza found."
    else
        echo "[functions] stanza not found. Creating it at the end of $CONF_FILE..."
        {
            echo
            echo "[functions]"
        } >> "$CONF_FILE" || die "Failed to create [functions] stanza."
    fi
}

reload_asterisk() {
    if command -v asterisk >/dev/null 2>&1; then
        echo "Reloading Asterisk/app_rpt..."
        asterisk -rx "rpt reload" >/dev/null 2>&1 || true
        asterisk -rx "dialplan reload" >/dev/null 2>&1 || true
        asterisk -rx "module reload app_rpt.so" >/dev/null 2>&1 || true
    else
        echo "Warning: asterisk command was not found. Skipping Asterisk reload."
    fi

    if systemctl is-active --quiet asterisk; then
        echo "Asterisk service is active."
    else
        echo "Warning: Asterisk service does not appear to be active right now."
    fi
}

# ----- Preflight Checks -----
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
need_cmd awk
need_cmd systemctl
need_cmd chown
need_cmd chmod
need_cmd mkdir
need_cmd cp
need_cmd date

# ----- Install Dependencies -----
echo "Updating package lists..."
apt-get update || die "apt-get update failed."

echo "Installing required packages..."
apt-get install -y curl libnet-ifconfig-wrapper-perl \
    || die "Failed to install required packages."

# ----- Prepare Target Directory -----
echo "Creating target directory if needed: $TARGET_DIR"
mkdir -p "$TARGET_DIR" || die "Failed to create $TARGET_DIR"

if id asterisk >/dev/null 2>&1; then
    chown asterisk:asterisk "$TARGET_DIR" \
        || die "Failed to set ownership on $TARGET_DIR"
else
    echo "Warning: user 'asterisk' was not found. Skipping ownership change on $TARGET_DIR."
fi

cd "$TARGET_DIR" || die "Failed to change directory to $TARGET_DIR"

# ----- Download Files -----
for FILE in "${FILES_TO_DOWNLOAD[@]}"; do
    echo "Downloading $FILE ..."
    curl -fL --retry 3 --connect-timeout 15 -o "$FILE" "$BASE_URL/$FILE" \
        || die "Failed to download $FILE from $BASE_URL"
done

# ----- Set Permissions -----
echo "Setting file permissions..."
chmod 750 ./*.pl 2>/dev/null || true
chmod 750 ./*.sh 2>/dev/null || true
chmod 640 ./*.ulaw 2>/dev/null || true

if id asterisk >/dev/null 2>&1; then
    chown asterisk:asterisk ./*.pl ./*.sh ./*.ulaw 2>/dev/null || true
fi

# ----- Create Systemd Service -----
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

echo "Starting allstar-sayip.service for initial test..."
systemctl start allstar-sayip.service \
    || echo "Warning: service was enabled, but the initial service start did not complete successfully."

# ----- Backup rpt.conf -----
BACKUP_FILE="${CONF_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
cp "$CONF_FILE" "$BACKUP_FILE" || die "Failed to create backup of $CONF_FILE"
echo "Backup created: $BACKUP_FILE"

# ----- Configure rpt.conf -----
ensure_functions_stanza_exists

ensure_node_uses_functions "$NODE_NUMBER"

insert_function_if_missing "A1" "A1 = cmd,/etc/asterisk/local/sayip.pl $NODE_NUMBER"
insert_function_if_missing "A3" "A3 = cmd,/etc/asterisk/local/saypublicip.pl $NODE_NUMBER"
insert_function_if_missing "B1" "B1 = cmd,/etc/asterisk/local/halt.pl $NODE_NUMBER"
insert_function_if_missing "B3" "B3 = cmd,/etc/asterisk/local/reboot.pl $NODE_NUMBER"

# ----- Reload Asterisk -----
reload_asterisk

# ----- Finished -----
echo
echo "Installation complete for node $NODE_NUMBER"
echo "Files installed in: $TARGET_DIR"
echo "Service enabled: allstar-sayip.service"
echo "Backup of rpt.conf: $BACKUP_FILE"
echo
echo "DTMF commands:"
echo "  *A1  -> Say local IP address"
echo "  *A3  -> Say public IP address"
echo "  *B1  -> Halt / shutdown node"
echo "  *B3  -> Reboot node"
echo
echo "Recommended test:"
echo "  sudo asterisk -rvvv"
echo
echo "Then key:"
echo "  *A1"
echo
echo "If it speaks your local IP address, you're good to go."
echo "Ham On Y'all!"
