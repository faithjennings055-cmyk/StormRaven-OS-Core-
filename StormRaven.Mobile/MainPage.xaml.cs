using System.Net.Http.Json;
using System.Text.Json;
using StormRaven.Kernel.ContextBus;
using StormRaven.Kernel.Contracts;
using StormRaven.Kernel.Kernel;
using StormRaven.Kernel.Providers;
using StormRaven.Mobile.Services;

namespace StormRaven.Mobile;

public partial class MainPage : ContentPage
{
    private readonly ContextBus _bus = new();
    private readonly DecisionEngine _engine = new();
    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(8) };

    public MainPage()
    {
        InitializeComponent();
    }

    private void OnCheckKernel(object? sender, EventArgs e)
    {
        var hosted = KernelHostedService.Current;
        if (hosted is not null)
        {
            var decisions = hosted.EvaluateActiveSession(isFocused: true);
            var st = hosted.LatestState;
            StatusLabel.Text = decisions.Count > 0
                ? $"Kernel OK — {decisions.Count} decision(s) · Latest: {decisions[0].Id}"
                : "Kernel OK — nominal";
            TelemetryLabel.Text = $"Focus: {st.Focus.Attention} · Activity: {st.Focus.ForegroundActivity} · Ticks: {hosted.IterationCount}";
            return;
        }

        var envelope = EdgeTabsProvider.Normalize(new[] { new { isCurrent = true } });
        _bus.Publish(envelope);
        var localDecisions = _engine.Evaluate(_bus.State);

        StatusLabel.Text = localDecisions.Count > 0
            ? $"Kernel OK — {localDecisions.Count} decision(s). Latest: {localDecisions[0].Id}"
            : "Kernel OK — no decisions.";
    }

    private async void OnSyncGateway(object? sender, EventArgs e)
    {
        var baseUrl = (GatewayUrlEntry.Text ?? "https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app").Trim().TrimEnd('/');
        try
        {
            GatewayOutputLabel.Text = $"Connecting to {baseUrl}/status…";
            var json = await _http.GetStringAsync($"{baseUrl}/status");
            GatewayOutputLabel.Text = json.Length > 600 ? json[..600] + "…" : json;
        }
        catch (Exception ex)
        {
            GatewayOutputLabel.Text = $"Gateway error: {ex.Message}";
        }
    }

    private async void OnRunOdinTelemetry(object? sender, EventArgs e)
    {
        var baseUrl = (GatewayUrlEntry.Text ?? "https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app").Trim().TrimEnd('/');
        try
        {
            GatewayOutputLabel.Text = "Running Odin Pantheon telemetry…";
            // Gateway command API expects { intent, target }: map the Odin telemetry request
            using var resp = await _http.PostAsJsonAsync($"{baseUrl}/command", new { intent = "odin_telemetry", target = "maui-mobile" });
            var body = await resp.Content.ReadAsStringAsync();
            GatewayOutputLabel.Text = body.Length > 600 ? body[..600] + "…" : body;
        }
        catch (Exception ex)
        {
            GatewayOutputLabel.Text = $"Odin command error: {ex.Message}";
        }
    }
}
