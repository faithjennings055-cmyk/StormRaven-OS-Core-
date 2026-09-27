using StormRaven.Mobile.Services;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace StormRaven.Mobile;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()

            // iOS replacement for the Windows ServiceBase wrapper: the same
            // kernel monitor loop runs as a hosted service inside the MAUI
            // app's lifecycle.
            .Services.AddHostedService<KernelHostedService>();

        return builder.Build();
    }
}
