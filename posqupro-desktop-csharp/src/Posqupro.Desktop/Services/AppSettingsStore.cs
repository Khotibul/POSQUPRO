using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Posqupro.Desktop.Models;

namespace Posqupro.Desktop.Services;

public class AppSettings
{
    public const string ProductionBaseUrl = "https://posqupro.co-id.id";
    public const string LocalBaseUrl = "http://127.0.0.1:8000";

    public string BaseUrl { get; set; } = ProductionBaseUrl;
    public string? Token { get; set; }
    public long? UserId { get; set; }
    public string? UserName { get; set; }
    public string? UserEmail { get; set; }
    public string? UserRole { get; set; }
    public long? TenantId { get; set; }
    public string? TenantName { get; set; }
    public string? TenantStatus { get; set; }
    public string? LicenseCode { get; set; }
    public string? PlanName { get; set; }
    public string? OfflineSalt { get; set; }
    public string? OfflineHash { get; set; }
    public string? RememberedEmail { get; set; }
    public DateTime? LastSyncAt { get; set; }
    public bool AutoSync { get; set; } = true;
    public string DeviceId { get; set; } = Guid.NewGuid().ToString("N");
    public string? RegisterCode { get; set; }
}

public sealed class AppSettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private readonly string _path;

    public AppSettings Value { get; private set; } = new();

    public AppSettingsStore()
    {
        var folder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "POSQUPRO");
        Directory.CreateDirectory(folder);
        _path = Path.Combine(folder, "app-settings.json");
        Load();
    }

    public void Load()
    {
        try
        {
            if (File.Exists(_path))
            {
                Value = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(_path), JsonOptions) ?? new AppSettings();
            }
        }
        catch (Exception)
        {
            Value = new AppSettings();
        }
    }

    public void Save()
    {
        File.WriteAllText(_path, JsonSerializer.Serialize(Value, JsonOptions));
    }

    public void SetOfflinePassword(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(16);
        Value.OfflineSalt = Convert.ToBase64String(salt);
        Value.OfflineHash = Hash(password, salt);
        Save();
    }

    public bool VerifyOfflinePassword(string email, string password)
    {
        if (string.IsNullOrEmpty(Value.OfflineSalt) || string.IsNullOrEmpty(Value.OfflineHash))
        {
            return false;
        }

        if (!string.Equals(Value.UserEmail, email, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var computed = Hash(password, Convert.FromBase64String(Value.OfflineSalt));
        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(computed),
            Encoding.UTF8.GetBytes(Value.OfflineHash));
    }

    public void ApplyLogin(AuthResponse response)
    {
        Value.Token = response.Token;
        Value.UserId = response.User.Id;
        Value.UserName = response.User.Name;
        Value.UserEmail = response.User.Email;
        Value.UserRole = response.User.Role;
        Value.TenantId = response.Tenant?.Id;
        Value.TenantName = response.Tenant?.Name;
        Value.TenantStatus = response.Tenant?.Status;
        Value.LicenseCode = response.Tenant?.LicenseCode;
        Value.PlanName = response.Tenant?.Plan?.Name;
        Value.RememberedEmail = response.User.Email;
        Save();
    }

    public void ClearSession()
    {
        Value.Token = null;
        Save();
    }

    public string NormalizedBaseUrl =>
        string.IsNullOrWhiteSpace(Value.BaseUrl) ? AppSettings.ProductionBaseUrl : Value.BaseUrl.TrimEnd('/');

    private static string Hash(string password, byte[] salt)
    {
        var bytes = Rfc2898DeriveBytes.Pbkdf2(
            Encoding.UTF8.GetBytes(password),
            salt,
            120_000,
            HashAlgorithmName.SHA256,
            32);
        return Convert.ToBase64String(bytes);
    }
}
