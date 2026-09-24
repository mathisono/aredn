/*
 * Part of AREDN® -- Used for creating Amateur Radio Emergency Data Networks
 * Copyright (C) 2026 Tim Wilkinson
 * See Contributors file for additional contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation version 3 of the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Additional Terms:
 *
 * Additional use restrictions exist on the AREDN® trademark and logo.
 * See AREDNLicense.txt for more info.
 *
 * Attributions to the AREDN® Project must be retained in the source code.
 * If importing this code into a new or existing project attribution
 * to the AREDN® project must be added to the source code.
 *
 * You must not misrepresent the origin of the material contained within.
 *
 * Modified versions must be modified to attribute to the original source
 * and be marked in reasonable ways as differentiate it from the original
 * version
 */

const WAN_TABLE = 28;
const WAN_IFACE = "br-wan";
const PATT = regexp(`default via ([0-9\.]+) dev ${WAN_IFACE}`);
const POLLYWAN_REQUEST = "/var/run/pollywan/export-v1.json";
const POLLYWAN_SCHEMA = 1;
const POLLYWAN_MAX_AGE = 180;

const c = uci.cursor();

const mesh_to_local_wan = c.get("aredn", "@wan[0]", "mesh_to_local_wan");
const lan_to_local_wan = c.get("aredn", "@wan[0]", "lan_dhcp_route");
const local_defaultroute = c.get("aredn", "@wan[0]", "local_defaultroute");
const wan_passthrough = c.get("aredn", "@wan[0]", "passthrough");
const wan_mode = c.get("setup", "globals", "wan_proto");
const pollywan_enabled = c.get("aredn", "multiwan", "enabled") == "1";
const addresses = [];
const mon1 = c.get("aredn", "@wan[0]", "monitor1");
const mon2 = c.get("aredn", "@wan[0]", "monitor2");
if (mon1) {
    push(addresses, mon1);
}
if (mon2) {
    push(addresses, mon2);
}
if (!pollywan_enabled && !(length(addresses) > 0 && (mesh_to_local_wan == "1" || lan_to_local_wan == "1") && wan_passthrough == "0" && wan_mode != "disabled")) {
    return exitApp();
}

let last_gw = null;

function validDevice(value)
{
    return type(value) == "string" && match(value, /^[A-Za-z0-9_.:-]+$/);
}

function validIPv4(value)
{
    if (type(value) != "string" || !match(value, /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/)) {
        return false;
    }
    const octets = split(value, ".");
    for (let i = 0; i < 4; i++) {
        const number = +octets[i];
        if (number < 0 || number > 255 || `${number}` != octets[i]) {
            return false;
        }
    }
    return true;
}

function readPollyWANRequest()
{
    let request = null;
    try {
        request = json(fs.readfile(POLLYWAN_REQUEST));
    }
    catch (_) {
        return null;
    }
    if (type(request) != "object" || request.schema_version != POLLYWAN_SCHEMA || request.eligible != true ||
        !validDevice(request.device) || !validIPv4(request.source) ||
        (request.gateway != null && request.gateway != "" && !validIPv4(request.gateway)) ||
        type(request.monotonic_seconds) != "int" ||
        clock(true)[0] - request.monotonic_seconds < 0 ||
        clock(true)[0] - request.monotonic_seconds > POLLYWAN_MAX_AGE) {
        return null;
    }
    return request;
}

function desiredRoute(prefix, request)
{
    const via = request.gateway ? ` via ${request.gateway}` : "";
    return `${prefix}${via} dev ${request.device} src ${request.source} proto static metric 1`;
}

function routeMatches(prefix, request)
{
    const p = fs.popen(`/sbin/ip -4 route show table ${WAN_TABLE} ${prefix} 2>/dev/null`);
    if (!p) {
        return false;
    }
    const output = trim(p.read("all"));
    p.close();
    const via = request.gateway ? ` via ${request.gateway} ` : " ";
    return index(`\n${output}\n`, `\n${prefix}${via}dev ${request.device} `) >= 0 &&
        index(output, `src ${request.source}`) >= 0;
}

function routeExists(prefix)
{
    const p = fs.popen(`/sbin/ip -4 route show table ${WAN_TABLE} ${prefix} 2>/dev/null`);
    if (!p) {
        return false;
    }
    const found = trim(p.read("all")) != "";
    p.close();
    return found;
}

function deleteDefaultLikeRoutes()
{
    if (routeExists("default")) {
        system(`/sbin/ip -4 route flush table ${WAN_TABLE} default > /dev/null 2>&1`);
    }
    if (routeExists("0.0.0.0/1")) {
        system(`/sbin/ip -4 route flush table ${WAN_TABLE} 0.0.0.0/1 > /dev/null 2>&1`);
    }
    if (routeExists("128.0.0.0/1")) {
        system(`/sbin/ip -4 route flush table ${WAN_TABLE} 128.0.0.0/1 > /dev/null 2>&1`);
    }
}

