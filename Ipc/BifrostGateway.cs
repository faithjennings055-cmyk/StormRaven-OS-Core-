using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Security.Cryptography;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using StormRaven.Kernel.Contracts;
using StormRaven.Kernel.Kernel;
using StormRaven.Kernel.Providers;
using StormRaven.Kernel.Storage;

namespace StormRaven.Kernel.Ipc
{
    /// <summary>
    /// Bifrost Gateway — the mobile bridge of StormRaven OS.
    ///
    /// The kernel's classic IPC surface is a Windows named pipe (PipeServer), which is
    /// unreachable from other devices. Bifrost exposes the same kernel over HTTP + WebSocket
    /// so a remote companion (e.g. the StormRaven iOS app) can:
    ///
    ///   GET  /health                  kernel status, uptime, versions, counters
    ///   GET  /state                   latest NormalizedState snapshot
    ///   GET  /tabs                    tabs from the Edge-tabs provider (last ingested)
    ///   POST /tabs                    ingest raw Edge tab data -> normalize -> evaluate
    ///   GET  /decisions               recent decision-engine output (latest first)
    ///   POST /decisions/evaluate      evaluate a caller-supplied NormalizedState
    ///   POST /commands                trigger a kernel command ({"intent": "...", "target": "..."})
    ///   GET  /signals                 recent signal envelopes
    ///   WS   /ws                      live event stream (hello, health.tick, decision, signal, tab events)
    ///
    /// All responses share the envelope: { "ok": true, "kernel": {...}, "data": ... }.
    /// JSON naming is camelCase to match Swift's JSONDecoder defaults.
    /// </summary>
    public sealed class BifrostGateway
    {
        // ---- gateway configuration -------------------------------------------
        public const int DefaultPort = 8787;
        public const string Version = "1.0.0";

        // ---- zero-trust auth (Heimdall gate) ----------------------------------
        // Every request must present a bearer token matching the gateway token.
        // Configure via STORMRAVEN_GATEWAY_TOKEN (required in production); when
        // unset the gateway refuses to serve unauthenticated traffic.
        private static readonly string? _authToken =
            Environment.GetEnvironmentVariable("STORMRAVEN_GATEWAY_TOKEN");

        private static bool Authorized(HttpListenerRequest req)
        {
            if (string.IsNullOrEmpty(_authToken)) return false; // fail closed
            var header = req.Headers["Authorization"] ?? "";
            var provided = header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                ? header.Substring("Bearer ".Length).Trim()
                : (req.Headers["X-StormRaven-Token"] ?? "").Trim();
            if (provided.Length == 0) return false;
            return CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(provided), Encoding.UTF8.GetBytes(_authToken));
        }

        private static readonly JsonSerializerOptions JsonOpts = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        // ---- shared kernel state (single-instance gateway) --------------------
        private static readonly object StateLock = new();
        private static NormalizedState _lastState = new();
        private static readonly List<TabInfo> _tabs = new();
        private static readonly ConcurrentQueue<SignalEnvelope> _signals = new();
        private static readonly ConcurrentQueue<Decision> _decisions = new();
        
        private static readonly List<WebSocket> _sockets = new();
        private static readonly HashSet<string> _commandLog = new();
        private static long _signalCount;
        private static long _commandCount;
        private static DateTime _startedUtc = DateTime.UtcNow;

        private static StormRavenDb? _dbStatic;
        private HttpListener _listener = null!;
        private CancellationTokenSource _cts = new();
        private readonly StormRavenDb? _db;
        private readonly string _schemaSql;
        private readonly int _port;

        public BifrostGateway(int port = DefaultPort, StormRavenDb? db = null, string? schemaSql = null)
        {
            _port = port;
            _db = db;
            _dbStatic = db;
            _schemaSql = schemaSql ?? "";
        }

