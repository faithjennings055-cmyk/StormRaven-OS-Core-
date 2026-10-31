using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;

namespace StormRaven.Kernel
{
    public class NiflheimSnapshotManager
    {
        private readonly string _snapshotPath = "/void/niflheim";
        private readonly ContextBus _bus;

        public NiflheimSnapshotManager(ContextBus bus)
        {
            _bus = bus;
            if (!Directory.Exists(_snapshotPath))
            {
                Directory.CreateDirectory(_snapshotPath);
            }
        }

        public async Task<string> CreateSnapshot(string targetId, object state)
        {
            string snapshotId = $"snap_{targetId}_{DateTime.UtcNow:yyyyMMddHHmmss}";
            string filePath = Path.Combine(_snapshotPath, $"{snapshotId}.void");

            string json = JsonSerializer.Serialize(state);
            await File.WriteAllTextAsync(filePath, json);

            _bus.Publish("sr.niflheim.snapshot", new { SnapshotId = snapshotId, Target = targetId });
            return snapshotId;
        }

        public async Task<T> RestoreSnapshot<T>(string snapshotId)
        {
            string filePath = Path.Combine(_snapshotPath, $"{snapshotId}.void");
            if (!File.Exists(filePath)) throw new FileNotFoundException("Snapshot not found in Niflheim.");

            string json = await File.ReadAllTextAsync(filePath);
            return JsonSerializer.Deserialize<T>(json);
        }

        public IEnumerable<string> ListSnapshots()
        {
            return Directory.GetFiles(_snapshotPath, "*.void");
        }
    }
}
