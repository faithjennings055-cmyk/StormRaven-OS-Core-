using StormRaven.Kernel.ContextBus;
using StormRaven.Kernel.Contracts;
using StormRaven.Kernel.Kernel;
using StormRaven.Kernel.Providers;

namespace StormRaven.Mobile;

public partial class MainPage : ContentPage
{
    private readonly ContextBus _bus = new();
    private readonly DecisionEngine _engine = new();

    public MainPage()
    {
        InitializeComponent();
    }

    private void OnCheckKernel(object? sender, EventArgs e)
    {
        // Round-trip a sample edge-tabs signal through the ported kernel:
        // provider -> context bus -> decision engine.
        var envelope = EdgeTabsProvider.Normalize(new[] { new { isCurrent = true } });
        _bus.Publish(envelope);
        var decisions = _engine.Evaluate(_bus.State);

        StatusLabel.Text = decisions.Count > 0
            ? $"Kernel OK — {decisions.Count} decision(s). Latest: {decisions[0].Id}"
            : "Kernel OK — no decisions.";
    }
}
