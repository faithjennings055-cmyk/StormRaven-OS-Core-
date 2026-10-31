using System;
using System.IO;
using StormRaven.Kernel.Ipc;
using StormRaven.Kernel.Storage;

namespace StormRaven.Kernel
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("StormRaven Kernel (Native) initialized.");

            // Bifrost Gateway — HTTP + WebSocket bridge for remote companions
            // (StormRaven iOS app). Runs alongside the named-pipe IPC surface.
            //   http://localhost:8787/health   full route table in Ipc/BifrostGateway.cs
            // Set STORMRAVEN_NO_GATEWAY=1 to run the kernel headless without it.
            if (Environment.GetEnvironmentVariable("STORMRAVEN_NO_GATEWAY") != "1")
            {
                var port = int.TryParse(Environment.GetEnvironmentVariable("STORMRAVEN_GATEWAY_PORT"), out var p) ? p : BifrostGateway.DefaultPort;
                string? dbPath = Environment.GetEnvironmentVariable("STORMRAVEN_DB");
                dbPath ??= Path.Combine(AppContext.BaseDirectory, "stormraven.db");

                var db = new StormRavenDb(dbPath);
                var schema = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Schema.sql"));
                var gateway = new BifrostGateway(port, db, schema);
                gateway.Start();
                Console.WriteLine($"Bifrost Gateway listening on http://localhost:{port}  (mobile bridge sr.bridge.mobile.v1)");
            }

            Console.WriteLine("To run Hybrid Kernel, execute 'python StormRaven.Python/odin.py'");
        }
    }
}
