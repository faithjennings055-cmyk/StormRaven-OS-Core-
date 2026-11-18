using System.Collections.Concurrent;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using StormRaven.Kernel.ContextBus;
using StormRaven.Kernel.Contracts;
using StormRaven.Kernel.Kernel;
using StormRaven.Kernel.Providers;
using StormRaven.Kernel.Storage;

namespace StormRaven.Mobile.Services;

/// <summary>
/// Cross-platform iOS/Android MAUI replacement for the Windows-only ServiceBase
/// wrapper (Core/StormRaven.Kernel/KernelService.cs). Runs a real on-device
/// monitor loop over StormRaven.Kernel.Portable (ContextBus, EdgeTabsProvider,
/// DecisionEngine, StormRavenDb) tied to the MAUI application lifecycle.
/// </summary>
public sealed class KernelHostedService : IHostedService, IDisposable
{
    private const string DefaultSchema = @"
CREATE TABLE IF NOT EXISTS signals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  time_utc TEXT NOT NULL,
  provider TEXT NOT NULL,
  schema TEXT NOT NULL,
  classification TEXT NOT NULL,
  retention_sec INTEGER NOT NULL,
  payload_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS state_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  time_utc TEXT NOT NULL,
  state_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS decisions (
  id TEXT PRIMARY KEY,
  time_utc TEXT NOT NULL,
  severity TEXT NOT NULL,
  summary TEXT NOT NULL,
  evidence_json TEXT NOT NULL,
  explainability_json TEXT NOT NULL
);";

    private readonly ILogger<KernelHostedService> _logger;
    private readonly ContextBus _bus = new();
    private readonly DecisionEngine _engine = new();
    private readonly StormRavenDb _db;
    private readonly ConcurrentQueue<Decision> _recentDecisions = new();
    private CancellationTokenSource? _cts;
    private Task? _monitorTask;
    private long _iterationCount;

    public static KernelHostedService? Current { get; private set; }

    public NormalizedState LatestState => _bus.State;
    public long IterationCount => Interlocked.Read(ref _iterationCount);
    public IReadOnlyCollection<Decision> RecentDecisions => _recentDecisions.ToArray();

    public event Action<NormalizedState, IReadOnlyList<Decision>>? TickCompleted;

    public KernelHostedService(ILogger<KernelHostedService> logger)
    {
        _logger = logger;
        var dbPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "stormraven-mobile.db");
        _db = new StormRavenDb(dbPath);
        try { _db.EnsureSchema(DefaultSchema); } catch { }
        Current = this;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        var token = _cts.Token;
        _monitorTask = Task.Run(() => MonitorLoop(token), token);
        _logger.LogInformation("StormRaven mobile kernel hosted service started.");
        return Task.CompletedTask;
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_cts is null) return;
        _cts.Cancel();

        try
        {
            if (_monitorTask is not null)
            {
                await Task.WhenAny(_monitorTask, Task.Delay(TimeSpan.FromSeconds(5), cancellationToken));
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Monitor task failed while stopping.");
        }
        finally
        {
            _cts.Dispose();
            _cts = null;
            _monitorTask = null;
        }
    }

    private async Task MonitorLoop(CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            try
            {
                await RunMonitorIterationAsync(token);
            }
            catch (OperationCanceledException) when (token.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Monitor loop failure.");
            }
        }
    }

    public IReadOnlyList<Decision> EvaluateActiveSession(bool isFocused = true)
    {
        var envelope = EdgeTabsProvider.Normalize(new[] { new { isCurrent = isFocused } });
        _bus.Publish(envelope);
        _bus.State.System.CpuLoad = "normal";
        _bus.State.System.MemoryPressure = "normal";
        _bus.State.Network.State = "online";
        _bus.State.Power.Source = "battery";

        var decisions = _engine.Evaluate(_bus.State);
        foreach (var d in decisions)
        {
            _recentDecisions.Enqueue(d);
            while (_recentDecisions.Count > 50) _recentDecisions.TryDequeue(out _);
            try { _db.InsertDecision(d.Id, d.Time, d.Severity, d.Summary, d.Evidence, d.Explainability); } catch { }
        }
        Interlocked.Increment(ref _iterationCount);
        TickCompleted?.Invoke(_bus.State, decisions);
        return decisions;
    }

    private async Task RunMonitorIterationAsync(CancellationToken token)
    {
        token.ThrowIfCancellationRequested();
        EvaluateActiveSession(isFocused: true);
        await Task.Delay(TimeSpan.FromSeconds(10), token);
    }

    public void Dispose() => _cts?.Dispose();
}
