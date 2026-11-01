using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using ContextBusClass = StormRaven.Kernel.ContextBus.ContextBus;

namespace StormRaven.Kernel
{
    public class HelheimIsolationVault
    {
        private readonly string _vaultPath;
        private readonly global::StormRaven.Kernel.ContextBus.ContextBus _bus;

        public HelheimIsolationVault(global::StormRaven.Kernel.ContextBus.ContextBus bus, string? vaultPath = null)
        {
            _bus = bus;
            var baseDir = Environment.GetEnvironmentVariable("STORMRAVEN_VOID_DIR")
                          ?? Path.Combine(Path.GetTempPath(), "stormraven-void");
            _vaultPath = vaultPath ?? Path.Combine(baseDir, "helheim");
            Directory.CreateDirectory(_vaultPath);
        }

        public async Task<string> QuarantineTarget(string targetId, byte[] data)
        {
            var safeId = Path.GetFileName(targetId);
            string filePath = Path.Combine(_vaultPath, $"{safeId}.void");
            await File.WriteAllBytesAsync(filePath, data);

            _bus.Publish("sr.helheim.quarantine", new { Target = safeId, Status = "Isolating", Path = filePath });
            return filePath;
        }

        public async Task<byte[]> ReleaseTarget(string targetId)
        {
            var safeId = Path.GetFileName(targetId);
            string filePath = Path.Combine(_vaultPath, $"{safeId}.void");
            if (!File.Exists(filePath)) throw new FileNotFoundException("Target not found in Helheim vault.");

            byte[] data = await File.ReadAllBytesAsync(filePath);
            File.Delete(filePath);

            _bus.Publish("sr.helheim.release", new { Target = safeId, Status = "Released" });
            return data;
        }

        public IEnumerable<string> ListQuarantined()
        {
            if (!Directory.Exists(_vaultPath)) return Array.Empty<string>();
            return Directory.GetFiles(_vaultPath, "*.void");
        }
    }
}