        /// <summary>A tab as reported by the Edge-tabs provider (camelCase on the wire).</summary>
        public sealed class TabInfo
        {
            public string Id { get; set; } = Guid.NewGuid().ToString("N")[..8];
            public string Title { get; set; } = "";
            public string Url { get; set; } = "";
            public bool IsCurrent { get; set; }
            public bool IsAudible { get; set; }
            public DateTime UpdatedUtc { get; set; } = DateTime.UtcNow;
        }

        // ---- lifecycle ---------------------------------------------------------
        public void Start()
        {
            if (_db != null && !string.IsNullOrWhiteSpace(_schemaSql))
                _db.EnsureSchema(_schemaSql);

            _listener = new HttpListener();
            try
            {
                // Attempt universal binding (0.0.0.0 / +) to make it accessible to all platforms on the LAN
                _listener.Prefixes.Add($"http://+:{_port}/");
                _listener.Start();
            }
            catch (HttpListenerException)
            {
                _listener.Close();
                // Fallback for Linux/macOS where '*' is the standard wildcard
                try
                {
                    _listener = new HttpListener();
                    _listener.Prefixes.Add($"http://*:{_port}/");
                    _listener.Start();
                }
                catch
                {
                    _listener.Close();
                    // Final fallback to loopback if all else fails
                    _listener = new HttpListener();
                    _listener.Prefixes.Add($"http://127.0.0.1:{_port}/");
                    _listener.Start();
                }
            }

            var t = new Thread(ListenLoop) { IsBackground = true, Name = "BifrostGateway" };
            t.Start();

            // heartbeat: broadcasts health.tick over every open WebSocket every 15 s
            var hb = new Task(() =>
            {
                while (!_cts.IsCancellationRequested)
                {
                    try { BroadcastAsync("health.tick", HealthPayload()).Wait(2000, _cts.Token); }
                    catch { /* listener shutting down */ }
                    try { Task.Delay(15000, _cts.Token).Wait(_cts.Token); }
                    catch (OperationCanceledException) { break; }
                }
            }, _cts.Token);
            hb.Start();
        }

        public void Stop()
        {
            try { _cts.Cancel(); } catch { }
            try { _listener.Stop(); } catch { }
        }

        // ---- accept loop --------------------------------------------------------
        private void ListenLoop()
        {
            while (!_cts.IsCancellationRequested)
            {
                HttpListenerContext ctx;
                try { ctx = _listener.GetContext(); }
                catch (Exception) { break; } // listener stopped

                Task.Run(() => Handle(ctx), _cts.Token);
            }
        }

