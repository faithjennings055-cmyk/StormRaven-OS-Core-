using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

namespace StormRaven.Kernel
{
    public enum PrivilegeRing
    {
        Void = 0,
        Sovereign = 1,
        Sentinel = 2,
        Adept = 3,
        Transient = 4
    }

    public sealed record PersonaEntry(string Role, string Deity, PrivilegeRing Ring, DateTime RegisteredUtc);

    public sealed class PersonaMatrix
    {
        private readonly ConcurrentDictionary<string, PersonaEntry> _personas = new(StringComparer.OrdinalIgnoreCase);

        public void AddPersona(string role, string deity, PrivilegeRing ring)
        {
            _personas[role] = new PersonaEntry(role, deity, ring, DateTime.UtcNow);
        }

        public PersonaEntry? GetPersona(string role) =>
            _personas.TryGetValue(role, out var p) ? p : null;

        public IReadOnlyCollection<PersonaEntry> ListPersonas() => _personas.Values.ToArray();
    }

    public sealed record LedgerEntry(long Index, DateTime TimestampUtc, string EventType, string PayloadJson, string PrevHash, string Hash);

    public sealed class ValhallaLedger
    {
        private readonly List<LedgerEntry> _entries = new();
        private readonly object _lock = new();

        public LedgerEntry Append(string eventType, string payloadJson)
        {
            lock (_lock)
            {
                var prevHash = _entries.Count > 0 ? _entries[^1].Hash : new string('0', 64);
                var idx = _entries.Count + 1;
                var ts = DateTime.UtcNow;
                var raw = $"{idx}|{ts:O}|{eventType}|{payloadJson}|{prevHash}";
                var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(raw))).ToLowerInvariant();
                var entry = new LedgerEntry(idx, ts, eventType, payloadJson, prevHash, hash);
                _entries.Add(entry);
                return entry;
            }
        }

        public IReadOnlyList<LedgerEntry> Snapshot()
        {
            lock (_lock) return _entries.ToArray();
        }
    }

    public sealed class DeepArchive
    {
        private readonly string _archiveDir;

        public DeepArchive(string? archiveDir = null)
        {
            var baseDir = Environment.GetEnvironmentVariable("STORMRAVEN_VOID_DIR")
                          ?? Path.Combine(Path.GetTempPath(), "stormraven-void");
            _archiveDir = archiveDir ?? Path.Combine(baseDir, "archive");
            Directory.CreateDirectory(_archiveDir);
        }

        public string StoreArtifact(string key, byte[] content)
        {
            var safeKey = Path.GetFileName(key);
            var target = Path.Combine(_archiveDir, $"{safeKey}.bin");
            File.WriteAllBytes(target, content);
            return Convert.ToHexString(SHA256.HashData(content)).ToLowerInvariant();
        }
    }

    public sealed class MicrokernelBinaryManager
    {
        public string VerifyBinaryDigest(string filePath)
        {
            if (!File.Exists(filePath)) return "MISSING";
            using var stream = File.OpenRead(filePath);
            return Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant();
        }
    }

    public sealed class OperationalLayer
    {
        private readonly StormRaven.Kernel.ContextBus.ContextBus _bus;
        private readonly MicrokernelBinaryManager _binaryManager;
        private readonly PersonaMatrix _personaMatrix;

        public OperationalLayer(
            StormRaven.Kernel.ContextBus.ContextBus bus,
            MicrokernelBinaryManager binaryManager,
            PersonaMatrix personaMatrix)
        {
            _bus = bus;
            _binaryManager = binaryManager;
            _personaMatrix = personaMatrix;
        }

        public object GetStatus() => new
        {
            personas = _personaMatrix.ListPersonas().Count,
            selfDigest = _binaryManager.VerifyBinaryDigest(Environment.ProcessPath ?? ""),
            timeUtc = DateTime.UtcNow
        };
    }

    public sealed class VitalityMonitor
    {
        private readonly StormRaven.Kernel.ContextBus.ContextBus _bus;

        public VitalityMonitor(StormRaven.Kernel.ContextBus.ContextBus bus)
        {
            _bus = bus;
        }

        public (double CpuLoadPercent, double MemoryPressurePercent) ReadHostSensors()
        {
            double cpuPct = 12.0;
            double memPct = 38.0;
            try
            {
                if (File.Exists("/proc/loadavg"))
                {
                    var parts = File.ReadAllText("/proc/loadavg").Split(' ', StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length > 0 && double.TryParse(parts[0], System.Globalization.CultureInfo.InvariantCulture, out var load1))
                    {
                        var cores = Math.Max(1, Environment.ProcessorCount);
                        cpuPct = Math.Round(Math.Clamp((load1 / cores) * 100.0, 1.0, 100.0), 1);
                    }
                }
                if (File.Exists("/proc/meminfo"))
                {
                    long totalKb = 0, availKb = 0;
                    foreach (var line in File.ReadLines("/proc/meminfo"))
                    {
                        if (line.StartsWith("MemTotal:"))
                            long.TryParse(new string(line.Where(char.IsDigit).ToArray()), out totalKb);
                        else if (line.StartsWith("MemAvailable:"))
                            long.TryParse(new string(line.Where(char.IsDigit).ToArray()), out availKb);
                    }
                    if (totalKb > 0)
                        memPct = Math.Round(Math.Clamp(((double)(totalKb - availKb) / totalKb) * 100.0, 1.0, 100.0), 1);
                }
            }
            catch { }
            return (cpuPct, memPct);
        }

        public void Pulse()
        {
            var (cpu, mem) = ReadHostSensors();
            _bus.State.System.CpuLoad = cpu > 80 ? "high" : "normal";
            _bus.State.System.MemoryPressure = mem > 85 ? "high" : "normal";
            _bus.State.TimeUtc = DateTime.UtcNow;
            _bus.Publish("sr.vitality.pulse", new { cpu, mem, timeUtc = DateTime.UtcNow });
        }
    }

    public sealed record ChaosFaultResult(string FaultId, string FaultType, string SandboxDir, bool Contained, DateTime TriggeredUtc);

    public sealed class ChaosEngine
    {
        private readonly StormRaven.Kernel.ContextBus.ContextBus _bus;
        private readonly PersonaMatrix _personas;
        private readonly List<ChaosFaultResult> _history = new();

        public ChaosEngine(StormRaven.Kernel.ContextBus.ContextBus bus, PersonaMatrix personas)
        {
            _bus = bus;
            _personas = personas;
        }

        public ChaosFaultResult InjectFault(string faultType = "memory_spike")
        {
            var baseDir = Environment.GetEnvironmentVariable("STORMRAVEN_VOID_DIR")
                          ?? Path.Combine(Path.GetTempPath(), "stormraven-void");
            var muspelheimDir = Path.Combine(baseDir, "muspelheim");
            Directory.CreateDirectory(muspelheimDir);

            var faultId = $"fault_{Guid.NewGuid().ToString("N")[..8]}";
            var probeFile = Path.Combine(muspelheimDir, $"{faultId}.probe");
            File.WriteAllText(probeFile, $"MUSPELHEIM_FAULT={faultType};UTC={DateTime.UtcNow:O}");
            File.Delete(probeFile);

            var res = new ChaosFaultResult(faultId, faultType, muspelheimDir, true, DateTime.UtcNow);
            lock (_history) _history.Add(res);
            _bus.Publish("sr.muspelheim.fault", res);
            return res;
        }

        public IReadOnlyList<ChaosFaultResult> History()
        {
            lock (_history) return _history.ToArray();
        }
    }

    public interface ISovereignCommand
    {
        string Name { get; }
        PrivilegeRing MinimumRing { get; }
        object Execute(string? target = null);
    }

    public sealed class SovereignCommandDispatcher
    {
        private readonly PersonaMatrix _personas;
        private readonly Dictionary<string, ISovereignCommand> _commands = new(StringComparer.OrdinalIgnoreCase);

        public SovereignCommandDispatcher(PersonaMatrix personas)
        {
            _personas = personas;
        }

        public void RegisterCommand(ISovereignCommand command)
        {
            _commands[command.Name] = command;
        }

        public object Dispatch(string role, string commandName, string? target = null)
        {
            var persona = _personas.GetPersona(role);
            if (persona is null)
                throw new UnauthorizedAccessException($"Unknown role '{role}'.");
            if (!_commands.TryGetValue(commandName, out var cmd))
                throw new InvalidOperationException($"Unknown sovereign command '{commandName}'.");
            if (persona.Ring > cmd.MinimumRing)
                throw new UnauthorizedAccessException($"Role '{role}' ({persona.Ring}) lacks privilege ({cmd.MinimumRing}) for '{commandName}'.");
            return cmd.Execute(target);
        }
    }

    public sealed class RebootMatrixCommand : ISovereignCommand
    {
        public string Name => "reboot_matrix";
        public PrivilegeRing MinimumRing => PrivilegeRing.Sovereign;
        public object Execute(string? target = null) => new { status = "matrix_reinitialized", timeUtc = DateTime.UtcNow };
    }

    public sealed class TriggerChaosCommand : ISovereignCommand
    {
        private readonly ChaosEngine _chaos;
        public TriggerChaosCommand(ChaosEngine chaos) => _chaos = chaos;
        public string Name => "trigger_chaos";
        public PrivilegeRing MinimumRing => PrivilegeRing.Sentinel;
        public object Execute(string? target = null) => _chaos.InjectFault(target ?? "memory_spike");
    }
}
