#!/bin/sh
# Root-only disposable chroot tests for Ethernet roles, Wi-Fi WAN ownership,
# DSA/swconfig generation, rollback, GPS non-interference, and conflicts.
set -eu

[ "$(id -u)" = 0 ] || { echo 'SKIP: mock port-manager chroot requires root'; exit 0; }
ROOT_SRC="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/pollywan-port-test.$$"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

setup_root()
{
    root="$1"
    mkdir -p "$root"/bin "$root"/sbin "$root"/usr/bin "$root"/usr/sbin "$root"/usr/local/bin \
        "$root"/etc/config.mesh "$root"/etc/aredn_include "$root"/etc/init.d "$root"/tmp/sysinfo \
        "$root"/tmp/wan-sla "$root"/sys/class/net "$root"/dev "$root"/lib/x86_64-linux-gnu "$root"/lib64
    cp /usr/bin/busybox "$root/bin/busybox"
    cp /lib/x86_64-linux-gnu/libresolv.so.2 "$root/lib/x86_64-linux-gnu/"
    cp /lib/x86_64-linux-gnu/libc.so.6 "$root/lib/x86_64-linux-gnu/"
    cp /lib64/ld-linux-x86-64.so.2 "$root/lib64/"
    for cmd in sh ash awk sed grep cat cp mv rm mkdir rmdir date sleep kill readlink tr head md5sum dirname basename cut sort wc touch chmod cmp ls id; do
        ln -s busybox "$root/bin/$cmd"
    done
    ln -s /bin/busybox "$root/usr/bin/logger"
    ln -s /bin/busybox "$root/usr/bin/printf"
    ln -s /bin/busybox "$root/usr/bin/pidof"
    ln -s /bin/busybox "$root/sbin/ip"
    ln -s /bin/busybox "$root/usr/sbin/nft"
    cp "$ROOT_SRC/files/usr/local/bin/wan-port-manager" "$root/usr/local/bin/"
    chmod 755 "$root/usr/local/bin/wan-port-manager"
    mknod -m 666 "$root/dev/null" c 1 3

    cat > "$root/sbin/uci" <<'UCI'
#!/bin/sh
set -u
db=/tmp/uci.db
while [ $# -gt 0 ]; do
    case "$1" in -q) shift ;; -c) shift 2 ;; *) break ;; esac
done
cmd="${1:-}"; shift || true
getv() { awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; found=1; exit } END { if (!found) exit 1 }' "$db"; }
setv() {
    key="${1%%=*}"; val="${1#*=}"; tmp="$db.tmp.$$"
    awk -F= -v key="$key" '$1 != key { print }' "$db" > "$tmp" 2>/dev/null || true
    printf '%s=%s\n' "$key" "$val" >> "$tmp"; mv "$tmp" "$db"
}
case "$cmd" in
    get) getv "$1" ;;
    set) setv "$1" ;;
    add_list)
        key="${1%%=*}"; add="${1#*=}"; old="$(getv "$key" 2>/dev/null || true)"
        case " $old " in *" $add "*) ;; *) setv "$key=${old:+$old }$add" ;; esac
        ;;
    del_list)
        key="${1%%=*}"; del="${1#*=}"; old="$(getv "$key" 2>/dev/null || true)"; new=''
        for x in $old; do [ "$x" = "$del" ] || new="${new:+$new }$x"; done
        setv "$key=$new"
        ;;
    delete)
        key="$1"; tmp="$db.tmp.$$"; awk -F= -v key="$key" '$1 != key && index($1, key ".") != 1 { print }' "$db" > "$tmp"; mv "$tmp" "$db"
        ;;
    commit) : ;;
    *) exit 1 ;;
esac
UCI
    chmod 755 "$root/sbin/uci"
    ln -s /sbin/uci "$root/usr/bin/uci"

    for cmd in ubus jsonfilter swconfig; do
        cat > "$root/usr/bin/$cmd" <<'MOCK'
#!/bin/sh
case "$(basename "$0")" in
  swconfig) echo 'link:up speed:1000baseT full-duplex' ;;
  *) exit 0 ;;
esac
MOCK
        chmod 755 "$root/usr/bin/$cmd"
    done
    ln -s /usr/bin/swconfig "$root/sbin/swconfig"

    for cmd in node-setup wan3-manager wan-route-cache wan-tunnel-guard wan-sla; do
        cat > "$root/usr/local/bin/$cmd" <<'MOCK'
#!/bin/sh
exit 0
MOCK
        chmod 755 "$root/usr/local/bin/$cmd"
    done
    for svc in network firewall dnsmasq; do
        cat > "$root/etc/init.d/$svc" <<'MOCK'
