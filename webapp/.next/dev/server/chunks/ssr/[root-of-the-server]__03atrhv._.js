module.exports = [
"[externals]/next/dist/compiled/next-server/app-page-turbo.runtime.dev.js [external] (next/dist/compiled/next-server/app-page-turbo.runtime.dev.js, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("next/dist/compiled/next-server/app-page-turbo.runtime.dev.js", () => require("next/dist/compiled/next-server/app-page-turbo.runtime.dev.js"));

module.exports = mod;
}),
"[externals]/next/dist/server/app-render/action-async-storage.external.js [external] (next/dist/server/app-render/action-async-storage.external.js, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("next/dist/server/app-render/action-async-storage.external.js", () => require("next/dist/server/app-render/action-async-storage.external.js"));

module.exports = mod;
}),
"[externals]/next/dist/server/app-render/work-unit-async-storage.external.js [external] (next/dist/server/app-render/work-unit-async-storage.external.js, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("next/dist/server/app-render/work-unit-async-storage.external.js", () => require("next/dist/server/app-render/work-unit-async-storage.external.js"));

module.exports = mod;
}),
"[externals]/next/dist/server/app-render/work-async-storage.external.js [external] (next/dist/server/app-render/work-async-storage.external.js, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("next/dist/server/app-render/work-async-storage.external.js", () => require("next/dist/server/app-render/work-async-storage.external.js"));

