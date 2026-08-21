pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // --- Stats Properties ---
    property int cpuUsage: 0
    property int cpuTemp: -1
    property real cpuPower: -1
    property string cpuModel: ""
    property int cpuClock: -1
    property int memUsage: 0
    property int gpuUsage: 0
    property bool gpuAvailable: false
    property bool gpuMetricsAvailable: false
    property string gpuModel: ""
    property string gpuPci: ""
    property string gpuVramVendor: ""
    property string gpuVbiosVersion: ""
    property int gpuMemUsage: -1
    property int gpuVcnUsage: -1
    property int gpuVramUsage: -1
    property int gpuVisVramUsage: -1
    property int gpuGttUsage: -1
    property real gpuVramUsed: -1
    property real gpuVramTotal: -1
    property real gpuVisVramUsed: -1
    property real gpuVisVramTotal: -1
    property real gpuGttUsed: -1
    property real gpuGttTotal: -1
    property int gpuTempEdge: -1
    property int gpuTempHotspot: -1
    property int gpuTempMem: -1
    property int gpuTempVrGfx: -1
    property int gpuTempVrMem: -1
    property int gpuTempVrSoc: -1
    property real gpuPower: -1
    property int gpuFanRpm: -1
    property int gpuClock: -1
    property int gpuMemoryClock: -1
    property int gpuSocClock: -1
    property int gpuVideoClock: -1
    property int gpuVideoClock1: -1
    property int gpuVoltage: -1
    property int gpuMemVoltage: -1
    property int gpuSocVoltage: -1
    property string gpuPcieSpeed: ""
    property string gpuPcieWidth: ""
    property string gpuPcieMaxSpeed: ""
    property string gpuPcieMaxWidth: ""
    property string gpuThrottleStatus: ""
    property int diskUsage: 0
    property int memTotal: 0

    // --- Detailed Information ---
    property var cpuCores: []
    property ListModel cpuCoresModel: ListModel {}
    property var drives: []
    property var memHogs: []
    property ListModel memHogsModel: ListModel {}
    property var gpuVramProcesses: []
    property ListModel gpuVramProcessesModel: ListModel {}

    // --- Internal State ---
    property var _lastCpuStats: ({})
    property real _lastCpuEnergy: -1
    property real _lastCpuEnergyTime: 0
    property var _cpuClocksByCore: ({})
    property real _lastGpuMetricsRequest: 0
    property bool _gpuStaticLoaded: false
    property int cpuDetailConsumers: 0
    property int gpuDetailConsumers: 0
    property int memoryDetailConsumers: 0
    property int diskDetailConsumers: 0
    
    property FileView cpuInfoFile: FileView { path: "/proc/cpuinfo"; blockLoading: true }
    property string cpuTempPath: ""
    property FileView cpuTempFile: FileView { path: cpuTempPath; blockLoading: true; printErrors: false }
    property string cpuPowerPath: ""
    property string cpuPowerSource: ""
    property real cpuPowerMaxEnergy: 0
    property FileView cpuPowerFile: FileView {
        path: cpuPowerPath
        printErrors: false
        onLoaded: root.processCpuPowerSample(text())
    }
    
    property string gpuDevicePath: ""
    property string gpuHwmonPath: ""
    property string gpuPath: ""
    property FileView gpuMemFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/mem_busy_percent" : ""; blockLoading: true; printErrors: false }
    property FileView gpuVcnFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/vcn_busy_percent" : ""; blockLoading: true; printErrors: false }
    property FileView gpuVramUsedFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/mem_info_vram_used" : ""; blockLoading: true; printErrors: false }
    property FileView gpuVramTotalFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/mem_info_vram_total" : ""; blockLoading: true; printErrors: false }
    property FileView gpuVisVramUsedFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/mem_info_vis_vram_used" : ""; blockLoading: true; printErrors: false }
    property FileView gpuVisVramTotalFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/mem_info_vis_vram_total" : ""; blockLoading: true; printErrors: false }
    property FileView gpuGttUsedFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/mem_info_gtt_used" : ""; blockLoading: true; printErrors: false }
    property FileView gpuGttTotalFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/mem_info_gtt_total" : ""; blockLoading: true; printErrors: false }
    property FileView gpuVramVendorFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/mem_info_vram_vendor" : ""; blockLoading: true; printErrors: false }
    property FileView gpuVbiosFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/vbios_version" : ""; blockLoading: true; printErrors: false }
    property FileView gpuPcieSpeedFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/current_link_speed" : ""; blockLoading: true; printErrors: false }
    property FileView gpuPcieWidthFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/current_link_width" : ""; blockLoading: true; printErrors: false }
    property FileView gpuPcieMaxSpeedFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/max_link_speed" : ""; blockLoading: true; printErrors: false }
    property FileView gpuPcieMaxWidthFile: FileView { path: gpuDevicePath ? gpuDevicePath + "/max_link_width" : ""; blockLoading: true; printErrors: false }
    property FileView gpuTempEdgeFile: FileView { path: gpuHwmonPath ? gpuHwmonPath + "/temp1_input" : ""; blockLoading: true; printErrors: false }
    property FileView gpuTempHotspotFile: FileView { path: gpuHwmonPath ? gpuHwmonPath + "/temp2_input" : ""; blockLoading: true; printErrors: false }
    property FileView gpuTempMemFile: FileView { path: gpuHwmonPath ? gpuHwmonPath + "/temp3_input" : ""; blockLoading: true; printErrors: false }
    property FileView gpuPowerFile: FileView { path: gpuHwmonPath ? gpuHwmonPath + "/power1_average" : ""; blockLoading: true; printErrors: false }
    property FileView gpuFanFile: FileView { path: gpuHwmonPath ? gpuHwmonPath + "/fan1_input" : ""; blockLoading: true; printErrors: false }
    property FileView gpuClockFile: FileView { path: gpuHwmonPath ? gpuHwmonPath + "/freq1_input" : ""; blockLoading: true; printErrors: false }
    property FileView gpuMemoryClockFile: FileView { path: gpuHwmonPath ? gpuHwmonPath + "/freq2_input" : ""; blockLoading: true; printErrors: false }
    property FileView gpuVoltageFile: FileView { path: gpuHwmonPath ? gpuHwmonPath + "/in0_input" : ""; blockLoading: true; printErrors: false }

    // --- Process Components ---
    property Process basicStatsCheck: Process {
        command: [
            "sh",
            "-c",
            "cat /proc/stat; printf '\\n---QS-STATS---\\n'; cat /proc/meminfo; printf '\\n---QS-STATS---\\n'; [ -n \"$1\" ] && [ -r \"$1\" ] && cat \"$1\" || true",
            "basic-stats",
            root.gpuPath
        ]
        stdout: StdioCollector {
            onStreamFinished: root.parseBasicStats(text)
        }
    }

    property Process cpuTempDiscovery: Process {
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do [ -f \"$h/name\" ] || continue; name=$(cat \"$h/name\"); if [ \"$name\" = \"k10temp\" ] || [ \"$name\" = \"coretemp\" ] || [ \"$name\" = \"zenpower\" ]; then for t in \"$h\"/temp*_input; do [ -f \"$t\" ] || continue; label=\"${t%_input}_label\"; if [ ! -f \"$label\" ] || grep -qiE \"package|tctl|tdie|die|cpu\" \"$label\"; then echo \"$t\"; exit 0; fi; done; fi; done; for z in /sys/class/thermal/thermal_zone*; do [ -f \"$z/type\" ] || continue; if grep -qiE \"x86_pkg_temp|cpu|k10temp|acpitz\" \"$z/type\"; then echo \"$z/temp\"; exit 0; fi; done"]
        stdout: SplitParser {
            onRead: (data) => {
                const path = data.trim();
                if (path) root.cpuTempPath = path;
            }
        }
    }

    property Process cpuPowerDiscovery: Process {
        command: ["sh", "-c",
            "for d in /sys/class/powercap/intel-rapl:*; do " +
            "[ -d \"$d\" ] || continue; " +
            "[ -f \"$d/name\" ] || continue; " +
            "[ -r \"$d/energy_uj\" ] || continue; " +
            "name=$(cat \"$d/name\"); " +
            "case \"$name\" in package*|Package*) max=0; [ -r \"$d/max_energy_range_uj\" ] && max=$(cat \"$d/max_energy_range_uj\"); echo \"energy|$d/energy_uj|$max\"; exit 0;; esac; " +
            "done; " +
            "for h in /sys/class/hwmon/hwmon*; do " +
            "[ -f \"$h/name\" ] || continue; " +
            "name=$(cat \"$h/name\"); " +
            "case \"$name\" in k10temp|coretemp|zenpower|fam15h_power|amd_energy) " +
            "for p in \"$h\"/power*_average \"$h\"/power*_input; do [ -r \"$p\" ] || continue; echo \"instant|$p|0\"; exit 0; done;; " +
            "esac; " +
            "done"
        ]
        stdout: SplitParser {
            onRead: (data) => {
                const parts = data.trim().split("|");
                if (parts.length < 2) return;
                root.cpuPowerSource = parts[0];
                root.cpuPowerPath = parts[1];
                root.cpuPowerMaxEnergy = parts.length >= 3 ? (parseInt(parts[2]) || 0) : 0;
                root._lastCpuEnergy = -1;
                root._lastCpuEnergyTime = 0;
            }
        }
    }

    property Process gpuDiscovery: Process {
        command: ["sh", "-c", "for d in /sys/class/drm/card*/device; do [ -r \"$d/gpu_busy_percent\" ] || continue; hw=\"\"; for h in \"$d\"/hwmon/hwmon*; do [ -r \"$h/name\" ] || continue; if grep -qx \"amdgpu\" \"$h/name\"; then hw=\"$h\"; break; fi; done; pci=$(basename \"$(readlink -f \"$d\" 2>/dev/null)\" 2>/dev/null); echo \"$d|$hw|$pci\"; exit 0; done"]
        stdout: SplitParser {
            onRead: (data) => {
                const parts = data.trim().split("|");
                if (!parts[0]) return;
                root.gpuDevicePath = parts[0];
                root.gpuHwmonPath = parts.length > 1 ? parts[1] : "";
                if (parts.length > 2 && parts[2]) root.gpuPci = parts[2];
                root.gpuPath = root.gpuDevicePath + "/gpu_busy_percent";
                root.gpuAvailable = true;
            }
        }
    }

    property Process gpuMetricsCheck: Process {
        // amdgpu_top -J streams forever by default; -n 1 makes it exit after one
        // snapshot so StdioCollector.onStreamFinished can fire and parse the JSON.
        command: ["sh", "-c", "command -v amdgpu_top >/dev/null 2>&1 && amdgpu_top -J -gm -n 1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.parseGpuMetrics(text)
        }
    }

    property Process diskCheck: Process {
        command: ["sh", "-c", "lsblk -b -J -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL,RM,MOUNTPOINTS,HOTPLUG,TRAN; echo '---SEP---'; df -h --output=target,size,used,pcent"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const sections = text.split("---SEP---");
                if (sections.length >= 2) {
                    parseDiskData(sections[0], sections[1]);
                }
            }
        }
    }

    property Process memHogCheck: Process {
        // Broaden ps command to get all processes for aggregation (RSS in KB)
        command: ["ps", "-eo", "comm,rss", "--no-headers"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.parseMemHogs(text)
        }
    }

    property Process gpuVramProcessCheck: Process {
        command: ["sh", "-c",
            "gpu_pci=\"$1\"; " +
            "find /proc/[0-9]*/fdinfo -type f -readable -print 2>/dev/null | " +
            "xargs -r awk -v pci=\"$gpu_pci\" '" +
            "function reset_fd() { driver=\"\"; pdev=\"\"; client=\"\"; vram=-1 } " +
            "function to_bytes(value, unit) { " +
            "if (value == \"\" || value !~ /^[0-9.]+$/) return -1; " +
            "if (unit == \"KiB\") return value * 1024; " +
            "if (unit == \"MiB\") return value * 1024 * 1024; " +
            "if (unit == \"GiB\") return value * 1024 * 1024 * 1024; " +
            "return value " +
            "} " +
            "function finish_fd() { " +
            "if (driver != \"amdgpu\" || vram <= 0 || (pci != \"\" && pdev != pci)) return; " +
            "split(FILENAME, path, \"/\"); " +
            "pid = path[3]; fd = path[5]; " +
            "key = pid \":\" (client != \"\" ? client : fd); " +
            "comm_path = \"/proc/\" pid \"/comm\"; name = \"\"; " +
            "if ((getline name < comm_path) <= 0) name = pid; " +
            "close(comm_path); " +
            "sub(/[[:space:]]+$/, \"\", name); " +
            "if (name == \"node-MainThread\") name = \"Gemini CLI\"; " +
            "if (name == \"\") name = pid; " +
            "printf \"%s\\t%.0f\\t%s\\n\", key, vram, name " +
            "} " +
            "FNR == 1 { if (NR > 1) finish_fd(); reset_fd() } " +
            "/^drm-driver:/ { driver = $2 } " +
            "/^drm-pdev:/ { pdev = $2 } " +
            "/^drm-client-id:/ { client = $2 } " +
            "/^drm-memory-vram:/ { vram = to_bytes($2, $3) } " +
            "/^drm-resident-vram:/ && vram < 0 { vram = to_bytes($2, $3) } " +
            "END { finish_fd() }' 2>/dev/null | " +
            "awk -F '\\t' '!seen[$1]++ { usage[$3]+=$2 } END { for (name in usage) printf \"%.0f|%s\\n\", usage[name], name }' | " +
            "sort -t '|' -k1,1nr | head -10",
            "gpu-vram-processes",
            root.gpuPci
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.parseGpuVramProcesses(text)
        }
    }

    function updateListModel(listModel, newArray) {
        for (let i = 0; i < newArray.length; i++) {
            const newItem = newArray[i];
            if (i < listModel.count) {
                const existing = listModel.get(i);
                if (existing.name !== newItem.name) listModel.setProperty(i, "name", newItem.name);
                if (existing.usage !== newItem.usage) listModel.setProperty(i, "usage", newItem.usage);
                if (existing.rss !== newItem.rss) listModel.setProperty(i, "rss", newItem.rss);
            } else {
                listModel.append(newItem);
            }
        }
        while (listModel.count > newArray.length) {
            listModel.remove(listModel.count - 1);
        }
    }

    function updateCpuCoreModel(newArray) {
        // Diff into a ListModel so per-core delegates are updated in place
        // instead of being destroyed and recreated on every poll.
        for (let i = 0; i < newArray.length; i++) {
            const newItem = newArray[i];
            if (i < cpuCoresModel.count) {
                const existing = cpuCoresModel.get(i);
                if (existing.name !== newItem.name) cpuCoresModel.setProperty(i, "name", newItem.name);
                if (existing.usage !== newItem.usage) cpuCoresModel.setProperty(i, "usage", newItem.usage);
                if (existing.clock !== newItem.clock) cpuCoresModel.setProperty(i, "clock", newItem.clock);
            } else {
                cpuCoresModel.append(newItem);
            }
        }
        while (cpuCoresModel.count > newArray.length) {
            cpuCoresModel.remove(cpuCoresModel.count - 1);
        }
    }

    function parseMemHogs(output) {
        if (!output) return;
        const lines = output.trim().split("\n");
        const aggregation = {};

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;
            const parts = line.split(/\s+/);
            if (parts.length >= 2) {
                let name = parts[0];
                const rss = parseInt(parts[1]) || 0;
                
                if (name === "node-MainThread") name = "Gemini CLI";
                
                if (aggregation[name]) {
                    aggregation[name] += rss;
                } else {
                    aggregation[name] = rss;
                }
            }
        }

        const hogs = Object.keys(aggregation).map(name => {
            const rss = aggregation[name];
            const usagePercent = root.memTotal > 0 ? (rss / root.memTotal) * 100 : 0;
            return { name: name, usage: usagePercent, rss: rss };
        });

        hogs.sort((a, b) => b.rss - a.rss);
        const topHogs = hogs.slice(0, 10);
        root.memHogs = topHogs;
        root.updateListModel(root.memHogsModel, topHogs);
    }

    function updateGpuVramProcessModel(newArray) {
        for (let i = 0; i < newArray.length; i++) {
            const newItem = newArray[i];
            if (i < gpuVramProcessesModel.count) {
                const existing = gpuVramProcessesModel.get(i);
                if (existing.name !== newItem.name) gpuVramProcessesModel.setProperty(i, "name", newItem.name);
                if (existing.usage !== newItem.usage) gpuVramProcessesModel.setProperty(i, "usage", newItem.usage);
                if (existing.bytes !== newItem.bytes) gpuVramProcessesModel.setProperty(i, "bytes", newItem.bytes);
            } else {
                gpuVramProcessesModel.append(newItem);
            }
        }
        while (gpuVramProcessesModel.count > newArray.length) {
            gpuVramProcessesModel.remove(gpuVramProcessesModel.count - 1);
        }
    }

    function parseGpuVramProcesses(output) {
        if (!output) {
            root.gpuVramProcesses = [];
            root.updateGpuVramProcessModel([]);
            return;
        }

        const lines = output.trim().split("\n");
        const processes = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;

            const separator = line.indexOf("|");
            if (separator < 0) continue;

            const bytes = parseFloat(line.substring(0, separator));
            const name = line.substring(separator + 1).trim();
            if (!name || isNaN(bytes) || bytes <= 0) continue;

            const usagePercent = root.gpuVramTotal > 0 ? (bytes / root.gpuVramTotal) * 100 : 0;
            processes.push({ name: name, usage: usagePercent, bytes: bytes });
        }

        processes.sort((a, b) => b.bytes - a.bytes);
        const topProcesses = processes.slice(0, 10);
        root.gpuVramProcesses = topProcesses;
        root.updateGpuVramProcessModel(topProcesses);
    }

    function parseDiskData(lsblkData, dfData) {
        if (!lsblkData || !dfData) return;
        const dfStats = {};
        const dfLines = dfData.trim().split("\n");
        for (let i = 1; i < dfLines.length; i++) {
            const parts = dfLines[i].trim().split(/\s+/);
            if (parts.length >= 4) {
                const mount = parts[0];
                dfStats[mount] = {
                    size: parts[1],
                    used: parts[2],
                    percent: parseInt(parts[3].replace("%", "")) || 0
                };
            }
        }
        let lsblkJson;
        try {
            lsblkJson = JSON.parse(lsblkData);
        } catch (e) { return; }
        if (!lsblkJson || !lsblkJson.blockdevices) return;
        const allDrives = [];
        let rootUsage = 0;
        for (let j = 0; j < lsblkJson.blockdevices.length; j++) {
            const dev = lsblkJson.blockdevices[j];
            if (dev.name.startsWith("loop") || dev.name.startsWith("ram") || dev.name.startsWith("zram")) continue;
            if (dev.type !== "disk") continue;
            const drive = {
                name: dev.name,
                size: formatBytes(dev.size),
                removable: !!(dev.rm || dev.hotplug || dev.tran === "usb"),
                partitions: []
            };
            const processNode = (node) => {
                let mounts = node.mountpoints || (node.mountpoint ? [node.mountpoint] : []);
                if (mounts.length > 0) {
                    mounts = mounts.filter(m => m && m !== "[SWAP]");
                    mounts.sort((a, b) => {
                        if (a === "/") return -1;
                        if (b === "/") return 1;
                        if (a === "/home") return -1;
                        if (b === "/home") return 1;
                        return a.length - b.length;
                    });
                    const mount = mounts[0];
                    if (mount) {
                        const stats = dfStats[mount];
                        if (stats) {
                            if (mount === "/") rootUsage = stats.percent;
                            drive.partitions.push({
                                name: node.name,
                                mount: mount,
                                label: node.label || node.name,
                                size: stats.size,
                                used: stats.used,
                                percent: stats.percent,
                                filesystem: node.fstype || "unknown"
                            });
                        }
                    }
                }
                if (node.children) {
                    for (let c = 0; c < node.children.length; c++) {
                        processNode(node.children[c]);
                    }
                }
            };
            processNode(dev);
            if (drive.partitions.length > 0) {
                allDrives.push(drive);
            }
        }
        allDrives.sort((a, b) => {
            const aIsSystem = a.partitions.some(p => p.mount === "/" || p.mount === "/home");
            const bIsSystem = b.partitions.some(p => p.mount === "/" || p.mount === "/home");
            if (aIsSystem !== bIsSystem) return aIsSystem ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
        root.drives = allDrives;
        root.diskUsage = rootUsage;
    }

    function formatBytes(bytes) {
        if (isNaN(bytes) || bytes === 0) return "0 B";
        const k = 1024;
        const sizes = ["B", "KB", "MB", "GB", "TB"];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
    }

    function readFileText(file) {
        if (!file.path) return "";
        file.reload();
        const content = file.text();
        return content ? content.trim() : "";
    }

    function readFileInt(file) {
        const content = readFileText(file);
        if (!content) return -1;
        const value = parseInt(content);
        return isNaN(value) ? -1 : value;
    }

    function clampPercent(value) {
        return Math.max(0, Math.min(100, Math.round(value)));
    }

    function percentFromBytes(used, total) {
        if (used < 0 || total <= 0) return -1;
        return clampPercent((used / total) * 100);
    }

    function normalizeTemp(raw) {
        if (raw < 0) return -1;
        return raw > 1000 ? Math.round(raw / 1000) : Math.round(raw);
    }

    function normalizePower(raw) {
        // hwmon power*_input/power*_average report microwatts (see ABI note in
        // processCpuPowerSample); magnitude guessing mis-scales idle readings.
        if (raw < 0) return -1;
        return Math.round((raw / 1000000) * 10) / 10;
    }

    function normalizeFreq(raw) {
        if (raw < 0) return -1;
        if (raw > 1000000) return Math.round(raw / 1000000);
        if (raw > 1000) return Math.round(raw / 1000);
        return Math.round(raw);
    }

    function firstNumber(values) {
        for (let i = 0; i < values.length; i++) {
            const value = values[i];
            if (value === null || value === undefined) continue;
            const numberValue = Number(value);
            if (!isNaN(numberValue)) return numberValue;
        }
        return -1;
    }

    function parseGpuMetrics(output) {
        if (!output) return;

        let parsed;
        try {
            parsed = JSON.parse(output.trim());
        } catch (e) {
            return;
        }

        if (!parsed || parsed.length === 0) return;

        let entry = parsed[0];
        for (let i = 0; i < parsed.length; i++) {
            const candidate = parsed[i];
            if (!candidate || !candidate.device_path) continue;
            if (!root.gpuPci || candidate.device_path.pci === root.gpuPci) {
                entry = candidate;
                break;
            }
        }

        const device = entry.device_path || {};
        const metrics = entry.gpu_metrics || {};

        if (device.DeviceName) root.gpuModel = device.DeviceName;
        if (device.pci) root.gpuPci = device.pci;

        root.gpuMetricsAvailable = true;
        root.gpuAvailable = true;

        const edgeTemp = firstNumber([metrics.temperature_edge]);
        const hotspotTemp = firstNumber([metrics.temperature_hotspot, metrics.temperature_gfx]);
        const memTemp = firstNumber([metrics.temperature_mem]);
        const vrGfxTemp = firstNumber([metrics.temperature_vrgfx]);
        const vrMemTemp = firstNumber([metrics.temperature_vrmem]);
        const vrSocTemp = firstNumber([metrics.temperature_vrsoc]);
        const power = firstNumber([
            metrics.average_socket_power,
            metrics.average_dgpu_power,
            metrics.average_gfx_power,
            metrics.average_core_power,
            metrics.average_apu_power
        ]);
        const gfxClock = firstNumber([metrics.average_gfxclk_frequency, metrics.current_gfxclk]);
        const memClock = firstNumber([metrics.average_uclk_frequency, metrics.current_uclk]);
        const socClock = firstNumber([metrics.current_socclk, metrics.average_socclk_frequency]);
        const videoClock = firstNumber([metrics.current_vclk, metrics.average_vclk_frequency]);
        const videoClock1 = firstNumber([metrics.current_vclk1, metrics.average_vclk1_frequency]);
        const gfxVoltage = firstNumber([metrics.voltage_gfx]);
        const memVoltage = firstNumber([metrics.voltage_mem]);
        const socVoltage = firstNumber([metrics.voltage_soc]);

        if (edgeTemp >= 0) root.gpuTempEdge = Math.round(edgeTemp);
        if (hotspotTemp >= 0) root.gpuTempHotspot = Math.round(hotspotTemp);
        if (memTemp >= 0) root.gpuTempMem = Math.round(memTemp);
        if (vrGfxTemp >= 0) root.gpuTempVrGfx = Math.round(vrGfxTemp);
        if (vrMemTemp >= 0) root.gpuTempVrMem = Math.round(vrMemTemp);
        if (vrSocTemp >= 0) root.gpuTempVrSoc = Math.round(vrSocTemp);
        if (power >= 0) root.gpuPower = Math.round(power * 10) / 10;
        if (gfxClock >= 0) root.gpuClock = Math.round(gfxClock);
        if (memClock >= 0) root.gpuMemoryClock = Math.round(memClock);
        if (socClock >= 0) root.gpuSocClock = Math.round(socClock);
        if (videoClock >= 0) root.gpuVideoClock = Math.round(videoClock);
        if (videoClock1 >= 0) root.gpuVideoClock1 = Math.round(videoClock1);
        if (gfxVoltage >= 0) root.gpuVoltage = Math.round(gfxVoltage);
        if (memVoltage >= 0) root.gpuMemVoltage = Math.round(memVoltage);
        if (socVoltage >= 0) root.gpuSocVoltage = Math.round(socVoltage);
        if (metrics.pcie_link_width !== null && metrics.pcie_link_width !== undefined) {
            root.gpuPcieWidth = String(metrics.pcie_link_width);
        }

        const throttleStatus = metrics["Throttle Status"];
        if (Array.isArray(throttleStatus)) {
            root.gpuThrottleStatus = throttleStatus.length > 0 ? throttleStatus.join(", ") : "None";
        }
    }

    Component.onCompleted: {
        cpuTempDiscovery.running = true;
        cpuPowerDiscovery.running = true;
        gpuDiscovery.running = true;
    }

    function updateStats() {
        if (!basicStatsCheck.running)
            basicStatsCheck.running = true;
    }

    function parseBasicStats(output) {
        const sections = output.split("---QS-STATS---");
        if (sections.length < 2)
            return;
        updateCpu(sections[0]);
        updateMem(sections[1]);
        updateGpuBasic(sections.length > 2 ? sections[2] : "");
    }

    function acquireCpuDetails() {
        if (cpuDetailConsumers === 0) {
            _lastCpuEnergy = -1;
            _lastCpuEnergyTime = 0;
            cpuPower = -1;
        }
        cpuDetailConsumers++;
        updateCpuDetails();
    }

    function releaseCpuDetails() {
        cpuDetailConsumers = Math.max(0, cpuDetailConsumers - 1);
    }

    function acquireGpuDetails() {
        gpuDetailConsumers++;
        updateGpuDetails();
        updateGpuVramProcesses();
    }

    function releaseGpuDetails() {
        gpuDetailConsumers = Math.max(0, gpuDetailConsumers - 1);
    }

    function acquireMemoryDetails() {
        memoryDetailConsumers++;
        updateMemHogs();
    }

    function releaseMemoryDetails() {
        memoryDetailConsumers = Math.max(0, memoryDetailConsumers - 1);
    }

    function acquireDiskDetails() {
        diskDetailConsumers++;
        updateDisk();
    }

    function releaseDiskDetails() {
        diskDetailConsumers = Math.max(0, diskDetailConsumers - 1);
    }

    function updateCpuDetails() {
        updateCpuInfo();
        updateCpuTemp();
        updateCpuPower();
    }

    function updateDisk() {
        if (!diskCheck.running) diskCheck.running = true;
    }

    function updateCpuInfo() {
        cpuInfoFile.reload();
        const content = cpuInfoFile.text();
        if (!content) return;

        const sections = content.trim().split(/\n\s*\n/);
        const clocks = {};
        let model = "";
        let totalClock = 0;
        let clockCount = 0;

        for (let i = 0; i < sections.length; i++) {
            const lines = sections[i].split("\n");
            let processor = -1;
            let clock = -1;

            for (let j = 0; j < lines.length; j++) {
                const separator = lines[j].indexOf(":");
                if (separator < 0) continue;

                const key = lines[j].substring(0, separator).trim();
                const value = lines[j].substring(separator + 1).trim();

                if (key === "processor") {
                    processor = parseInt(value);
                } else if (key === "model name" && !model) {
                    model = value;
                } else if (key === "cpu MHz") {
                    clock = parseFloat(value);
                }
            }

            if (processor >= 0 && clock >= 0) {
                clocks[processor] = Math.round(clock);
                totalClock += clock;
                clockCount++;
            }
        }

        if (model) cpuModel = model;
        if (clockCount > 0) cpuClock = Math.round(totalClock / clockCount);
        _cpuClocksByCore = clocks;
    }

    function updateMemHogs() {
        if (!memHogCheck.running) memHogCheck.running = true;
    }

    function updateGpuVramProcesses() {
        if (gpuPci && !gpuVramProcessCheck.running) gpuVramProcessCheck.running = true;
    }

    function updateCpu(content) {
        if (!content) return;
        const lines = content.split("\n");
        const nextStats = {};
        const cores = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line.startsWith("cpu")) continue;

            const parts = line.split(/\s+/);
            const name = parts[0];
            if (name !== "cpu" && !name.match(/^cpu\d+$/)) continue;

            let total = 0;
            for (let p = 1; p < parts.length; p++) {
                total += parseInt(parts[p]) || 0;
            }

            const idle = (parseInt(parts[4]) || 0) + (parseInt(parts[5]) || 0);
            const previous = _lastCpuStats[name];
            let usage = 0;

            if (previous) {
                const diffTotal = total - previous.total;
                const diffIdle = idle - previous.idle;
                if (diffTotal > 0) {
                    usage = Math.max(0, Math.min(100, Math.floor(((diffTotal - diffIdle) / diffTotal) * 100)));
                }
            }

            nextStats[name] = { total: total, idle: idle };

            if (name === "cpu") {
                cpuUsage = usage;
            } else {
                const index = parseInt(name.substring(3));
                const clock = _cpuClocksByCore[index] !== undefined ? _cpuClocksByCore[index] : -1;
                cores.push({ name: "Core " + index, usage: usage, clock: clock });
            }
        }

        _lastCpuStats = nextStats;
        cpuCores = cores;
        updateCpuCoreModel(cores);
    }

    function updateCpuTemp() {
        if (!cpuTempPath) return;
        cpuTempFile.reload();
        const content = cpuTempFile.text();
        if (!content) return;
        const raw = parseInt(content.trim());
        if (isNaN(raw)) return;
        cpuTemp = raw > 1000 ? Math.round(raw / 1000) : raw;
    }

    function updateCpuPower() {
        if (!cpuPowerPath) return;
        cpuPowerFile.reload();
    }

    function processCpuPowerSample(content) {
        if (cpuDetailConsumers <= 0) return;
        if (!content) return;
        const raw = parseInt(content.trim());
        if (isNaN(raw)) return;

        if (cpuPowerSource === "energy") {
            const now = Date.now();
            if (_lastCpuEnergy >= 0 && _lastCpuEnergyTime > 0) {
                let diffEnergy = raw - _lastCpuEnergy;
                if (diffEnergy < 0 && cpuPowerMaxEnergy > 0) {
                    diffEnergy = (cpuPowerMaxEnergy - _lastCpuEnergy) + raw;
                }

                const seconds = (now - _lastCpuEnergyTime) / 1000;
                if (diffEnergy >= 0 && seconds > 0) {
                    cpuPower = Math.round((diffEnergy / seconds / 1000000) * 10) / 10;
                }
            }

            _lastCpuEnergy = raw;
            _lastCpuEnergyTime = now;
            return;
        }

        // The hwmon ABI reports power*_input and power*_average in microwatts.
        const watts = raw / 1000000;
        cpuPower = Math.round(watts * 10) / 10;
    }

    function updateMem(content) {
        if (!content) return;
        const lines = content.split("\n");
        let total = 0;
        let available = 0;
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.startsWith("MemTotal:")) {
                const match = line.match(/MemTotal:\s+(\d+)/);
                if (match) total = parseInt(match[1]);
            } else if (line.startsWith("MemAvailable:")) {
                const match = line.match(/MemAvailable:\s+(\d+)/);
                if (match) available = parseInt(match[1]);
            }
        }
        if (total > 0) {
            memTotal = total;
            if (available > 0) {
                const used = total - available;
                memUsage = Math.max(0, Math.min(100, Math.floor((used / total) * 100)));
            }
        }
    }

    function updateGpuBasic(content) {
        const load = parseInt(String(content || "").trim());
        if (load >= 0) {
            gpuUsage = clampPercent(load);
            gpuAvailable = true;
        }
    }

    function updateGpuDetails() {
        const memBusy = readFileInt(gpuMemFile);
        if (memBusy >= 0) gpuMemUsage = clampPercent(memBusy);

        const vcnBusy = readFileInt(gpuVcnFile);
        if (vcnBusy >= 0) gpuVcnUsage = clampPercent(vcnBusy);

        const vramUsed = readFileInt(gpuVramUsedFile);
        const vramTotal = readFileInt(gpuVramTotalFile);
        if (vramUsed >= 0) gpuVramUsed = vramUsed;
        if (vramTotal >= 0) gpuVramTotal = vramTotal;
        gpuVramUsage = percentFromBytes(gpuVramUsed, gpuVramTotal);

        const visVramUsed = readFileInt(gpuVisVramUsedFile);
        const visVramTotal = readFileInt(gpuVisVramTotalFile);
        if (visVramUsed >= 0) gpuVisVramUsed = visVramUsed;
        if (visVramTotal >= 0) gpuVisVramTotal = visVramTotal;
        gpuVisVramUsage = percentFromBytes(gpuVisVramUsed, gpuVisVramTotal);

        const gttUsed = readFileInt(gpuGttUsedFile);
        const gttTotal = readFileInt(gpuGttTotalFile);
        if (gttUsed >= 0) gpuGttUsed = gttUsed;
        if (gttTotal >= 0) gpuGttTotal = gttTotal;
        gpuGttUsage = percentFromBytes(gpuGttUsed, gpuGttTotal);

        if (!_gpuStaticLoaded && gpuDevicePath) {
            const vramVendor = readFileText(gpuVramVendorFile);
            if (vramVendor) gpuVramVendor = vramVendor.toUpperCase();

            const vbios = readFileText(gpuVbiosFile);
            if (vbios) gpuVbiosVersion = vbios;

            const pcieMaxSpeed = readFileText(gpuPcieMaxSpeedFile);
            if (pcieMaxSpeed) gpuPcieMaxSpeed = pcieMaxSpeed;

            const pcieMaxWidth = readFileText(gpuPcieMaxWidthFile);
            if (pcieMaxWidth) gpuPcieMaxWidth = pcieMaxWidth;

            _gpuStaticLoaded = true;
        }

        const pcieSpeed = readFileText(gpuPcieSpeedFile);
        if (pcieSpeed) gpuPcieSpeed = pcieSpeed;

        const pcieWidth = readFileText(gpuPcieWidthFile);
        if (pcieWidth) gpuPcieWidth = pcieWidth;

        const fan = readFileInt(gpuFanFile);
        if (fan >= 0) gpuFanRpm = fan;

        if (!gpuMetricsAvailable) {
            const edgeTemp = readFileInt(gpuTempEdgeFile);
            const hotspotTemp = readFileInt(gpuTempHotspotFile);
            const memTemp = readFileInt(gpuTempMemFile);
            const power = readFileInt(gpuPowerFile);
            const clock = readFileInt(gpuClockFile);
            const memClock = readFileInt(gpuMemoryClockFile);
            const voltage = readFileInt(gpuVoltageFile);

            if (edgeTemp >= 0) gpuTempEdge = normalizeTemp(edgeTemp);
            if (hotspotTemp >= 0) gpuTempHotspot = normalizeTemp(hotspotTemp);
            if (memTemp >= 0) gpuTempMem = normalizeTemp(memTemp);
            if (power >= 0) gpuPower = normalizePower(power);
            if (clock >= 0) gpuClock = normalizeFreq(clock);
            if (memClock >= 0) gpuMemoryClock = normalizeFreq(memClock);
            if (voltage >= 0) gpuVoltage = voltage;
        }

        const now = Date.now();
        if (!gpuMetricsCheck.running && now - _lastGpuMetricsRequest >= 15000) {
            _lastGpuMetricsRequest = now;
            gpuMetricsCheck.running = true;
        }
    }

    property Timer pollTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateStats()
    }

    property Timer diskTimer: Timer {
        interval: 60000
        running: root.diskDetailConsumers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateDisk()
    }

    // Hardware can appear after boot (driver load, hotplug); re-run the cheap
    // discovery probes until each path is resolved instead of giving up once.
    property Timer discoveryRetryTimer: Timer {
        interval: 30000
        running: !root.cpuTempPath || !root.cpuPowerPath || !root.gpuDevicePath
        repeat: true
        onTriggered: {
            if (!root.cpuTempPath && !root.cpuTempDiscovery.running) root.cpuTempDiscovery.running = true;
            if (!root.cpuPowerPath && !root.cpuPowerDiscovery.running) root.cpuPowerDiscovery.running = true;
            if (!root.gpuDevicePath && !root.gpuDiscovery.running) root.gpuDiscovery.running = true;
        }
    }

    property Timer detailTimer: Timer {
        interval: 5000
        running: root.cpuDetailConsumers > 0 || root.gpuDetailConsumers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.cpuDetailConsumers > 0)
                root.updateCpuDetails();
            if (root.gpuDetailConsumers > 0)
                root.updateGpuDetails();
        }
    }

    property Timer memHogTimer: Timer {
        interval: 30000
        running: root.memoryDetailConsumers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateMemHogs()
    }

    property Timer gpuVramProcessTimer: Timer {
        interval: 30000
        running: root.gpuDetailConsumers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateGpuVramProcesses()
    }
}
