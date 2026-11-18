using System;

namespace StormRaven.Kernel.Contracts
{
    public sealed class NormalizedState
    {
        public DateTime TimeUtc { get; set; } = DateTime.UtcNow;
        public FocusState Focus { get; set; } = new FocusState();
        public SystemState System { get; set; } = new SystemState();
        public NetworkState Network { get; set; } = new NetworkState();
        public PowerState Power { get; set; } = new PowerState();
    }

    public sealed class FocusState
    {
        public string Attention { get; set; } = "unknown"; // focused|idle|unknown
        public string ForegroundActivity { get; set; } = "unknown"; // browser|game|work|unknown
    }

    public sealed class SystemState
    {
        public string CpuLoad { get; set; } = "unknown"; // low|med|high|unknown
        public string MemoryPressure { get; set; } = "unknown"; // low|med|high|unknown
    }

    public sealed class NetworkState { public string State { get; set; } = "unknown"; } // offline|metered|online|unknown
    public sealed class PowerState { public string Source { get; set; } = "unknown"; }  // ac|battery|unknown
}