module.exports = mod;
}),
"[project]/lib/pantheon.ts [app-ssr] (ecmascript)", ((__turbopack_context__) => {
"use strict";

// THE PANTHEON — 11-daemon modular intelligence registry.
// Per the Non-Destructive Mandate, all scanners/monitors default to "disabled"
// and require an explicit opt-in (config.ini) by the creator.
__turbopack_context__.s([
    "PANTHEON",
    ()=>PANTHEON,
    "STATUS_META",
    ()=>STATUS_META
]);
const PANTHEON = [
    {
        id: "odin",
        name: "Odin",
        role: "Allfather / Orchestrator",
        description: "Supervises the daemon hierarchy and arbitrates authority tokens.",
        defaultStatus: "online",
        destructive: false
    },
    {
        id: "leviathan",
        name: "Leviathan",
        role: "Command Hierarchy",
        description: "Maps the Pantheon into the Leviathan start menu tree.",
        defaultStatus: "online",
        destructive: false
    },
    {
        id: "heimdall",
        name: "Heimdall",
        role: "Gatekeeper / Sanitizer",
        description: "Heuristic regex inspection of all inbound commands (CWE-77).",
        defaultStatus: "online",
        destructive: false
    },
    {
        id: "thor",
        name: "Thor",
        role: "Throughput / Rate Limiter",
        description: "Redis-backed DDoS and rate-limiting middleware hammer.",
        defaultStatus: "idle",
        destructive: false
    },
    {
        id: "loki",
        name: "Loki",
        role: "Chaos / Fuzzer",
        description: "Fault-injection and fuzzing harness. Opt-in only.",
        defaultStatus: "disabled",
        destructive: true
    },
    {
        id: "mjolnir",
        name: "Mjolnir",
        role: "Enforcement",
        description: "Applies quarantine verdicts and revokes compromised sessions.",
        defaultStatus: "idle",
        destructive: true
    },
    {
        id: "fenrir",
        name: "Fenrir",
        role: "Active Scanner",
        description: "Aggressive port + surface scanner. Disabled by default.",
        defaultStatus: "disabled",
        destructive: true
    },
    {
        id: "sleipnir",
        name: "Sleipnir",
        role: "Transport Mesh",
        description: "Eight-legged gRPC/IPC courier between host and edge.",
        defaultStatus: "online",
        destructive: false
    },
    {
        id: "demogorgon",
        name: "Demogorgon",
        role: "TCP Tarpit Honeypot",
        port: 2222,
        description: "Multi-threaded tarpit on :2222 that ensnares intruders. Opt-in.",
        defaultStatus: "disabled",
        destructive: true
    },
    {
        id: "jormungandr",
        name: "Jörmungandr",
        role: "Quarantine Gateway",
        description: "System isolation gateway that coils around flagged processes.",
        defaultStatus: "idle",
        destructive: true
    },
    {
        id: "ginnungagap",
        name: "Ginnungagap",
        role: "Autonomous Sentinel",
        description: "Systemd-registered void watcher with heartbeat persistence.",
        defaultStatus: "online",
        destructive: false
    }
];
const STATUS_META = {
    online: {
        label: "ONLINE",
        tone: "aurora"
    },
    idle: {
        label: "IDLE",
        tone: "muted"
    },
    disabled: {
        label: "DISABLED",
        tone: "warn"
    },
    alert: {
        label: "ALERT",
        tone: "alert"
    }
};
}),
"[project]/lib/store/telemetry-slice.ts [app-ssr] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "default",
    ()=>__TURBOPACK__default__export__,
    "pushEvent",
    ()=>pushEvent,
    "setBridge",
    ()=>setBridge,
    "setDaemonStatus",
    ()=>setDaemonStatus,
    "tick",
    ()=>tick
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f40$reduxjs$2f$toolkit$2f$dist$2f$redux$2d$toolkit$2e$modern$2e$mjs__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/node_modules/@reduxjs/toolkit/dist/redux-toolkit.modern.mjs [app-ssr] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$pantheon$2e$ts__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/lib/pantheon.ts [app-ssr] (ecmascript)");
;
;
const seededAt = Date.now();
const initialState = {
    daemons: __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$pantheon$2e$ts__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__["PANTHEON"].reduce((acc, d)=>{
        acc[d.id] = {
            id: d.id,
            // Non-destructive mandate: scanners/monitors keep their registry default.
            status: d.defaultStatus,
            cpu: d.defaultStatus === "online" ? 4 : 0,
            mem: d.defaultStatus === "online" ? 12 : 0,
            threads: d.id === "demogorgon" ? 0 : d.defaultStatus === "online" ? 4 : 1,
            lastHeartbeat: seededAt,
            events: 0
        };
        return acc;
    }, {}),
    feed: [],
    bridge: "connected",
    threatLevel: 0
};
const telemetrySlice = (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f40$reduxjs$2f$toolkit$2f$dist$2f$redux$2d$toolkit$2e$modern$2e$mjs__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__$3c$locals$3e$__["createSlice"])({
    name: "telemetry",
    initialState,
    reducers: {
        tick (state, action) {
            for (const d of action.payload.daemons){
                state.daemons[d.id] = d;
            }
            state.threatLevel = action.payload.threatLevel;
        },
        pushEvent (state, action) {
            state.feed.unshift(action.payload);
            if (state.feed.length > 60) state.feed.pop();
            const d = state.daemons[action.payload.daemon];
            if (d) d.events += 1;
        },
        setDaemonStatus (state, action) {
            const d = state.daemons[action.payload.id];
            if (d) {
                d.status = action.payload.status;
                if (action.payload.status === "disabled") {
                    d.cpu = 0;
                    d.mem = 0;
                }
            }
        },
        setBridge (state, action) {
            state.bridge = action.payload;
        }
    }
});
const { tick, pushEvent, setDaemonStatus, setBridge } = telemetrySlice.actions;
const __TURBOPACK__default__export__ = telemetrySlice.reducer;
}),
"[project]/components/store-provider.tsx [app-ssr] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "StoreProvider",
    ()=>StoreProvider,
    "makeStore",
    ()=>makeStore
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$server$2f$route$2d$modules$2f$app$2d$page$2f$vendored$2f$ssr$2f$react$2d$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/node_modules/next/dist/server/route-modules/app-page/vendored/ssr/react-jsx-dev-runtime.js [app-ssr] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$server$2f$route$2d$modules$2f$app$2d$page$2f$vendored$2f$ssr$2f$react$2e$js__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/node_modules/next/dist/server/route-modules/app-page/vendored/ssr/react.js [app-ssr] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f40$reduxjs$2f$toolkit$2f$dist$2f$redux$2d$toolkit$2e$modern$2e$mjs__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/node_modules/@reduxjs/toolkit/dist/redux-toolkit.modern.mjs [app-ssr] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$react$2d$redux$2f$dist$2f$react$2d$redux$2e$mjs__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/node_modules/react-redux/dist/react-redux.mjs [app-ssr] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$store$2f$telemetry$2d$slice$2e$ts__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/lib/store/telemetry-slice.ts [app-ssr] (ecmascript)");
"use client";
;
;
;
;
;
function makeStore() {
    return (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f40$reduxjs$2f$toolkit$2f$dist$2f$redux$2d$toolkit$2e$modern$2e$mjs__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__$3c$locals$3e$__["configureStore"])({
        reducer: {
            telemetry: __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$store$2f$telemetry$2d$slice$2e$ts__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__["default"]
        }
    });
}
function StoreProvider({ children }) {
    const storeRef = (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$server$2f$route$2d$modules$2f$app$2d$page$2f$vendored$2f$ssr$2f$react$2e$js__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__["useRef"])(null);
    if (!storeRef.current) {
        storeRef.current = makeStore();
    }
    return /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$server$2f$route$2d$modules$2f$app$2d$page$2f$vendored$2f$ssr$2f$react$2d$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__["jsxDEV"])(__TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$react$2d$redux$2f$dist$2f$react$2d$redux$2e$mjs__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__["Provider"], {
        store: storeRef.current,
        children: children
    }, void 0, false, {
        fileName: "[project]/components/store-provider.tsx",
        lineNumber: 26,
        columnNumber: 10
    }, this);
}
}),
"[externals]/next/dist/server/app-render/after-task-async-storage.external.js [external] (next/dist/server/app-render/after-task-async-storage.external.js, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("next/dist/server/app-render/after-task-async-storage.external.js", () => require("next/dist/server/app-render/after-task-async-storage.external.js"));

module.exports = mod;
}),
"[externals]/next/dist/server/app-render/dynamic-access-async-storage.external.js [external] (next/dist/server/app-render/dynamic-access-async-storage.external.js, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("next/dist/server/app-render/dynamic-access-async-storage.external.js", () => require("next/dist/server/app-render/dynamic-access-async-storage.external.js"));

module.exports = mod;
}),
];

//# sourceMappingURL=%5Broot-of-the-server%5D__03atrhv._.js.map