using System.Text.Json;
using Posqupro.Desktop.Models;

namespace Posqupro.Desktop.Services;

public sealed class AuthService(AppSettingsStore settings, ApiClient api)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public bool IsLoggedIn => !string.IsNullOrWhiteSpace(settings.Value.Token);

    public async Task<(bool Success, string Message)> LoginAsync(string email, string password)
    {
        var result = await api.LoginAsync(email, password);
        if (!result.Success)
        {
            return (false, result.Offline
                ? "Server tidak dapat dijangkau. Gunakan login offline dengan akun yang pernah login di perangkat ini."
                : result.Message);
        }

        try
        {
            var response = JsonSerializer.Deserialize<AuthResponse>(result.Data.GetRawText(), JsonOptions);
            if (response is null || string.IsNullOrWhiteSpace(response.Token))
            {
                return (false, "Respons login tidak dikenali.");
            }

            if (!string.Equals(response.User.Role, "OWNER", StringComparison.OrdinalIgnoreCase) && response.Tenant is not null)
            {
                settings.Value.TenantId = response.Tenant.Id;
            }

            settings.ApplyLogin(response);
            settings.SetOfflinePassword(password);
            return (true, $"Selamat datang, {response.User.Name}.");
        }
        catch (JsonException)
        {
            return (false, "Respons login tidak dikenali.");
        }
    }

    public (bool Success, string Message) LoginOffline(string email, string password)
    {
        if (string.IsNullOrWhiteSpace(settings.Value.UserEmail) || string.IsNullOrWhiteSpace(settings.Value.OfflineHash))
        {
            return (false, "Belum ada sesi offline di perangkat ini. Login sekali saat online terlebih dahulu.");
        }

        if (!settings.VerifyOfflinePassword(email, password))
        {
            return (false, "Email atau password salah.");
        }

        return (true, $"Mode offline. Selamat datang, {settings.Value.UserName}.");
    }

    public async Task LogoutAsync()
    {
        if (IsLoggedIn)
        {
            await api.LogoutAsync();
        }

        settings.ClearSession();
    }
}