function reconcilePollyWAN()
{
    const request = readPollyWANRequest();
    if (!request) {
        deleteDefaultLikeRoutes();
        return;
    }

    const split = request.split_default == true;
    if (!routeMatches("default", request) ||
        (split && (!routeMatches("0.0.0.0/1", request) || !routeMatches("128.0.0.0/1", request))) ||
        (!split && (routeExists("0.0.0.0/1") || routeExists("128.0.0.0/1")))) {
        deleteDefaultLikeRoutes();
        system(`/sbin/ip -4 route replace table ${WAN_TABLE} ${desiredRoute("default", request)} > /dev/null 2>&1`);
        if (split) {
            system(`/sbin/ip -4 route replace table ${WAN_TABLE} ${desiredRoute("0.0.0.0/1", request)} > /dev/null 2>&1`);
            system(`/sbin/ip -4 route replace table ${WAN_TABLE} ${desiredRoute("128.0.0.0/1", request)} > /dev/null 2>&1`);
        }
        log.syslog(log.LOG_INFO, "PollyWAN export request reconciled");
    }
}

function isInternetReachable(addrs)
{
    let success = false;
    for (let i = 0; !success && i < length(addrs); i++) {
        const p = fs.popen(`/bin/ping -c 1 -W 5 -I ${WAN_IFACE} ${addrs[i]}`);
        if (p) {
            for (let line = p.read("line"); length(line); line = p.read("line")) {
                const m = match(trim(line), /^64 bytes from /);
                if (m) {
                    success = true;
                }
            }
            p.close();
        }
    }
    return success;
}

function isInterfaceUp()
{
    let valid = false;
    const p = fs.popen(`/sbin/ip -o -4 addr show dev ${WAN_IFACE}`);
    if (p) {
        valid = p.read("all") != "";
        p.close();
    }
    return valid;
}

function isGwFound()
{
    let found = false;
    const p = fs.popen(`/sbin/ip route show table ${WAN_TABLE} 2>/dev/null`);
    if (p) {
        for (let line = p.read("line"); length(line); line = p.read("line")) {
            const m = match(trim(line), PATT);
            if (m) {
                found = true;
                last_gw = m[1];
            }
        }
        p.close();
    }
    return found;
}

function discoverWanGateway()
{
    const p = fs.popen(`/sbin/ip -4 route show table main default dev ${WAN_IFACE} 2>/dev/null`);
    if (p) {
        const m = match(trim(p.read("all")), regexp(`default via ([0-9\\.]+) dev ${WAN_IFACE}`));
        p.close();
        if (m) {
            last_gw = m[1];
        }
    }
}

function main()
{
    if (pollywan_enabled) {
        reconcilePollyWAN();
        return waitForTicks(10);
    }

    if (isInterfaceUp()) {
        const reachable = isInternetReachable(addresses);
        const found = isGwFound();
        if (!last_gw) {
            discoverWanGateway();
        }
        if (last_gw) {
            if (reachable && !found) {
                system(`/sbin/ip route add default via ${last_gw} dev ${WAN_IFACE} table ${WAN_TABLE} > /dev/null 2>&1`);
                if (local_defaultroute == "1") {
                    system(`/sbin/ip route add 0.0.0.0/1 via ${last_gw} dev ${WAN_IFACE} table ${WAN_TABLE} > /dev/null 2>&1`);
                    system(`/sbin/ip route add 128.0.0.0/1 via ${last_gw} dev ${WAN_IFACE} table ${WAN_TABLE} > /dev/null 2>&1`);
                }
                log.syslog(log.LOG_INFO, "WAN network reachable");
            }
            else if (!reachable && found) {
                system(`/sbin/ip route del default via ${last_gw} dev ${WAN_IFACE} table ${WAN_TABLE} > /dev/null 2>&1`);
                system(`/sbin/ip route del 0.0.0.0/1 via ${last_gw} dev ${WAN_IFACE} table ${WAN_TABLE} > /dev/null 2>&1`);
                system(`/sbin/ip route del 128.0.0.0/1 via ${last_gw} dev ${WAN_IFACE} table ${WAN_TABLE} > /dev/null 2>&1`);
                log.syslog(log.LOG_INFO, "WAN network unreachable");
            }
        }
    }

    return waitForTicks(60); // 1 minute
}

return waitForTicks(pollywan_enabled ? 1 : max(1, 120 - clock(true)[0]), main);
