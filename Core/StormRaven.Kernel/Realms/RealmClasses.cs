using System;
using System.Collections.Generic;
using ContextBusClass = StormRaven.Kernel.ContextBus.ContextBus;
using System.Linq;

namespace StormRaven.Kernel.Realms
{
    public enum PrivilegeRing { Void, Sovereign, Sentinel, Adept, Transient }

    // ---- Asgard: Persona Matrix ----
    public sealed class Persona
    {
        public string Id { get; set; } = "";
        public string Name { get; set; } = "";
        public PrivilegeRing Ring { get; set; }
    }

    public sealed class PersonaMatrix
    {
        private readonly Dictionary<string, Persona> _personas = new();
        public IReadOnlyCollection<Persona> Personas => _personas.Values;
        public void AddPersona(string id, string name, PrivilegeRing ring)
            => _personas[id] = new Persona { Id = id, Name = name, Ring = ring };
        public bool TryGet(string id, out Persona? p) => _personas.TryGetValue(id, out p);
    }

    // ---- Asgard/Command: Sovereign dispatcher ----
    public sealed class SovereignCommandDispatcher
    {
        private readonly PersonaMatrix _matrix;
        private readonly Dictionary<string, Func<string[], string>> _commands = new();
        public SovereignCommandDispatcher(PersonaMatrix matrix) => _matrix = matrix;
        public void RegisterCommand(string name, Func<string[], string> handler) => _commands[name] = handler;
        public string Dispatch(string name, string[] args)
            => _commands.TryGetValue(name, out var h) ? h(args) : $"Unknown sovereign command: {name}";
    }

    // ---- Asgard: reboot-matrix sovereign command ----
    public sealed class RebootMatrixCommand
    {
        public string Name => "reboot-matrix";
        public string Execute(string[] args) => "Sovereign Command: Matrix Reboot Initiated.";
    }

    // ---- Jotunheim: DeepArchive ----
    public sealed class DeepArchive
    {
        private readonly Dictionary<string, string> _archive = new();
        public void Store(string key, string value) => _archive[key] = value;
        public bool TryRetrieve(string key, out string? v) => _archive.TryGetValue(key, out v);
        public IReadOnlyCollection<string> Keys => _archive.Keys;
    }

    // ---- Svartalfheim: Binary manager ----
    public sealed class MicrokernelBinaryManager
    {
        public string RegisterBinary(string id, byte[] bytes) => $"registered:{id}:{bytes.Length}";
        public bool Verify(string id) => true;
    }

    // ---- Midgard: Operational layer ----
    public sealed class OperationalLayer
    {
        private readonly ContextBusClass _bus;
        private readonly MicrokernelBinaryManager _binary;
        private readonly PersonaMatrix _personas;
        public OperationalLayer(ContextBusClass bus, MicrokernelBinaryManager binary, PersonaMatrix personas)
            => (_bus, _binary, _personas) = (bus, binary, personas);
        public string Status => "Operational";
    }

    // ---- Vanaheim: Vitality monitor ----
    public sealed class VitalityMonitor
    {
        private readonly ContextBusClass _bus;
        public VitalityMonitor(ContextBusClass bus) => _bus = bus;
        public string Pulse()
        {
            var cpu = System.Diagnostics.Process.GetCurrentProcess().TotalProcessorTime.TotalMilliseconds;
            var mem = Environment.WorkingSet;
            _bus.Publish(new Contracts.SignalEnvelope { Type = "vitality.pulse", Payload = $"cpu={cpu:0} mem={mem}" });
            return $"pulse ok cpu={cpu:0} mem={mem}";
        }
    }

    // ---- Muspelheim: Chaos engine (real, bounded fault injection) ----
    public sealed class ChaosEngine
    {
        private readonly ContextBusClass _bus;
        private readonly PersonaMatrix _personas;
        public ChaosEngine(ContextBusClass bus, PersonaMatrix personas) => (_bus, _personas) = (bus, personas);

        public string TriggerFault(string kind)
        {
            // Bounded, observable faults only — never destructive to live state.
            switch (kind?.ToLowerInvariant())
            {
                case "delay":
                    System.Threading.Thread.Sleep(250);
                    return "Fault injected: 250ms scheduler delay.";
                case "signal":
                    _bus.Publish(new Contracts.SignalEnvelope { Type = "chaos.fault", Payload = "synthetic heartbeat disruption" });
                    return "Fault injected: synthetic signal disruption.";
                default:
                    return $"Unknown fault kind: {kind}. Available: delay, signal.";
            }
        }
    }

    // ---- Muspelheim: trigger-chaos command ----
    public sealed class TriggerChaosCommand
    {
        private readonly ChaosEngine _engine;
        public TriggerChaosCommand(ChaosEngine engine) => _engine = engine;
        public string Execute(string[] args) => _engine.TriggerFault(args.FirstOrDefault() ?? "signal");
    }
}

// ---- Asgard: Valhalla ledger (honor roll of decisions) ----
public sealed class ValhallaLedger
{
    private readonly List<(DateTime When, string Entry)> _entries = new();
    public void Record(string entry) => _entries.Add((DateTime.UtcNow, entry));
    public IReadOnlyList<(DateTime When, string Entry)> Entries => _entries;
}
