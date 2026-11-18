StormRavenOS scaffold
=====================

This scaffold creates the initial project layout for StormRaven OS v1.

Includes:
1. Native C# Kernel (Windows Service)
2. Hybrid Master Doctoral Kernel (Python) in `StormRaven.Python/`
   - Cross-platform Logic (Windows/Linux)
   - Modules: Luci, Solomon, Thor, Freya, Heimdall, Bifrost, Saga, Shadow Log, Void Viz, Ragnarok, Deadman, Odin.
3. WinUI Shell Scaffold
4. Restoration Script: `StormRaven.Installer/restore_odin.sh`

Next steps:‎
1. Open the folder in Visual Studio.
2. Add a solution file and include the two projects.
3. To test the prototype kernel, run `python StormRaven.Python/odin.py`.
4. For Linux/WSL restoration, execute `bash StormRaven.Installer/restore_odin.sh`.