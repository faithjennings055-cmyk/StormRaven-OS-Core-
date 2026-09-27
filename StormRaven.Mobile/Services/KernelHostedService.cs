using Microsoft.Extensions.Hosting;
using StormRaven.Kernel;

namespace StormRaven.Mobile.Services;

/// <summary>
/// iOS/MAUI replacement for the Windows-only ServiceBase wrapper
/// (Core/StormRaven.Kernel/KernelService.cs). Runs the same monitor loop
/// as an IHostedService tied to the MAUI application lifecycle.
/// </summary>
public sealed class KernelHostedService : IHostedService, IDisposable
{
    private readonly ILogger<KernelHostedService> _logger;
    private CancellationTokenSource? _cts;
    private Task? _monitorTask;

    public KernelHostedService(ILogger<KernelHostedService> logger)
    {
        _logger = logger;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        var token = _cts.Token;
        _monitorTask = Task.Run(() => MonitorLoop(token), token);
        _logger.LogInformation("StormRaven kernel hosted service started.");
        return Task.CompletedTask;
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_cts is null)
        {
            return;
        }

        _cts.Cancel();

        try
        {
            if (_monitorTask is not null)
            {
                await Task.WhenAny(_monitorTask, Task.Delay(TimeSpan.FromSeconds(5), cancellationToken));
                if (!_monitorTask.IsCompleted)
                {
                    _logger.LogWarning("Monitor loop did not stop within 5 seconds.");
                }
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

    private async Task RunMonitorIterationAsync(CancellationToken token)
    {
        token.ThrowIfCancellationRequested();

        // TODO: Port monitor logic here.
        await Task.Delay(TimeSpan.FromSeconds(1), token);
    }

    public void Dispose() => _cts?.Dispose();
}