#!/bin/sh
exit 0
MOCK
        chmod 755 "$root/etc/init.d/$svc"
    done
    printf 'gps-sentinel\n' > "$root/etc/config.mesh/gpsd"
}

write_base_db()
{
    root="$1"
    cat > "$root/tmp/uci.db" <<'DB'
aredn.multiwan.enabled=1
aredn.multiwan.port_roles_enabled=1
aredn.multiwan.wan_enable=1
aredn.multiwan.wan2_enable=1
aredn.multiwan.port_rollback_timeout=60
aredn.multiwan.port1_role=wan
aredn.multiwan.port2_role=wan2
aredn.multiwan.port3_role=lan
aredn.multiwan.port4_role=lan
aredn.multiwan.port5_role=off
aredn.multiwan.port1_dtd=0
aredn.multiwan.port2_dtd=0
aredn.multiwan.port3_dtd=0
aredn.multiwan.port4_dtd=0
aredn.multiwan.port5_dtd=1
setup.globals.radio0_mode=off
setup.globals.radio1_mode=off
firewall.@zone[0].name=wan
firewall.@zone[0].network=wan
DB
}

set_db()
{
    root="$1"; key="$2"; value="$3"
    chroot "$root" /sbin/uci set "$key=$value"
}

add_devices()
{
    root="$1"; kind="$2"
    if [ "$kind" = dsa ]; then
        for d in wan lan1 lan2 lan3 lan4 wlan0 wlan1; do
            mkdir -p "$root/sys/class/net/$d"
            echo 1 > "$root/sys/class/net/$d/carrier"
        done
    else
        for d in eth0 eth1 wlan0 wlan1; do
            mkdir -p "$root/sys/class/net/$d"
            echo 1 > "$root/sys/class/net/$d/carrier"
        done
    fi
}

assert_gps_unchanged()
{
    root="$1"
    [ "$(cat "$root/etc/config.mesh/gpsd")" = gps-sentinel ]
}

run_ethernet_case()
{
    board="$1"; kind="$2"; root="$TMP/ethernet-$kind"
    setup_root "$root"; write_base_db "$root"; add_devices "$root" "$kind"
    printf '%s\n' "$board" > "$root/tmp/sysinfo/board_name"

    [ "$(POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager wan-transport)" = 'ethernet:br-wan' ]
    POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager validate
    token="$(POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager apply)"
    [ -n "$token" ] || { echo "missing rollback token for $kind" >&2; exit 1; }

    bridge="$root/etc/aredn_include/bridge.network.user"
    grep -F "option vlan '4'" "$bridge" >/dev/null
    grep -F "option vlan '5'" "$bridge" >/dev/null
    grep -F "option ip4table '102'" "$bridge" >/dev/null
    grep -F "list ports 'br0.5'" "$bridge" >/dev/null
    grep -F "option vlan '2'" "$bridge" >/dev/null
    test -f "$root/etc/aredn_include/wan.network.user"
    grep -F "option ip4table '101'" "$root/etc/aredn_include/wan.network.user" >/dev/null
    grep -F 'wan_transport=ethernet:br-wan' "$root/etc/aredn_include/.aredn-multiwan-ports" >/dev/null

    if [ "$kind" = dsa ]; then
        grep -F "list ports 'wan:u'" "$bridge" >/dev/null
        grep -F "list ports 'lan1:u'" "$bridge" >/dev/null
        grep -F "list ports 'lan4:t'" "$bridge" >/dev/null
    else
        grep -F "list ports 'eth1:u'" "$bridge" >/dev/null
        grep -F "list ports 'eth0:t'" "$bridge" >/dev/null
        # Port 1 is the dedicated eth1 MAC on hAP ac lite, so VLAN 4 does
        # not require a switch0 stanza. WAN 2 on Port 2 does require VLAN 5.
        grep -F "option vlan '5'" "$root/etc/aredn_include/swconfig" >/dev/null
        grep -F "option ports '0t 4'" "$root/etc/aredn_include/swconfig" >/dev/null
        grep -F "option ports '0t 1t'" "$root/etc/aredn_include/swconfig" >/dev/null
    fi

    assert_gps_unchanged "$root"

    # A later AREDN radio-mode change must not silently rewrite port roles.
    set_db "$root" setup.globals.radio0_mode wan
    POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager reconcile
    grep -F '"status":"attention"' "$root/tmp/wan-port-manager/state.json" >/dev/null
    grep -F 'WAN 1 transport changed' "$root/tmp/wan-port-manager/state.json" >/dev/null
    set_db "$root" setup.globals.radio0_mode off

    POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager confirm "$token"
    POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager restore
    assert_gps_unchanged "$root"
    [ ! -e "$root/etc/aredn_include/.aredn-multiwan-ports" ]
    [ "$(chroot "$root" /sbin/uci get aredn.multiwan.port_roles_enabled)" = 0 ]
    [ "$(chroot "$root" /sbin/uci get aredn.multiwan.wan2_enable)" = 0 ]
    [ "$(chroot "$root" /sbin/uci get aredn.multiwan.wan3_enable)" = 0 ]
    [ "$(chroot "$root" /sbin/uci get aredn.multiwan.wan3_proxy_enable)" = 0 ]
    echo "mock Ethernet port generation passed: $kind"
}

