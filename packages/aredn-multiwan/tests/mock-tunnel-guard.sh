#!/bin/sh
set -eu
[ "$(id -u)" = 0 ] || { echo 'SKIP: mock tunnel-guard chroot requires root'; exit 0; }
ROOT_SRC="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ROOT="${TMPDIR:-/tmp}/pollywan-guard-test.$$"
trap 'rm -rf "$ROOT"' EXIT HUP INT TERM
mkdir -p "$ROOT"/bin "$ROOT"/lib/x86_64-linux-gnu "$ROOT"/lib64 "$ROOT"/usr/bin "$ROOT"/usr/local/bin "$ROOT"/etc/aredn_include "$ROOT"/etc/init.d "$ROOT"/tmp "$ROOT"/sys/class/net/wg-test "$ROOT"/sys/class/net/tun5 "$ROOT"/dev
cp /usr/bin/busybox "$ROOT/bin/busybox"
cp /lib/x86_64-linux-gnu/libresolv.so.2 "$ROOT/lib/x86_64-linux-gnu/"
cp /lib/x86_64-linux-gnu/libc.so.6 "$ROOT/lib/x86_64-linux-gnu/"
cp /lib64/ld-linux-x86-64.so.2 "$ROOT/lib64/"
for cmd in sh awk sed grep cat cp mv rm mkdir rmdir sort cmp chmod printf tr; do ln -s busybox "$ROOT/bin/$cmd"; done
mknod -m 666 "$ROOT/dev/null" c 1 3
cp "$ROOT_SRC/files/usr/local/bin/wan-tunnel-guard" "$ROOT/usr/local/bin/"
chmod 755 "$ROOT/usr/local/bin/wan-tunnel-guard"
cat > "$ROOT/usr/bin/uci" <<'EOF_UCI'
#!/bin/sh
case "$*" in *aredn.multiwan.enabled*) cat /tmp/enabled ;; *) exit 1 ;; esac
EOF_UCI
cat > "$ROOT/usr/bin/ip" <<'EOF_IP'
#!/bin/sh
printf '%s\n' "$*" >> /tmp/ip.log
case " $* " in *' rule del '*|*' route del '*) exit 1 ;; *) exit 0 ;; esac
EOF_IP
cat > "$ROOT/usr/bin/pidof" <<'EOF_PID'
#!/bin/sh
exit 1
EOF_PID
chmod 755 "$ROOT/usr/bin/uci" "$ROOT/usr/bin/ip" "$ROOT/usr/bin/pidof"
ln -s /usr/bin/ip "$ROOT/bin/ip"
printf '# user sentinel\n' > "$ROOT/etc/aredn_include/babel-deny.conf"
printf '1\n' > "$ROOT/tmp/enabled"
chroot "$ROOT" /usr/local/bin/wan-tunnel-guard apply
grep -F 'rule add pref 45 iif wg-test lookup 99' "$ROOT/tmp/ip.log" >/dev/null
grep -F 'rule add pref 45 iif tun5 lookup 99' "$ROOT/tmp/ip.log" >/dev/null
grep -F 'redistribute proto 3 ip 0.0.0.0/0 eq 0 deny' "$ROOT/etc/aredn_include/babel-deny.conf" >/dev/null
grep -F 'in if wg-test ip 0.0.0.0/0 eq 0 deny' "$ROOT/etc/aredn_include/babel-deny.conf" >/dev/null
grep -F 'out if tun5 ip ::/0 eq 0 deny' "$ROOT/etc/aredn_include/babel-deny.conf" >/dev/null
printf '0\n' > "$ROOT/tmp/enabled"
chroot "$ROOT" /usr/local/bin/wan-tunnel-guard apply
grep -F '# user sentinel' "$ROOT/etc/aredn_include/babel-deny.conf" >/dev/null
! grep -F 'BEGIN AREDN-MULTIWAN-TUNNEL-GUARD' "$ROOT/etc/aredn_include/babel-deny.conf" >/dev/null
echo 'mock tunnel guard passed'
