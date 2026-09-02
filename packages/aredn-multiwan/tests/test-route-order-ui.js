#!/usr/bin/env node
"use strict";

const fs = require("fs");
const source = fs.readFileSync("files/app/main/status/e/wan-policy.ut", "utf8");
const match = source.match(/<script>\(function\(\)\{([\s\S]*?)\}\)\(\);<\/script>/);
if (!match) throw new Error("Route Policy Setup script was not found");

function select(value)
{
    return {
        value,
        attributes: {},
        listeners: {},
        setAttribute(name, next) { this.attributes[name] = next; },
        getAttribute(name) { return this.attributes[name]; },
        addEventListener(name, handler) { this.listeners[name] = handler; }
    };
}

const order = [ select("wan"), select("wan2"), select("wan3"), select("mesh") ];
global.document = {
    getElementById(id) {
        if (id !== "wan-policy-form") return null;
        return { querySelectorAll() { return order; } };
    }
};
global.htmx = { on() {}, ajax() {} };

const script = match[1].replace('{{_R("open")}}', "");
new Function(script)();

order[0].value = "mesh";
order[0].listeners.change.call(order[0]);
if (order.map(item => item.value).join(",") !== "mesh,wan2,wan3,wan") {
    throw new Error("Selecting Remote Mesh WAN first did not swap it with WAN 1");
}

order[2].value = "wan2";
order[2].listeners.change.call(order[2]);
if (order.map(item => item.value).join(",") !== "mesh,wan3,wan2,wan") {
    throw new Error("A second route-order edit did not preserve a unique permutation");
}

if (new Set(order.map(item => item.value)).size !== 4) {
    throw new Error("Route-order editing produced a duplicate route");
}

console.log("route-order UI swap passed");
