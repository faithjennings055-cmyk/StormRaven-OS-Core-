using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using StormRaven.Kernel.Contracts;
using StormRaven.Kernel.ContextBus;

namespace StormRaven.Kernel
{
    // ---- privilege rings ------------------------------------------------------
    public enum PrivilegeRing
    {
        Adept = 0,     // dev / read-mostly
        Sentinel = 1,  // sec-ops / ops
        Sovereign = 2, // admin / thor
        Void = 3       // root / odin
    }

    // ---- persona matrix -------------------------------------------------------
    public sealed class PersonaMatrix
    {
        private readonly ConcurrentDictionary<string, (string Deity, PrivilegeRing Ring)> _personas = new();

        public void AddPersona(string principal, string deity, PrivilegeRing ring)
            => _personas[principal] = (deity, ring);

        public bool TryGet(string principal, out string deity, out PrivilegeRing ring)
        {
            if (_personas.TryGetValue(principal, out var v)) { deity = v.Deity; ring = v.Ring; return true; }
            deity = ""; ring = PrivilegeRing.Adept; return false;
        }

        public bool HasPrivilege(string principal, PrivilegeRing required)
            => _personas.TryGetValue(principal, out var v) && v.Ring >= required;

        public IReadOnlyDictionary<string, (string Deity, PrivilegeRing Ring)> Snapshot => _personas;
    }

    // ---- valhalla ledger (post-mortem archive of crashed kernels) -------------
    public sealed class ValhallaLedger
    {
        private readonly ConcurrentQueue<ValhallaEntry> _entries = new();
        private readonly string _logPath;

        public ValhallaLedger() : this(ResolveVoidDir()) { }

        public ValhallaLedger(string logDir)
        {
            _logPath = logDir;
            try { Directory.CreateDirectory(logDir); } catch { /* read-only fs: keep in-memory */ }
        }

        public static string ResolveVoidDir()
            => Environment.GetEnvironmentVariable("STORMRAVENVOIDDIR") ?? "/tmp/stormraven-void";

        public void Record(string daemon, string reason, string detail = "")
        {
            var e = new ValhallaEntry(DateTime.UtcNow, daemon, reason, detail);
            _entries.Enqueue(e);
            try { File.AppendAllText(Path.Combine(_logPath, "valhalla.log"), JsonSerializer.Serialize(e) + Environment.NewLine); } catch { }
        }

        public IReadOnlyList<ValhallaEntry> Recent() => _entries.ToList();
    }

    public sealed record ValhallaEntry(DateTime TimeUtc, string Daemon, string Reason, string Detail);

    // ---- deep archive (immutable decision history) ----------------------------
    public sealed class DeepArchive
    {
        private readonly ConcurrentQueue<(DateTime Utc, string Kind, string Payload)> _archive = new();
        public void Append(string kind, string payload) => _archive.Enqueue((DateTime.UtcNow, kind, payload));
        public IReadOnlyList<(DateTime Utc, string Kind, string Payload)> Recent(int n = 50) => _archive.TakeLast(n).ToList();
    }

    // ---- microkernel binary manager -------------------------------------------
    public sealed class MicrokernelBinaryManager
    {
        public string BinaryPath { get; private set; } = string.Empty;
        public string Version { get; private set; } = "unknown";

        public bool Register(string path)
        {
            if (!File.Exists(path)) return false;
            BinaryPath = path;
            Version = Path.GetFileNameWithoutExtension(path);
            return true;
        }
    }

    // ---- operational layer -----------------------------------------------------
    public sealed class OperationalLayer
    {
        private readonly ContextBus _bus;
        private readonly MicrokernelBinaryManager _binaries;
        private readonly PersonaMatrix _personas;

        public OperationalLayer(ContextBus bus, MicrokernelBinaryManager binaries, PersonaMatrix personas)
        { _bus = bus; _binaries = binaries; _personas = personas; }

        public bool Execute(string principal, string op, string payload = "")
        {
            if (!_personas.HasPrivilege(principal, PrivilegeRing.Adept)) return false;
            _bus.Publish(new SignalEnvelope { Schema = "sr.op.executed.v1", Provider = "operational", Payload = new { principal, op, payload, utc = DateTime.UtcNow }) });
            return true;
        }
    }

    // ---- vitality monitor ------------------------------------------------------
    public sealed class VitalityMonitor
    {
        private readonly ContextBus _bus;
        private readonly List<SignalEnvelope> _events = new();

        public VitalityMonitor(ContextBus bus) { _bus = bus; }

        public void Observe(SignalEnvelope e) { _events.Add(e); _bus.Publish(e); }
        public SignalEnvelope LastEvent => _events.Count > 0 ? _events[^1] : new SignalEnvelope { Schema = "sr.vitality.idle.v1", Provider = "vitality" };
        public bool Healthy => _events.Count == 0 || _events[^1].Schema != "sr.chaos.injected.v1";
    }

    // ---- chaos engine (Muspelheim) ---------------------------------------------
    public sealed class ChaosEngine
    {
        private readonly ContextBus _bus;
        private readonly PersonaMatrix _personas;

        public ChaosEngine(ContextBus bus, PersonaMatrix personas) { _bus = bus; _personas = personas; }

        public bool InjectFault(string principal, string fault, string realm = "muspelheim")
        {
            if (!_personas.HasPrivilege(principal, PrivilegeRing.Sentinel)) return false;
            _bus.Publish(new SignalEnvelope { Schema = "sr.chaos.injected.v1", Provider = "chaos", Payload = new { principal, fault, realm, utc = DateTime.UtcNow }) });
            return true;
        }
    }

    // ---- sovereign command dispatcher -----------------------------------------
    public sealed class SovereignCommandDispatcher
    {
        private readonly PersonaMatrix _personas;
        private readonly Dictionary<string, (PrivilegeRing Ring, Func<string, string> Handler)> _commands = new();

        public SovereignCommandDispatcher(PersonaMatrix personas) { _personas = personas; }

        public void Register(string command, PrivilegeRing required, Func<string, string> handler)
            => _commands[command] = (required, handler);

        public (bool Ok, string Output) Dispatch(string principal, string command, string args = "")
        {
            if (!_commands.TryGetValue(command, out var spec))
                return (false, $"unknown sovereign command '{command}'");
            if (!_personas.HasPrivilege(principal, spec.Ring))
                return (false, $"principal '{principal}' lacks privilege for '{command}'");
            return (true, spec.Handler(args));
        }

        public IReadOnlyCollection<string> Registered => _commands.Keys;
    }

    // ---- reboot / chaos sovereign commands -------------------------------------
    public sealed class RebootMatrixCommand
    {
        public static void Register(SovereignCommandDispatcher d, Action reboot)
            => d.Register("reboot-matrix", PrivilegeRing.Void, _ => { reboot(); return "reboot-matrix initiated"; });
    }

    public sealed class TriggerChaosCommand
    {
        public static void Register(SovereignCommandDispatcher d, ChaosEngine chaos, string principal)
            => d.Register("trigger-chaos", PrivilegeRing.Sentinel, fault =>
                chaos.InjectFault(principal, fault) ? $"chaos injected: {fault}" : "chaos injection denied");
    }
}
