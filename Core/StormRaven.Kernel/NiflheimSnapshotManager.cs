using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;

namespace StormRaven.Kernel
{
    public class NiflheimSnapshotManager
    {
        private readonly string _snapshotPath;
        private readonly StormRaven.Kernel.ContextBus.ContextBus _bus;

        public NiflheimSnapshotManager(StormRaven.Kernel.ContextBus.ContextBus bus, string? snapshotPath = null)
        {
            _bus = bus;
            var baseDir = Environment.GetEnvironmentVariable("STORMRAVEN_VOID_DIR")
                          ?? Path.Combine(Path.GetTempPath(), "stormraven-void");
            _snapshotPath = snapshotPath ?? Path.Combine(baseDir, "niflheim");
            Directory.CreateDirectory(_snapshotPath);
        }

        public async Task<string> CreateSnapshot(string targetId, object state)
        {
            var safeId = Path.GetFileName(targetId);
            string snapshotId = $"snap_{safeId}_{DateTime.UtcNow:yyyyMMddHHmmss}";
            string filePath = Path.Combine(_snapshotPath, $"{snapshotId}.void");

            string json = JsonSerializer.Serialize(state);
            await File.WriteAllTextAsync(filePath, json);

            _bus.Publish("sr.niflheim.snapshot", new { SnapshotId = snapshotId, Target = safeId });
            return snapshotId;
        }

        public async Task<T?> RestoreSnapshot<T>(string snapshotId)
        {
            var safeId = Path.GetFileName(snapshotId);
            string filePath = Path.Combine(_snapshotPath, $"{safeId}.void");
            if (!File.Exists(filePath)) throw new FileNotFoundException("Snapshot not found in Niflheim.");

            string json = await File.ReadAllTextAsync(filePath);
            return JsonSerializer.Deserialize<T>(json);
        }

        public IEnumerable<string> ListSnapshots()
        {
            if (!Directory.Exists(_snapshotPath)) return Array.Empty<string>();
            return Directory.GetFiles(_snapshotPath, "*.void");
        }
    }
}
