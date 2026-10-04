#!/usr/bin/env bash
# Boots a headless Luanti server with the game for a few seconds and reports
# Lua errors. Usage: tools/boot_test.sh [seconds] [world_dir]
# Requires LUANTI_SERVER (path to luantiserver) or luantiserver in PATH.
set -u
SECS="${1:-12}"
WORLD="${2:-$(mktemp -d)/world}"
SERVER="${LUANTI_SERVER:-luantiserver}"
mkdir -p "$WORLD"
CONF="$WORLD/../test.conf"
cat > "$CONF" <<CONF
mg_name = v7
enable_damage = true
creative_mode = false
server_announce = false
port = ${PORT:-30123}
debug_log_level = action
enable_ipv6 = false
ipv6_server = false
CONF
LOG="$WORLD/../server.log"
timeout --signal=INT "$SECS" "$SERVER" --gameid dbil --world "$WORLD" --config "$CONF" --logfile "$LOG" > /dev/null 2>&1
echo "== log: $LOG"
if grep -E "ERROR|error:|stack traceback" "$LOG" > /dev/null; then
	grep -n -E -A 12 "ERROR|error:" "$LOG" | head -60
	exit 1
fi
grep -E "\[dbil\]|Server for gameid" "$LOG" | head -40
exit 0
