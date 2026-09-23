#!/bin/sh
# Disposable chroot test proving logical WAN 1 follows an AREDN Wi-Fi client
# into table 101 and source rule 81. Also checks Ethernet WAN2 and USB WAN3.
set -eu

[ "$(id -u)" = 0 ] || { echo 'SKIP: mock route-cache chroot requires root'; exit 0; }
ROOT_SRC="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ROOT="${TMPDIR:-/tmp}/pollywan-route-cache-test.$$"
trap 'rm -rf "$ROOT"' EXIT HUP INT TERM

mkdir -p "$ROOT"/bin "$ROOT"/sbin "$ROOT"/usr/bin "$ROOT"/usr/local/bin \
    "$ROOT"/lib/x86_64-linux-gnu "$ROOT"/lib64 "$ROOT"/tmp "$ROOT"/dev
cp /usr/bin/busybox "$ROOT/bin/busybox"
cp /lib/x86_64-linux-gnu/libresolv.so.2 "$ROOT/lib/x86_64-linux-gnu/"
cp /lib/x86_64-linux-gnu/libc.so.6 "$ROOT/lib/x86_64-linux-gnu/"
cp /lib64/ld-linux-x86-64.so.2 "$ROOT/lib64/"
for cmd in sh ash awk sed grep cat cp mv rm mkdir head sort printf; do ln -s busybox "$ROOT/bin/$cmd"; done
mknod -m 666 "$ROOT/dev/null" c 1 3
cp "$ROOT_SRC/files/usr/local/bin/wan-route-cache" "$ROOT/usr/local/bin/"
chmod 755 "$ROOT/usr/local/bin/wan-route-cache"

cat > "$ROOT/usr/bin/ubus" <<'UBUS'
#!/bin/sh
case "$2" in
    network.interface.wan) echo wan ;;
    network.interface.wan2) echo wan2 ;;
    network.interface.wan3) echo wan3 ;;
    *) exit 1 ;;
esac
UBUS

cat > "$ROOT/usr/bin/jsonfilter" <<'JSONFILTER'
#!/bin/sh
expr=''
while [ $# -gt 0 ]; do
    case "$1" in
        -e) expr="$2"; shift 2 ;;
        *) shift ;;
    esac
done
name="$(cat)"
case "$expr" in
    '@.up') echo true ;;
    '@.l3_device')
        case "$name" in wan) echo wlan0 ;; wan2) echo br-wan2 ;; wan3) echo usb0 ;; esac
        ;;
    '@["ipv4-address"][0].address')
        case "$name" in wan) echo 192.0.2.10 ;; wan2) echo 198.51.100.10 ;; wan3) echo 192.168.49.2 ;; esac
        ;;
    "@.route[@.target='0.0.0.0'].nexthop")
        case "$name" in wan) echo 192.0.2.1 ;; wan2) echo 198.51.100.1 ;; wan3) echo 192.168.49.1 ;; esac
        ;;
    "@.inactive.route[@.target='0.0.0.0'].nexthop") : ;;
    *) exit 1 ;;
esac
JSONFILTER

cat > "$ROOT/sbin/ip" <<'IP'
#!/bin/sh
printf '%s\n' "$*" >> /tmp/ip.log
case "$*" in
    '-4 route show table all dev wlan0 scope link')
        echo '192.0.2.0/24 dev wlan0 scope link src 192.0.2.10'
        ;;
    '-4 route show table all dev br-wan2 scope link')
        echo '198.51.100.0/24 dev br-wan2 scope link src 198.51.100.10'
        ;;
    '-4 route show table all dev usb0 scope link')
        echo '192.168.49.0/24 dev usb0 scope link src 192.168.49.2'
        ;;
    *' rule del '*) exit 1 ;;
    *) exit 0 ;;
esac
IP

chmod 755 "$ROOT/usr/bin/ubus" "$ROOT/usr/bin/jsonfilter" "$ROOT/sbin/ip"
ln -s /sbin/ip "$ROOT/usr/bin/ip"

chroot "$ROOT" /usr/local/bin/wan-route-cache all

LOG="$ROOT/tmp/ip.log"
grep -F -- '-4 route flush table 101' "$LOG" >/dev/null
grep -F -- '-4 route replace table 101 192.0.2.0/24 dev wlan0 src 192.0.2.10 scope link proto static' "$LOG" >/dev/null
grep -F -- '-4 route replace table 101 default via 192.0.2.1 dev wlan0 src 192.0.2.10 metric 10 onlink proto static' "$LOG" >/dev/null
grep -F -- '-4 rule add pref 81 from 192.0.2.10/32 lookup 101' "$LOG" >/dev/null

grep -F -- '-4 route flush table 102' "$LOG" >/dev/null
grep -F -- '-4 route replace table 102 default via 198.51.100.1 dev br-wan2 src 198.51.100.10 metric 10 onlink proto static' "$LOG" >/dev/null
grep -F -- '-4 rule add pref 82 from 198.51.100.10/32 lookup 102' "$LOG" >/dev/null

# netifd owns table 103, but PollyWAN installs source rule 83 for bound probes.
! grep -F -- '-4 route flush table 103' "$LOG" >/dev/null
grep -F -- '-4 rule add pref 83 from 192.168.49.2/32 lookup 103' "$LOG" >/dev/null

echo 'mock private WAN route cache passed (Wi-Fi WAN1 -> table 101)'