write_wifi_roles()
{
    root="$1"; radio="$2"
    set_db "$root" setup.globals.radio0_mode off
    set_db "$root" setup.globals.radio1_mode off
    set_db "$root" "setup.globals.radio${radio}_mode" wan
    set_db "$root" aredn.multiwan.port1_role off
    set_db "$root" aredn.multiwan.port2_role wan2
    set_db "$root" aredn.multiwan.port3_role lan
    set_db "$root" aredn.multiwan.port4_role lan
    set_db "$root" aredn.multiwan.port5_role off
}

run_wifi_case()
{
    board="$1"; kind="$2"; radio="$3"; expected="wlan$radio"; root="$TMP/wifi-$kind-$radio"
    setup_root "$root"; write_base_db "$root"; add_devices "$root" "$kind"
    printf '%s\n' "$board" > "$root/tmp/sysinfo/board_name"
    write_wifi_roles "$root" "$radio"

    [ "$(POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager wan-transport)" = "wifi:$expected" ]
    POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager validate
    token="$(POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager apply)"
    [ -n "$token" ]

    bridge="$root/etc/aredn_include/bridge.network.user"
    ! grep -F "option vlan '4'" "$bridge" >/dev/null
    grep -F "option vlan '5'" "$bridge" >/dev/null
    grep -F "option ip4table '102'" "$bridge" >/dev/null
    [ ! -e "$root/etc/aredn_include/wan.network.user" ]
    grep -F "wan_transport=wifi:$expected" "$root/etc/aredn_include/.aredn-multiwan-ports" >/dev/null

    if [ "$kind" = swconfig ]; then
        ! grep -F "option vlan '4'" "$root/etc/aredn_include/swconfig" >/dev/null
        grep -F "option vlan '5'" "$root/etc/aredn_include/swconfig" >/dev/null
    fi

    assert_gps_unchanged "$root"
    POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager confirm "$token"
    POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager restore
    assert_gps_unchanged "$root"
    echo "mock Wi-Fi WAN ownership passed: $kind/$expected"
}

run_conflict_cases()
{
    root="$TMP/conflicts"
    setup_root "$root"; write_base_db "$root"; add_devices "$root" dsa
    printf '%s\n' mikrotik,hap-ac2 > "$root/tmp/sysinfo/board_name"

    set_db "$root" setup.globals.radio0_mode wan
    [ "$(POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager wan-transport)" = 'wifi:wlan0' ]
    if POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager validate >"$root/tmp/conflict.out" 2>&1; then
        echo 'Wi-Fi plus Ethernet WAN 1 conflict was accepted' >&2
        exit 1
    fi
    grep -F 'no Ethernet port may be assigned to WAN 1' "$root/tmp/conflict.out" >/dev/null

    set_db "$root" aredn.multiwan.port1_role off
    set_db "$root" setup.globals.radio1_mode wan
    if POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager validate >"$root/tmp/dual.out" 2>&1; then
        echo 'dual-radio WAN conflict was accepted' >&2
        exit 1
    fi
    grep -F 'both AREDN radios are configured as WAN clients' "$root/tmp/dual.out" >/dev/null
    if POLLYWAN_TEST_MODE=1 chroot "$root" /usr/local/bin/wan-port-manager wan-transport >"$root/tmp/transport.out" 2>&1; then
        echo 'dual-radio WAN transport was accepted' >&2
        exit 1
    fi
    grep -F 'invalid:both-radios' "$root/tmp/transport.out" >/dev/null
    assert_gps_unchanged "$root"
    echo 'mock Wi-Fi WAN conflict rejection passed'
}

run_ethernet_case mikrotik,hap-ac2 dsa
run_wifi_case mikrotik,routerboard-952ui-5ac2nd swconfig 1
run_conflict_cases
