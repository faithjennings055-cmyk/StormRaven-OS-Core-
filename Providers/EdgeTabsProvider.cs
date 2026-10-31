using StormRaven.Kernel.Contracts;
using System.Collections;

namespace StormRaven.Kernel.Providers
{
    public static class EdgeTabsProvider
    {
        public static SignalEnvelope Normalize(IEnumerable edgeTabs)
        {
            bool hasActiveTab = false;
            foreach (var tab in edgeTabs)
            {
                try
                {
                    var prop = tab.GetType().GetProperty("isCurrent");
                    if (prop != null)
                    {
                        var val = prop.GetValue(tab);
                        if (val is bool b && b) { hasActiveTab = true; break; }
                    }
                }
                catch { }
            }

            return new SignalEnvelope
            {
                Provider = "edge.tabs",
                Schema = "sr.signal.edge.tabs.v1",
                Payload = new { hasForegroundTab = hasActiveTab },
                Privacy = new PrivacyBlock { Classification = "opaque-metadata", RetentionSec = 1209600 }
            };
        }
    }
}