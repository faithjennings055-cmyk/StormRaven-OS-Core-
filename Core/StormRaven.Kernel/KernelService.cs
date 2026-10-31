using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.ServiceProcess;
using System.Threading;
using System.Threading.Tasks;
using StormRaven.Kernel.Contracts;
using StormRaven.Kernel.Storage;
using StormRaven.Kernel.Realms;
using ContextBusClass = StormRaven.Kernel.ContextBus.ContextBus;

namespace StormRaven.Kernel
{
    public class KernelService : ServiceBase
    {
        private readonly EventLog _eventLog;
        private CancellationTokenSource _cts;
        private Task _monitorTask;

        // The Nine Realms
        public ContextBusClass OpticalBus { get; } = new();
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
            ServiceName = "StormRavenKernel";
            _eventLog = new EventLog
            {
                Source = ServiceName,
                Log = "Application"
            };

            // Bootstrap the Void
            InitializePersonaMatrix();
            CommandDispatcher = new SovereignCommandDispatcher(PersonaMatrix);
            RegisterSovereignCommands();
            
            Vitality = new VitalityMonitor(OpticalBus);
            Chaos = new ChaosEngine(OpticalBus, PersonaMatrix);
            Niflheim = new NiflheimSnapshotManager(OpticalBus);
            Helheim = new HelheimIsolationVault(OpticalBus);
            Operational = new OperationalLayer(OpticalBus, BinaryManager, PersonaMatrix);
        }

        private void InitializePersonaMatrix()
        {
            // Seeding the Pantheon
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
            var reboot = new RebootMatrixCommand();
            CommandDispatcher.RegisterCommand(reboot.Name, args => reboot.Execute(args));
            var triggerChaos = new TriggerChaosCommand(Chaos);
            CommandDispatcher.RegisterCommand("trigger-chaos", args => triggerChaos.Execute(args));
        }

        protected override void OnStart(string[] args)
        {
            _cts = new CancellationTokenSource();
            var token = _cts.Token;

            _monitorTask = Task.Run(() => MonitorLoop(token), token);
            _eventLog.WriteEntry("StormRaven Kernel started: The Nine Realms are manifest.");
        }

        protected override void OnStop()
        {
            if (_cts == null) return;
            _cts.Cancel();

            try
            {
                if (_monitorTask != null && !_monitorTask.Wait(TimeSpan.FromSeconds(5)))
                {
                    _eventLog.WriteEntry("Monitor loop did not stop within 5 seconds.", EventLogEntryType.Warning);
                }
            }
            catch (AggregateException ex)
            {
                foreach (var inner in ex.Flatten().InnerExceptions)
                {
                    _eventLog.WriteEntry($"Monitor task failed while stopping: {inner}", EventLogEntryType.Error);
                }
            }
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
                catch (Exception ex)
                {
                    _eventLog.WriteEntry($"Monitor loop failure: {ex}", EventLogEntryType.Error);
                }
            }
        }

        private void RunMonitorIteration(CancellationToken token)
        {
            token.ThrowIfCancellationRequested();

            // Heartbeat of the Void
            OpticalBus.Publish("sr.kernel.heartbeat", new { Timestamp = DateTime.UtcNow, Status = "Stable" });
            
            // Run Vitality pulse
            Vitality.Pulse();

            Task.Delay(TimeSpan.FromSeconds(1), token).Wait(token);
        }
    }
}