        private async Task Handle(HttpListenerContext ctx)
        {
            var raw = ctx.Request.Url?.AbsolutePath ?? "/";
            try
            {
                if (ctx.Request.IsWebSocketRequest && raw == "/ws")
                {
                    // WebSocket handshake: Authorization headers are unreliable in
                    // browsers pre-connect, so /ws accepts ?token=<tok> OR a Bearer
                    // header. The gate runs here, before accepting the socket.
                    var qsToken = ctx.Request.QueryString["token"] ?? "";
                    if (qsToken.Length == 0 && !Authorized(ctx.Request))
                    {
                        ctx.Response.StatusCode = 401;
                        try { await WriteJson(ctx, Error("unauthorized", "missing or invalid gateway token"), 401); }
                        catch { ctx.Response.Close(); }
                        return;
                    }
                    if (qsToken.Length > 0)
                    {
                        if (string.IsNullOrEmpty(_authToken) || !CryptographicOperations.FixedTimeEquals(
                                Encoding.UTF8.GetBytes(qsToken),
                                Encoding.UTF8.GetBytes(_authToken)))
                        {
                            ctx.Response.StatusCode = 401;
                            try { await WriteJson(ctx, Error("unauthorized", "invalid gateway token"), 401); }
                            catch { ctx.Response.Close(); }
                            return;
                        }
                    }
                    var wsCtx = await ctx.AcceptWebSocketAsync(null);
                    await HandleSocket(wsCtx.WebSocket);
                    return;
                }

                // Zero-trust gate for plain HTTP routes: reject unauthenticated
                // callers (401 + WWW-Authenticate) before dispatch.
                if (!Authorized(ctx.Request))
                {
                    ctx.Response.StatusCode = 401;
                    ctx.Response.Headers["WWW-Authenticate"] = "Bearer realm=\"stormraven-bifrost\"";
                    try { await WriteJson(ctx, Error("unauthorized", "missing or invalid gateway token"), 401); }
                    catch { ctx.Response.Close(); }
                    return;
                }

                switch ((ctx.Request.HttpMethod, raw))
                {
                    case ("GET", "/") or ("GET", "/health"):
                        await WriteJson(ctx, Ok(HealthPayload()));
                        break;
                    case ("GET", "/state"):
                        await WriteJson(ctx, Ok(StatePayload()));
                        break;
                    case ("GET", "/tabs"):
                        await WriteJson(ctx, Ok(TabsPayload()));
                        break;
                    case ("POST", "/tabs"):
                        await HandleTabIngest(ctx);
                        break;
                    case ("GET", "/decisions"):
                        await WriteJson(ctx, Ok(DecisionsPayload()));
                        break;
                    case ("POST", "/decisions/evaluate"):
                        await HandleEvaluate(ctx);
                        break;
                    case ("POST", "/commands"):
                        await HandleCommand(ctx);
                        break;
                    // Mobile (MAUI) clients call /command + /status — accept both
                    // spellings so existing mobile builds keep working.
                    case ("POST", "/command"):
                        await HandleCommand(ctx);
                        break;
                    case ("GET", "/status"):
                        await WriteJson(ctx, Ok(HealthPayload()));
                        break;
                    case ("GET", "/signals"):
                        await WriteJson(ctx, Ok(SignalsPayload()));
                        break;
                    default:
                        await WriteJson(ctx, Error("not_found", $"no route for {ctx.Request.HttpMethod} {raw}"), 404);
                        break;
                }
            }
            catch (Exception ex)
            {
                try { await WriteJson(ctx, Error("internal_error", ex.Message), 500); } catch { }
            }
        }

        // ---- route handlers ------------------------------------------------------

        private async Task HandleTabIngest(HttpListenerContext ctx)
        {
            using var reader = new StreamReader(ctx.Request.InputStream, Encoding.UTF8);
            var body = await reader.ReadToEndAsync();

            List<TabInfo>? incoming;
            try { incoming = JsonSerializer.Deserialize<List<TabInfo>>(body, JsonOpts); }
            catch { incoming = null; }
            if (incoming is null)
            {
                await WriteJson(ctx, Error("bad_request", "body must be a JSON array of tabs"), 400);
                return;
            }

            lock (StateLock)
            {
                _tabs.Clear();
                _tabs.AddRange(incoming);
                _lastState.Focus.Attention = incoming.Count > 0 ? "focused" : "idle";
                _lastState.Focus.ForegroundActivity = incoming.Count > 0 ? "browser" : "unknown";
                _lastState.TimeUtc = DateTime.UtcNow;
            }

            // run the real kernel pipeline over the ingested tabs:
            // raw tabs -> EdgeTabsProvider.Normalize -> DecisionEngine.Evaluate
            var envelope = EdgeTabsProvider.Normalize(incoming);
            var state = SnapshotState();
            var decisions = new DecisionEngine().Evaluate(state);
            Record(envelope, decisions);

            var created = new List<object>();
            foreach (var d in decisions) created.Add(new { id = d.Id, summary = d.Summary, severity = d.Severity });
            await WriteJson(ctx, Ok(new { ingested = incoming.Count, normalized = envelope.Schema, decisions = created }));
        }

