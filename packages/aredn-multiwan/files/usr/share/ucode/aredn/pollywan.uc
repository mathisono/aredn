/*
 * Shared persistent configuration writer for the PollyWAN GUI.
 *
 * Each settings page owns a disjoint set of options.  All writes go through
 * this module so section repair, AREDN change tracking, commit checks, and
 * authoritative /etc/config.mesh read-back verification cannot drift between
 * dialogs.
 */

import * as uci from "uci";
import * as configuration from "aredn.configuration";

const owners = {
    policy: {
        enabled: true,
        selection_mode: true,
        preferred_wan: true,
        wan_enable: true,
        wan2_enable: true,
        wan3_enable: true,
        mesh_enable: true,
        priority_1: true,
        priority_2: true,
        priority_3: true,
        priority_4: true,
        selection_min_bin: true,
        mesh_share_min_bin: true,
        health_interval: true,
        health_url: true,
        health_url_secondary: true,
        failure_count: true,
        promote_count: true,
        hold_down: true,
        mesh_export_recover_count: true,
        mesh_export_hold_down: true,
        return_to_preferred: true,
        mesh_to_local_wan: true,
        lan_to_remote_wan: true
    },
    ports: {
        port_roles_enabled: true,
        port1_role: true,
        port2_role: true,
        port3_role: true,
        port4_role: true,
        port5_role: true,
        port1_dtd: true,
        port2_dtd: true,
        port3_dtd: true,
        port4_dtd: true,
        port5_dtd: true
    },
    usb: {
        wan3_device: true
    },
    speed: {
        speed_test_method: true,
        speed_test_payload: true,
        speed_result_ttl: true,
        speed_node: true,
        speed_iperf_port: true,
        speed_iperf_duration: true
    }
};

const arednWanOptions = {
    mesh_to_local_wan: true,
    lan_to_remote_wan: true
};

function target(name)
{
    if (arednWanOptions[name]) return { section: "@wan[0]", option: name };
    return { section: "multiwan", option: name };
};

function asString(value)
{
    return value == null ? "" : sprintf("%s", value);
};

function failure(message)
{
    return { ok: false, error: message };
};

function restoreValues(snapshot, sectionExisted)
{
    try {
        const restore = uci.cursor("/etc/config.mesh");
        if (!sectionExisted) {
            if (restore.get("aredn", "multiwan")) restore.delete("aredn", "multiwan");
        }
        const names = keys(snapshot);
        for (let i = 0; i < length(names); i++) {
            const item = snapshot[names[i]];
            if (!sectionExisted && item.section === "multiwan") continue;
            if (item.present)
                restore.set("aredn", item.section, item.option, item.value);
            else
                restore.delete("aredn", item.section, item.option);
        }
        if (restore.commit("aredn") === false) return false;

        const verify = uci.cursor("/etc/config.mesh");
        if (!sectionExisted && verify.get("aredn", "multiwan")) return false;
        for (let i = 0; i < length(names); i++) {
            const item = snapshot[names[i]];
            const actual = verify.get("aredn", item.section, item.option);
            if (item.present ? asString(actual) !== item.value : actual != null) return false;
        }
        return true;
    }
    catch (_) { return false; }
};

function restoredFailure(message, snapshot, sectionExisted)
{
    return failure(restoreValues(snapshot, sectionExisted) ? message : `${message}; previous persistent values could not be restored`);
};

export function save(owner, values, cursor)
{
    const allowed = owners[owner];
    if (!allowed) return failure("Unknown PollyWAN configuration owner");

    const names = keys(values || {});
    if (!length(names)) return failure("No PollyWAN configuration values were submitted");
    for (let i = 0; i < length(names); i++) {
        if (allowed[names[i]] !== true)
            return failure(`The ${owner} page does not own ${names[i]}`);
    }

    if (configuration.countChanges() > 0)
        return failure("Commit or revert pending AREDN changes before applying PollyWAN settings");

    const snapshot = {};
    let sectionExisted = false;
    try {
        if (!cursor) cursor = uci.cursor("/etc/config.mesh");
        sectionExisted = !!cursor.get("aredn", "multiwan");
        for (let i = 0; i < length(names); i++) {
            const name = names[i];
            const location = target(name);
            const previous = cursor.get("aredn", location.section, location.option);
            snapshot[name] = { section: location.section, option: location.option, present: previous != null, value: asString(previous) };
        }
        if (!sectionExisted) {
            if (cursor.set("aredn", "multiwan", "multiwan") === false)
                return failure("Could not create the persistent PollyWAN configuration section");
        }
        for (let i = 0; i < length(names); i++) {
            const name = names[i];
            const location = target(name);
            if (cursor.set("aredn", location.section, location.option, asString(values[name])) === false)
                return failure(`Could not stage persistent PollyWAN option ${name}`);
        }
        if (cursor.commit("aredn") === false)
            return restoredFailure("Could not commit persistent PollyWAN configuration", snapshot, sectionExisted);
    }
    catch (_) {
        return restoredFailure("Persistent PollyWAN configuration raised an unexpected write error", snapshot, sectionExisted);
    }

    try {
        const verify = uci.cursor("/etc/config.mesh");
        if (!verify.get("aredn", "multiwan"))
            return restoredFailure("Persistent PollyWAN configuration disappeared after commit", snapshot, sectionExisted);
        for (let i = 0; i < length(names); i++) {
            const name = names[i];
            const location = target(name);
            const actual = verify.get("aredn", location.section, location.option);
            if (asString(actual) !== asString(values[name]))
                return restoredFailure(`Persistent PollyWAN option ${name} did not match after commit`, snapshot, sectionExisted);
        }
    }
    catch (_) {
        return restoredFailure("Persistent PollyWAN configuration could not be verified after commit", snapshot, sectionExisted);
    }

    return { ok: true, error: "" };
};

