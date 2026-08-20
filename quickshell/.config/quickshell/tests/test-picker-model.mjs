import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const source = fs.readFileSync(new URL("../components/PickerModel.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*/m, "");
const context = vm.createContext({});
vm.runInContext(source, context);

const items = [
    { name: "Firefox", genericName: "Web Browser", metadata: "org.mozilla.firefox" },
    { name: "Files", genericName: "File Manager", metadata: "org.gnome.Nautilus" },
    { name: "work/github", genericName: "", metadata: "" }
];

assert.equal(context.scoreItem(items[0], "firefox"), 100);
assert.equal(context.scoreItem(items[0], "fire"), 80);
assert.equal(context.scoreItem(items[2], "github"), 60);
assert.equal(context.scoreItem(items[1], "manager"), 10);
assert.equal(context.scoreItem(items[1], "missing"), -1);
assert.deepEqual(Array.from(context.filter(items, "fi", 10), item => item.name), ["Files", "Firefox"]);
assert.deepEqual(Array.from(context.filter(items, "", 2), item => item.name), ["Files", "Firefox"]);

console.log("picker model tests passed");
