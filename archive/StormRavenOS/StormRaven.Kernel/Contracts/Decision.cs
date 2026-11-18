using System;
using System.Collections.Generic;

namespace StormRaven.Kernel.Contracts
{
    public sealed class Decision
    {
        public int V { get; set; } = 1;
        public string Type { get; set; } = "Decision";
        public string Id { get; set; } = "";
        public DateTime Time { get; set; } = DateTime.UtcNow;
        public string Severity { get; set; } = "info";
        public string Summary { get; set; } = "";
        public List<EvidenceItem> Evidence { get; set; } = new List<EvidenceItem>();
        public Explainability Explainability { get; set; } = new Explainability();
    }

    public sealed class EvidenceItem
    {
        public string Signal { get; set; } = "";
        public string Field { get; set; } = "";
        public string Value { get; set; } = "";
    }

    public sealed class Explainability
    {
        public string RuleId { get; set; } = "";
        public double Confidence { get; set; } = 1.0;
    }
}