/*
 * XLinks share the Ports & XLinks dialog, but live in their own persistent UCI
 * package.  Keep their commit and fresh-cursor verification here as well so
 * the combined dialog cannot silently accept only half of a submission.
 */
export function saveXlinks(values, defaults, cursor)
{
    if (configuration.countChanges() > 0)
        return failure("Commit or revert pending AREDN changes before applying PollyWAN settings");
    const desired = {};
    const names = [];
    const removed = [];
    const defaultPort = defaults && defaults.port || "eth0";
    const defaultCost = defaults && defaults.cost != null ? asString(defaults.cost) : "";

    for (let i = 0; i < length(values || []); i++) {
        const value = values[i];
        const name = value && value.name || "";
        if (!match(name, /^xlink[0-9]+$/) || desired[name])
            return failure("XLinks contain an invalid or duplicate entry name");
        desired[name] = {
            vlan: asString(value.vlan),
            ipaddr: asString(value.ipaddr),
            cidr: asString(value.cidr),
            netmask: asString(value.netmask),
            cost: value.cost == null || asString(value.cost) === "" ? defaultCost : asString(value.cost),
            port: asString(value.port || defaultPort),
            note: asString(value.note)
        };
        push(names, name);
    }

    const existing = {};
    try {
        if (!cursor) cursor = uci.cursor("/etc/config.mesh");
        cursor.foreach("xlink", "interface", section => { existing[section[".name"]] = true; });

        for (let name in existing) {
            if (desired[name]) continue;
            if (cursor.delete("xlink", name) === false)
                return failure(`Could not remove persistent XLink ${name}`);
            if (cursor.get("xlink", `${name}bridge`) && cursor.delete("xlink", `${name}bridge`) === false)
                return failure(`Could not remove persistent XLink bridge ${name}`);
            if (cursor.get("xlink", `${name}route`) && cursor.delete("xlink", `${name}route`) === false)
                return failure(`Could not remove persistent XLink route ${name}`);
            push(removed, name);
        }
        for (let i = 0; i < length(names); i++) {
            const name = names[i];
            const value = desired[name];
            if (cursor.set("xlink", `${name}bridge`, "bridge-vlan") === false ||
                cursor.set("xlink", `${name}bridge`, "device", "br0") === false ||
                cursor.set("xlink", `${name}bridge`, "vlan", value.vlan) === false ||
                cursor.set("xlink", `${name}bridge`, "ports", [ `${value.port}:t` ]) === false ||
                cursor.set("xlink", name, "interface") === false ||
                cursor.set("xlink", name, "ifname", `br0.${value.vlan}`) === false ||
                cursor.set("xlink", name, "ipaddr", value.ipaddr) === false ||
                cursor.set("xlink", name, "cost", value.cost) === false ||
                cursor.set("xlink", name, "netmask", value.netmask) === false ||
                cursor.set("xlink", name, "note", value.note) === false ||
                cursor.set("xlink", name, "proto", "static") === false)
                return failure(`Could not stage persistent XLink ${name}`);
            if (!cursor.get("xlink", name, "macaddr") &&
                cursor.set("xlink", name, "macaddr", replace("x2:xx:xx:xx:xx:xx", "x", _ => sprintf("%X", math.rand() & 15))) === false)
                return failure(`Could not create persistent XLink address for ${name}`);
        }
        if (cursor.commit("xlink") === false)
            return failure("Could not commit persistent XLink configuration");
    }
    catch (_) {
        return failure("Persistent XLink configuration raised an unexpected write error");
    }

    try {
        const verify = uci.cursor("/etc/config.mesh");
        const actualNames = {};
        verify.foreach("xlink", "interface", section => { actualNames[section[".name"]] = true; });
        if (length(keys(actualNames)) !== length(names))
            return failure("Persistent XLink count did not match after commit");
        for (let name in actualNames) {
            if (!desired[name]) return failure(`Unexpected persistent XLink ${name} remained after commit`);
        }
        for (let i = 0; i < length(removed); i++) {
            const name = removed[i];
            if (verify.get("xlink", name) || verify.get("xlink", `${name}bridge`) || verify.get("xlink", `${name}route`))
                return failure(`Removed persistent XLink ${name} remained after commit`);
        }
        for (let i = 0; i < length(names); i++) {
            const name = names[i];
            const value = desired[name];
            const ports = verify.get("xlink", `${name}bridge`, "ports") || [];
            if (asString(verify.get("xlink", `${name}bridge`)) !== "bridge-vlan" ||
                asString(verify.get("xlink", `${name}bridge`, "device")) !== "br0" ||
                asString(verify.get("xlink", `${name}bridge`, "vlan")) !== value.vlan ||
                length(ports) !== 1 || asString(ports[0]) !== `${value.port}:t` ||
                asString(verify.get("xlink", name)) !== "interface" ||
                asString(verify.get("xlink", name, "ifname")) !== `br0.${value.vlan}` ||
                asString(verify.get("xlink", name, "ipaddr")) !== value.ipaddr ||
                asString(verify.get("xlink", name, "cost")) !== value.cost ||
                asString(verify.get("xlink", name, "netmask")) !== value.netmask ||
                asString(verify.get("xlink", name, "note")) !== value.note ||
                asString(verify.get("xlink", name, "proto")) !== "static" ||
                !asString(verify.get("xlink", name, "macaddr")))
                return failure(`Persistent XLink ${name} did not match after commit`);
        }
    }
    catch (_) {
        return failure("Persistent XLink configuration could not be verified after commit");
    }

    return { ok: true, error: "" };
};
