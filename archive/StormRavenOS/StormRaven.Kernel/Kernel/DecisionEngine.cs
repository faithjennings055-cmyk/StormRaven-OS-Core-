using System;
using System.Collections.Generic;
using StormRaven.Kernel.Contracts;

namespace StormRaven.Kernel.Kernel
{
    public sealed class DecisionEngine
    {
        public List<Decision> Evaluate(NormalizedState s)
        {
            var outDecisions = new List<Decision>();

            if (s?.Focus != null &&
                s.Focus.Attention == "focused" &&
                s.Focus.ForegroundActivity == "browser")
            {
                var d = new Decision
                {
                    Id = $"DEC-{DateTime.UtcNow:yyyyMMddHHmmss}-FOCUS",
                    Time = DateTime.UtcNow,
                    Severity = "info",
                    Summary = "User attention is focused in foreground browsing session",
                    Evidence = new List<EvidenceItem>
                    {
                        new EvidenceItem { Signal = "sr.signal.edge.tabs.v1", Field = "isCurrent", Value = "true" }
                    },
                    Explainability = new Explainability { RuleId = "focus.attention.edge.current.v1", Confidence = 1.0 }
                };
                outDecisions.Add(d);
            }

            return outDecisions;
        }
    }
}