#!/bin/sh
# Disposable chroot coverage for the package-owned table-28 handoff.
set -eu

[ "$(id -u)" = 0 ] || { echo 'SKIP: mock export ownership chroot requires root'; exit 0; }
if ! command -v chroot >/dev/null 2>&1; then
    chroot() { busybox chroot "$@"; }
fi
ROOT_SRC="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ROOT="${TMPDIR:-/tmp}/pollywan-export-ownership-test.$$"
trap 'rm -rf "$ROOT"' EXIT HUP INT TERM

mkdir -p "$ROOT"/bin "$ROOT"/sbin "$ROOT"/usr/bin "$ROOT"/usr/local/bin \
    "$ROOT"/lib/x86_64-linux-gnu "$ROOT"/lib64 "$ROOT"/tmp "$ROOT"/proc "$ROOT"/dev
cp /usr/bin/busybox "$ROOT/bin/busybox"
cp /lib/x86_64-linux-gnu/libresolv.so.2 "$ROOT/lib/x86_64-linux-gnu/"
cp /lib/x86_64-linux-gnu/libc.so.6 "$ROOT/lib/x86_64-linux-gnu/"
cp /lib64/ld-linux-x86-64.so.2 "$ROOT/lib64/"
for cmd in sh ash awk sed grep cat cp mv rm mkdir head tail sort printf touch sleep date logger pidof kill chmod; do
    cp "$ROOT/bin/busybox" "$ROOT/bin/$cmd"
done
cp /bin/dash "$ROOT/bin/sh"
mknod -m 666 "$ROOT/dev/null" c 1 3 2>/dev/null || { : > "$ROOT/dev/null"; chmod 666 "$ROOT/dev/null"; }
printf '1000.00 0.00\n' > "$ROOT/proc/uptime"

# Source the real functions without executing the command dispatcher.
sed '/^COMMAND="${1:-apply}"/,$d' "$ROOT_SRC/files/usr/local/bin/wan3-manager" > "$ROOT/tmp/manager-functions.sh"
cp "$ROOT_SRC/files/usr/local/bin/wan-export-watchdog" "$ROOT/usr/local/bin/"
cp "$ROOT_SRC/files/etc/hotplug.d/iface/95-wan3-manager" "$ROOT/tmp/hotplug.sh"

cat > "$ROOT/sbin/uci" <<'UCI'
#!/bin/sh
db=/tmp/uci.db
log=/tmp/uci.log
while [ $# -gt 0 ]; do
    case "$1" in -c) shift 2 ;; -q) shift ;; *) break ;; esac
done
cmd="${1:-}"; arg="${2:-}"
case "$cmd" in
    get)
        value="$(grep -F "${arg}=" "$db" | tail -n 1 | sed 's/^[^=]*=//')"
        [ -n "$value" ] || exit 1
        printf '%s\n' "$value"
        ;;
    set)
        key="${arg%%=*}"; value="${arg#*=}"
        grep -Fv "${key}=" "$db" > "$db.new" || true
        printf '%s=%s\n' "$key" "$value" >> "$db.new"
        mv "$db.new" "$db"
        printf 'set %s\n' "$arg" >> "$log"
        ;;
    delete)
        key="$arg"
        grep -Fv "${key}=" "$db" > "$db.new" || true
        mv "$db.new" "$db"
        printf 'delete %s\n' "$arg" >> "$log"
        ;;
    commit) printf 'commit %s\n' "$arg" >> "$log" ;;
    revert) printf 'revert %s\n' "$arg" >> "$log" ;;
    *) exit 2 ;;
esac
UCI

cat > "$ROOT/sbin/ip" <<'IP'
#!/bin/sh
log=/tmp/ip.log
printf '%s\n' "$*" >> "$log"
case "$*" in
    '-4 route show table 28 default') file=/tmp/route-default ;;
    '-4 route show table 28 0.0.0.0/1') file=/tmp/route-half1 ;;
    '-4 route show table 28 128.0.0.0/1') file=/tmp/route-half2 ;;
    '-4 route flush table 28 default') rm -f /tmp/route-default; exit 0 ;;
    '-4 route flush table 28 0.0.0.0/1') rm -f /tmp/route-half1; exit 0 ;;
    '-4 route flush table 28 128.0.0.0/1') rm -f /tmp/route-half2; exit 0 ;;
    '-4 route replace table 28 default '*) file=/tmp/route-default; shift 6 ;;
    '-4 route replace table 28 0.0.0.0/1 '*) file=/tmp/route-half1; shift 6 ;;
    '-4 route replace table 28 128.0.0.0/1 '*) file=/tmp/route-half2; shift 6 ;;
    *) exit 0 ;;
esac
case "$*" in
    '-4 route show '*) [ -r "$file" ] && cat "$file"; exit 0 ;;
esac
prefix=default
case "$file" in /tmp/route-half1) prefix=0.0.0.0/1 ;; /tmp/route-half2) prefix=128.0.0.0/1 ;; esac
printf '%s %s\n' "$prefix" "$*" > "$file"
IP

