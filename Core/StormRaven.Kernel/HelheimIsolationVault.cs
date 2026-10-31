using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;

namespace StormRaven.Kernel
{
    public class HelheimIsolationVault
    {
        private readonly string _vaultPath = "/void/helheim";
        private readonly ContextBus _bus;

        public HelheimIsolationVault(ContextBus bus)
        {
            _bus = bus;
            if (!Directory.Exists(_vaultPath))
            {
                Directory.CreateDirectory(_vaultPath);
            }
        }

        public async Task QuarantineTarget(string targetId, byte[] data)
        {
            string filePath = Path.Combine(_vaultPath, $"{targetId}.void");
            await File.WriteAllBytesAsync(filePath, data);

            _bus.Publish("sr.helheim.quarantine", new { Target = targetId, Status = "Isolating" });
        }

        public async Task<byte[]> ReleaseTarget(string targetId)
        {
            string filePath = Path.Combine(_vaultPath, $"{targetId}.void");
            if (!File.Exists(filePath)) throw new FileNotFoundException("Target not found in Helheim vault.");

            byte[] data = await File.ReadAllBytesAsync(filePath);
            File.Delete(filePath);

            _bus.Publish("sr.helheim.release", new { Target = targetId, Status = "Released" });
            return data;
        }

        public IEnumerable<string> ListQuarantined()
        {
            return Directory.GetFiles(_vaultPath, "*.void");
        }
    }
}
