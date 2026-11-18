using StormRaven.Kernel.Contracts;

namespace StormRaven.Kernel.ContextBus
{
    public sealed class ContextBus
    {
        public NormalizedState State { get; } = new NormalizedState();

        public void Publish(SignalEnvelope signal)
        {
            if (signal?.Schema == "sr.signal.edge.tabs.v1")
            {
                dynamic p = signal.Payload;
                bool focused = false;
                try { focused = p.hasForegroundTab == true; } catch { focused = false; }

                State.Focus.Attention = focused ? "focused" : "idle";
                State.Focus.ForegroundActivity = focused ? "browser" : "unknown";
                State.TimeUtc = DateTime.UtcNow;
            }
        }
    }
}