cat > "$ROOT/bin/pidof" <<'PIDOF'
#!/bin/sh
[ "${1:-}" = manager ] && echo 4242
PIDOF
cat > "$ROOT/bin/kill" <<'KILL'
#!/bin/sh
printf '%s\n' "$*" >> /tmp/kill.log
KILL
cat > "$ROOT/bin/logger" <<'LOGGER'
#!/bin/sh
printf '%s\n' "$*" >> /tmp/logger.log
LOGGER
cat > "$ROOT/usr/local/bin/wan3-manager" <<'WITHDRAW'
#!/bin/sh
printf '%s\n' "$*" >> /tmp/manager.log
if [ "${1:-}" = export-withdraw ]; then
    rm -f /tmp/route-default /tmp/route-half1 /tmp/route-half2
fi
WITHDRAW
chmod 755 "$ROOT/sbin/uci" "$ROOT/sbin/ip" "$ROOT/bin/pidof" "$ROOT/bin/kill" \
    "$ROOT/bin/logger" "$ROOT/usr/local/bin/wan3-manager" \
    "$ROOT/usr/local/bin/wan-export-watchdog" "$ROOT/tmp/hotplug.sh"
ln -s /sbin/uci "$ROOT/usr/bin/uci"
ln -s /sbin/ip "$ROOT/usr/bin/ip"

cat > "$ROOT/tmp/test.sh" <<'TEST'
#!/bin/sh
set -eu
. /tmp/manager-functions.sh

get() { uci -c /etc/config.mesh -q get "$1"; }
absent() { ! uci -c /etc/config.mesh -q get "$1" >/dev/null 2>&1; }

# Exact presence/value preservation and a task-specific manager signal.
cat > /tmp/uci.db <<'DB'
aredn.multiwan.enabled=1
aredn.@wan[0].monitor1=1.1.1.1
aredn.@wan[0].local_defaultroute=1
DB
native_monitor_takeover
[ "$(get aredn.multiwan.native_monitor_takeover)" = 1 ]
[ "$(get aredn.multiwan.native_monitor1_present)" = 1 ]
[ "$(get aredn.multiwan.native_monitor1_saved)" = 1.1.1.1 ]
[ "$(get aredn.multiwan.native_monitor2_present)" = 0 ]
absent 'aredn.@wan[0].monitor1'
absent 'aredn.@wan[0].monitor2'
[ -e /tmp/mgr/wan_monitor ]

native_monitor_release
[ "$(get 'aredn.@wan[0].monitor1')" = 1.1.1.1 ]
absent 'aredn.@wan[0].monitor2'
absent aredn.multiwan.native_monitor_takeover

# A later administrator value wins if disable occurs before another takeover.
native_monitor_takeover
uci -c /etc/config.mesh set 'aredn.@wan[0].monitor1=9.9.9.9'
uci -c /etc/config.mesh set 'aredn.@wan[0].monitor2=8.8.8.8'
uci -c /etc/config.mesh commit aredn
native_monitor_release
[ "$(get 'aredn.@wan[0].monitor1')" = 9.9.9.9 ]
[ "$(get 'aredn.@wan[0].monitor2')" = 8.8.8.8 ]

# Split-default publication is complete and a second reconcile is a no-op.
native_monitor_takeover
reconcile_export_routes br-wan 192.0.2.10 192.0.2.1
[ -s /tmp/route-default ] && [ -s /tmp/route-half1 ] && [ -s /tmp/route-half2 ]
before="$(grep -c 'route replace table 28' /tmp/ip.log)"
reconcile_export_routes br-wan 192.0.2.10 192.0.2.1
after="$(grep -c 'route replace table 28' /tmp/ip.log)"
[ "$before" = "$after" ]

# Switching stock split-default policy off removes both /1s without touching
# unrelated tables.
uci -c /etc/config.mesh set 'aredn.@wan[0].local_defaultroute=0'
reconcile_export_routes br-wan 192.0.2.10 192.0.2.1
[ -s /tmp/route-default ]
[ ! -e /tmp/route-half1 ] && [ ! -e /tmp/route-half2 ]
! grep -E 'flush table (22|23)' /tmp/ip.log >/dev/null

# A stale monotonic heartbeat fails closed.
printf '1\n' > /tmp/wan3/export-heartbeat
POLLYWAN_WATCHDOG_ONCE=1 /usr/local/bin/wan-export-watchdog
grep -Fx 'export-withdraw' /tmp/manager.log >/dev/null
[ ! -e /tmp/route-default ]

# The later hotplug handler flushes stock-created /0 and split /1 routes
# synchronously before it starts asynchronous requalification.
printf 'default via 192.0.2.1 dev br-wan src 192.0.2.10\n' > /tmp/route-default
printf '0.0.0.0/1 via 192.0.2.1 dev br-wan src 192.0.2.10\n' > /tmp/route-half1
printf '128.0.0.0/1 via 192.0.2.1 dev br-wan src 192.0.2.10\n' > /tmp/route-half2
INTERFACE=wan ACTION=ifupdate /tmp/hotplug.sh
[ ! -e /tmp/route-default ] && [ ! -e /tmp/route-half1 ] && [ ! -e /tmp/route-half2 ]

echo 'mock package-owned table-28 handoff passed'
TEST
chmod 755 "$ROOT/tmp/test.sh"
chroot "$ROOT" /tmp/test.sh
