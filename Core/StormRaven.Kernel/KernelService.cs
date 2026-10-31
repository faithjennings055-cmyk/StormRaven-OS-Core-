using System;
using System.Threading;
using System.Threading.Tasks;

namespace StormRaven.Kernel
{
    public class KernelService
    {
        private CancellationTokenSource? _cts;
        private Task? _monitorTask;

        public string ServiceName { get; } = "StormRavenKernel";

        // The Nine Realms
        public global::StormRaven.Kernel.ContextBus.ContextBus OpticalBus { get; } = new();
        public PersonaMatrix PersonaMatrix { get; } = new();
        public ValhallaLedger Valhalla { get; } = new();
        public DeepArchive DeepArchive { get; } = new();
        public MicrokernelBinaryManager BinaryManager { get; } = new();
        public OperationalLayer Operational { get; private set; }
        public NiflheimSnapshotManager Niflheim { get; private set; }
        public HelheimIsolationVault Helheim { get; private set; }
        public SovereignCommandDispatcher CommandDispatcher { get; private set; }
        public VitalityMonitor Vitality { get; private set; }
        public ChaosEngine Chaos { get; private set; }

        public KernelService()
        {
            InitializePersonaMatrix();
            CommandDispatcher = new SovereignCommandDispatcher(PersonaMatrix);
            Vitality = new VitalityMonitor(OpticalBus);
            Chaos = new ChaosEngine(OpticalBus, PersonaMatrix);
            Niflheim = new NiflheimSnapshotManager(OpticalBus);
            Helheim = new HelheimIsolationVault(OpticalBus);
            Operational = new OperationalLayer(OpticalBus, BinaryManager, PersonaMatrix);
            RegisterSovereignCommands();
        }

        private void InitializePersonaMatrix()
        {
            PersonaMatrix.AddPersona("root", "Odin", PrivilegeRing.Void);
            PersonaMatrix.AddPersona("admin", "Thor", PrivilegeRing.Sovereign);
            PersonaMatrix.AddPersona("sec-ops", "Heimdall", PrivilegeRing.Sentinel);
            PersonaMatrix.AddPersona("ops", "Freya", PrivilegeRing.Sentinel);
            PersonaMatrix.AddPersona("dev", "Loki", PrivilegeRing.Adept);
            PersonaMatrix.AddPersona("user", "Baldur", PrivilegeRing.Adept);
            PersonaMatrix.AddPersona("guest", "Fenrir", PrivilegeRing.Transient);
        }

        private void RegisterSovereignCommands()
        {
            CommandDispatcher.RegisterCommand(new RebootMatrixCommand());
            CommandDispatcher.RegisterCommand(new TriggerChaosCommand(Chaos));
        }

        public void Start(string[]? args = null)
        {
            _cts = new CancellationTokenSource();
            var token = _cts.Token;
            _monitorTask = Task.Run(() => MonitorLoop(token), token);
            Valhalla.Append("kernel.start", "{\"message\":\"The Nine Realms are manifest.\"}");
        }

        public void Stop()
        {
            if (_cts == null) return;
            _cts.Cancel();
            try
            {
                _monitorTask?.Wait(TimeSpan.FromSeconds(5));
            }
            catch { }
            finally
            {
                _cts.Dispose();
                _cts = null;
                _monitorTask = null;
            }
        }

        private void MonitorLoop(CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                try
                {
                    RunMonitorIteration(token);
                }
                catch (OperationCanceledException) when (token.IsCancellationRequested)
                {
                    break;
                }
                catch { }
            }
        }

        public void RunMonitorIteration(CancellationToken token = default)
        {
            token.ThrowIfCancellationRequested();
            OpticalBus.Publish("sr.kernel.heartbeat", new { Timestamp = DateTime.UtcNow, Status = "Stable" });
            Vitality.Pulse();
            if (token.CanBeCanceled)
                Task.Delay(TimeSpan.FromSeconds(1), token).Wait(token);
        }
    }
}
