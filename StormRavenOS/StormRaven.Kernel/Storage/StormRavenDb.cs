using Microsoft.Data.Sqlite;
using System;
using System.Text.Json;

namespace StormRaven.Kernel.Storage
{
    public sealed class StormRavenDb
    {
        private readonly string _dbPath;

        public StormRavenDb(string dbPath)
        {
            _dbPath = dbPath;
            var dir = System.IO.Path.GetDirectoryName(_dbPath);
            if (!string.IsNullOrEmpty(dir) && !System.IO.Directory.Exists(dir))
                System.IO.Directory.CreateDirectory(dir);
        }

        public SqliteConnection Open()
        {
            var cn = new SqliteConnection($"Data Source={_dbPath}");
            cn.Open();
            return cn;
        }

        public void EnsureSchema(string schemaSql)
        {
            using var cn = Open();
            using var cmd = cn.CreateCommand();
            cmd.CommandText = schemaSql;
            cmd.ExecuteNonQuery();
        }

        public void InsertDecision(string id, DateTime timeUtc, string severity, string summary, object evidence, object explainability)
        {
            using var cn = Open();
            using var cmd = cn.CreateCommand();
            cmd.CommandText =
@"INSERT OR REPLACE INTO decisions (id, time_utc, severity, summary, evidence_json, explainability_json)
  VALUES ($id, $t, $sev, $sum, $ev, $ex)";
            cmd.Parameters.AddWithValue("$id", id);
            cmd.Parameters.AddWithValue("$t", timeUtc.ToString("O"));
            cmd.Parameters.AddWithValue("$sev", severity);
            cmd.Parameters.AddWithValue("$sum", summary);
            cmd.Parameters.AddWithValue("$ev", JsonSerializer.Serialize(evidence));
            cmd.Parameters.AddWithValue("$ex", JsonSerializer.Serialize(explainability));
            cmd.ExecuteNonQuery();
        }
    }
}