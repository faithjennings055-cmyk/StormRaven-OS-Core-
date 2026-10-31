namespace StormRaven.Kernel.Contracts
{
    public sealed class SignalEnvelope
    {
        public int V { get; set; } = 1;
        public string Type { get; set; } = "Signal";
        public DateTime Time { get; set; } = DateTime.UtcNow;
        public string Provider { get; set; } = "";
        public string Schema { get; set; } = "";
        public PrivacyBlock Privacy { get; set; } = new PrivacyBlock();
        public object Payload { get; set; } = new { };
    }

    public sealed class PrivacyBlock
    {
        public string Classification { get; set; } = "opaque-metadata";
        public int RetentionSec { get; set; } = 300;
    }
}