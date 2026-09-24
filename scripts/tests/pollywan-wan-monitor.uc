#!/usr/bin/ucode

/* Exercise the real native WAN monitor through the same raw load interface
 * used by /usr/local/mgr/manager. No host routes or files are changed. */

let commands = [];
let routes = {};
let request = null;

function stream(value)
{
    return {
        read: function(mode) { return mode == "all" ? value : ""; },
        close: function() { return 0; }
    };
}

const mockfs = {
    readfile: function(path) {
        return path == "/var/run/pollywan/export-v1.json" ? request : null;
    },
    popen: function(command) {
        for (let prefix in routes) {
            if (index(command, `table 28 ${prefix}`) >= 0) {
                return stream(routes[prefix]);
            }
        }
        return stream("");
    }
};

const mockuci = {
    cursor: function() {
        return {
            get: function(config, section, option) {
                if (config == "aredn" && section == "multiwan" && option == "enabled") return "1";
                return null;
            }
        };
    }
};

const context = {
    fs: mockfs,
    uci: mockuci,
    log: { LOG_INFO: 6, syslog: function() {} },
    system: function(command) { push(commands, command); return 0; },
    waitForTicks: function(ticks, next) { return next; },
    exitApp: function() { return null; }
};

const source = loadfile("files/usr/local/mgr/wan_monitor.uc", { raw_mode: true });
const monitor = call(source, context, context);
const now = clock(true)[0];

request = sprintf('{"schema_version":1,"eligible":true,"device":"br-test","source":"192.0.2.2","gateway":"192.0.2.1","split_default":true,"monotonic_seconds":%d,"reason":"test"}', now);
call(monitor, context, context);
if (length(commands) != 3 || index(commands[0], "table 28 default via 192.0.2.1 dev br-test src 192.0.2.2") < 0 ||
    index(commands[1], "table 28 0.0.0.0/1") < 0 || index(commands[2], "table 28 128.0.0.0/1") < 0) {
    warn("eligible split-default reconciliation failed\n");
    exit(1);
}

routes = {
    default: "default via 192.0.2.1 dev br-test proto static src 192.0.2.2 metric 1\n",
    "0.0.0.0/1": "0.0.0.0/1 via 192.0.2.1 dev br-test proto static src 192.0.2.2 metric 1\n",
    "128.0.0.0/1": "128.0.0.0/1 via 192.0.2.1 dev br-test proto static src 192.0.2.2 metric 1\n"
};
commands = [];
call(monitor, context, context);
if (length(commands) != 0) {
    warn("idempotent reconciliation wrote unchanged routes\n");
    exit(1);
}

request = sprintf('{"schema_version":1,"eligible":true,"device":"br-test","source":"192.0.2.2","gateway":"192.0.2.1","split_default":true,"monotonic_seconds":%d,"reason":"stale"}', now - 181);
commands = [];
call(monitor, context, context);
if (length(commands) != 3 || index(join("\n", commands), "table 28 default") < 0 ||
    index(join("\n", commands), "table 28 0.0.0.0/1") < 0 ||
    index(join("\n", commands), "table 28 128.0.0.0/1") < 0) {
    warn("stale request did not withdraw the complete default-like route set\n");
    exit(1);
}
if (index(join("\n", commands), "table 22") >= 0 || index(join("\n", commands), "table 23") >= 0) {
    warn("native export reconciliation touched table 22 or 23\n");
    exit(1);
}

print("native PollyWAN WAN-monitor contract passed\n");