        private async Task HandleEvaluate(HttpListenerContext ctx)
        {
            using var reader = new StreamReader(ctx.Request.InputStream, Encoding.UTF8);
            var body = await reader.ReadToEndAsync();

            NormalizedState? state;
            try { state = JsonSerializer.Deserialize<NormalizedState>(body, JsonOpts); }
            catch { state = null; }
            if (state is null)
            {
                await WriteJson(ctx, Error("bad_request", "body must be a NormalizedState JSON object"), 400);
                return;
            }

            lock (StateLock) { _lastState = state; }
            var decisions = new DecisionEngine().Evaluate(state);

            var envelope = new SignalEnvelope { Provider = "companion.evaluate", Schema = "sr.signal.manual.v1" };
            Record(envelope, decisions);

            var list = new List<object>();
            foreach (var d in decisions)
                list.Add(new { id = d.Id, time = d.Time, severity = d.Severity, summary = d.Summary, evidence = d.Evidence, explainability = d.Explainability });
            await WriteJson(ctx, Ok(new { decisions = list }));
        }

        private async Task HandleCommand(HttpListenerContext ctx)
        {
            using var reader = new StreamReader(ctx.Request.InputStream, Encoding.UTF8);
            var body = await reader.ReadToEndAsync();

            string intent = "", target = "";
            try
            {
                using var doc = JsonDocument.Parse(body);
                intent = doc.RootElement.GetProperty("intent").GetString() ?? "";
                if (doc.RootElement.TryGetProperty("target", out var t)) target = t.GetString() ?? "";
            }
            catch { }

            if (string.IsNullOrWhiteSpace(intent))
            {
                await WriteJson(ctx, Error("bad_request", "body must be {\"intent\": \"...\", \"target\": \"...\"?}"), 400);
                return;
            }

            Interlocked.Increment(ref _commandCount);

            // Bifrost command translation — mirrors the semantics of the Python
            // Hybrid kernel's Bifrost.translate_command(): validate + translate the
            // intent into a kernel-side action. Commands are allow-listed.
            var result = Translate(intent, target);

            lock (StateLock)
            {
                _commandLog.Add($"{intent}:{result.Status}");
                if (!result.Queued) Interlocked.Decrement(ref _commandCount);
            }

            Broadcast("command.accepted", new { intent, target, status = result.Status, detail = result.Detail });
            await WriteJson(ctx, Ok(new
            {
                intent,
                target,
                status = result.Status,
                detail = result.Detail,
                result = result.Payload
            }), result.Status == "accepted" ? 200 : 422);
        }

        private sealed record CommandResult(string Status, string Detail, object Payload, bool Queued = true);

        /// <summary>
        /// Allow-listed kernel commands. Unknown intents are rejected rather than
        /// echoed (the Python bridge's `echo {intent}` fallback is deliberately NOT
        /// reproduced here — a remote-control surface must never execute free text).
        /// </summary>
        private static CommandResult Translate(string intent, string target)
        {
            switch (intent.Trim().ToLowerInvariant())
            {
                case "ping":
                    return new CommandResult("accepted", "kernel is alive", new { pong = true, timeUtc = DateTime.UtcNow });
                case "odin_telemetry":
                    return new CommandResult("accepted", "odin pantheon telemetry attached", new {
                        timeUtc = DateTime.UtcNow,
                        pantheon = new[] { "odin", "freya", "heimdall", "thor", "bifrost", "loki", "luci", "solomon", "heketa", "lynn", "yggdrasil", "mjolnir" },
                        state = StatePayload(),
                    });
                case "get_state":
                    return new CommandResult("accepted", "state snapshot attached", StatePayload(), Queued: false);
                case "get_tabs":
                    return new CommandResult("accepted", "tabs attached", TabsPayload(), Queued: false);
                case "evaluate":
                    return new CommandResult("accepted", "decision engine ran on last normalized state",
                        new { decisions = DecisionsPayload() }, Queued: false);
                case "focus_tab":
                    if (string.IsNullOrWhiteSpace(target))
                        return new CommandResult("rejected", "focus_tab requires a target tab id", new { }, Queued: false);
                    return new CommandResult("accepted", $"focus request queued for tab '{target}'", new { tabId = target });
                case "close_tab":
                    if (string.IsNullOrWhiteSpace(target))
                        return new CommandResult("rejected", "close_tab requires a target tab id", new { }, Queued: false);
                    return new CommandResult("accepted", $"close request queued for tab '{target}'", new { tabId = target });
                case "shutdown_kernel":
                    return new CommandResult("rejected", "shutdown is not permitted over the mobile bridge", new { }, Queued: false);
                default:
                    return new CommandResult("rejected", $"unknown intent '{intent}'. allowed: ping, get_state, get_tabs, evaluate, focus_tab, close_tab", new { }, Queued: false);
            }
        }

