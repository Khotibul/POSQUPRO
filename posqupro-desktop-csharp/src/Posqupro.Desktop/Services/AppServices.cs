using Posqupro.Desktop.Data;

namespace Posqupro.Desktop.Services;

/// <summary>Application-wide service container (small app, explicit composition instead of DI).</summary>
public static class AppServices
{
    public static LocalDatabase Db { get; private set; } = null!;
    public static AppSettingsStore Settings { get; private set; } = null!;
    public static ApiClient Api { get; private set; } = null!;
    public static AuthService Auth { get; private set; } = null!;
    public static SalesService Sales { get; private set; } = null!;
    public static LocalQueries Queries { get; private set; } = null!;
    public static SyncService Sync { get; private set; } = null!;

    public static async Task InitializeAsync()
    {
        Db = new LocalDatabase();
        await Db.InitializeAsync();

        Settings = new AppSettingsStore();
        Api = new ApiClient(Settings);
        Auth = new AuthService(Settings, Api);
        Sales = new SalesService(Db, Settings);
        Queries = new LocalQueries(Db);
        Sync = new SyncService(Db, Api, Settings);
    }
}