        // ---- payloads -------------------------------------------------------------

        private static object HealthPayload()
        {
            lock (StateLock)
            {
                return new
                {
                    kernel = "StormRaven OS",
                    status = "online",
                    version = Version,
                    bridge = "bifrost",
                    bridgeVersion = "sr.bridge.mobile.v1",
                    startedUtc = _startedUtc,
                    uptimeSec = (long)(DateTime.UtcNow - _startedUtc).TotalSeconds,
                    signalCount = _signalCount,
                    openTabs = _tabs.Count,
                    pendingCommands = _commandCount,
                    clients = _sockets.Count,
                    lastActivityUtc = _lastState.TimeUtc,
                    providers = new[] { new { name = "edge.tabs", schema = "sr.signal.edge.tabs.v1", state = _tabs.Count > 0 ? "streaming" : "idle" } }
                };
            }
        }

        private static object StatePayload()
        {
            NormalizedState s;
            lock (StateLock) s = SnapshotState();
            return new
            {
                timeUtc = s.TimeUtc,
                focus = new { attention = s.Focus.Attention, foregroundActivity = s.Focus.ForegroundActivity },
                system = new { cpuLoad = s.System.CpuLoad, memoryPressure = s.System.MemoryPressure },
                network = new { state = s.Network.State },
                power = new { source = s.Power.Source }
            };
        }

        private static object TabsPayload()
        {
            lock (StateLock)
            {
                return new
                {
                    provider = "edge.tabs",
                    schema = "sr.signal.edge.tabs.v1",
                    count = _tabs.Count,
                    tabs = _tabs.ToArray()
                };
            }
        }

        private static object DecisionsPayload()
        {
            lock (StateLock) return new { count = _decisions.Count, decisions = _decisions.ToArray() };
        }

        private static object SignalsPayload()
        {
            lock (StateLock) return new { count = _signals.Count, signals = _signals.ToArray() };
        }

        // ---- pipeline helpers -------------------------------------------------------

        private static NormalizedState SnapshotState()
        {
            return new NormalizedState
            {
                TimeUtc = _lastState.TimeUtc,
                Focus = new FocusState { Attention = _lastState.Focus.Attention, ForegroundActivity = _lastState.Focus.ForegroundActivity },
                System = new SystemState { CpuLoad = _lastState.System.CpuLoad, MemoryPressure = _lastState.System.MemoryPressure },
                Network = new NetworkState { State = _lastState.Network.State },
                Power = new PowerState { Source = _lastState.Power.Source }
            };
        }

        private static void Record(SignalEnvelope envelope, List<Decision> decisions)
        {
            Interlocked.Increment(ref _signalCount);
            lock (StateLock)
            {
                _signals.Enqueue(envelope);
                while (_signals.Count > 50) _signals.TryDequeue(out _);
                foreach (var d in decisions)
                {
                    _decisions.Enqueue(d);
                }
                while (_decisions.Count > 100) _decisions.TryDequeue(out _);
            }
            foreach (var d in decisions)
            {
                try { _dbStatic?.InsertDecision(d.Id, d.Time, d.Severity, d.Summary, d.Evidence, d.Explainability); }
                catch { /* storage failure must not break the pipeline */ }
                Broadcast("decision", new { id = d.Id, time = d.Time, severity = d.Severity, summary = d.Summary, ruleId = d.Explainability.RuleId });
            }
            Broadcast("signal", new { provider = envelope.Provider, schema = envelope.Schema });
        }

        // ---- websocket fan-out --------------------------------------------------------

        private static async Task HandleSocket(WebSocket ws)
        {
            lock (StateLock) _sockets.Add(ws);
            try
            {
                // greeting carries the current health + state so the app can paint immediately
                var hello = new Dictionary<string, object?>
                {
                    ["type"] = "hello",
                    ["kernel"] = "StormRaven OS",
                    ["bridge"] = "bifrost",
                    ["version"] = Version,
                    ["health"] = HealthPayload(),
                    ["state"] = StatePayload(),
                    ["tabs"] = TabsPayload()
                };
                await SendAsync(ws, JsonSerializer.Serialize(hello, JsonOpts));

                var buf = new byte[8192];
                while (ws.State == WebSocketState.Open)
                {
                    var res = await ws.ReceiveAsync(new ArraySegment<byte>(buf), CancellationToken.None);
                    if (res.MessageType == WebSocketMessageType.Close) break;
                    // client pings ("ping") get a pong; anything else is ignored
                    var msg = Encoding.UTF8.GetString(buf, 0, res.Count).Trim();
                    if (msg == "ping") await SendAsync(ws, "{\"type\":\"pong\",\"timeUtc\":\"" + DateTime.UtcNow.ToString("O") + "\"}");
                }
            }
            catch { /* socket died */ }
            finally
            {
                lock (StateLock) _sockets.Remove(ws);
                try { ws.Dispose(); } catch { }
            }
        }

        private static void Broadcast(string type, object data)
        {
            var evt = new Dictionary<string, object?> { ["type"] = type, ["timeUtc"] = DateTime.UtcNow, ["data"] = data };
            var json = JsonSerializer.Serialize(evt, JsonOpts);
            lock (StateLock)
            {
                foreach (var ws in _sockets.ToArray())
                {
                    if (ws.State != WebSocketState.Open) continue;
                    var _ = SendAsync(ws, json); // fire-and-forget; failures cleaned up on receive loop
                }
            }
        }

        private static async Task BroadcastAsync(string type, object data)
        {
            var evt = new Dictionary<string, object?> { ["type"] = type, ["timeUtc"] = DateTime.UtcNow, ["data"] = data };
            var json = JsonSerializer.Serialize(evt, JsonOpts);
            WebSocket[] targets;
            lock (StateLock) targets = _sockets.ToArray();
            foreach (var ws in targets)
                if (ws.State == WebSocketState.Open)
                    try { await SendAsync(ws, json); } catch { }
        }

        private static async Task SendAsync(WebSocket ws, string message)
        {
            var bytes = Encoding.UTF8.GetBytes(message);
            await ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
        }

        // ---- http plumbing -----------------------------------------------------------------

        private static object Ok(object data) => new { ok = true, data };
        private static object Error(string code, string message) => new { ok = false, error = new { code, message } };

        private static async Task WriteJson(HttpListenerContext ctx, object payload, int status = 200)
        {
            ctx.Response.StatusCode = status;
            ctx.Response.ContentType = "application/json";
            ctx.Response.Headers["X-Bifrost-Bridge"] = "sr.bridge.mobile.v1";
            var json = JsonSerializer.Serialize(payload, JsonOpts);
            var bytes = Encoding.UTF8.GetBytes(json);
            ctx.Response.ContentLength64 = bytes.Length;
            await ctx.Response.OutputStream.WriteAsync(bytes);
            ctx.Response.Close();
        }
    }
}
