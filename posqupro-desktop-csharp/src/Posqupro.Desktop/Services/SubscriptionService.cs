using System.Diagnostics;
using System.Text.Json;
using Posqupro.Desktop.Models;

namespace Posqupro.Desktop.Services;

/// <summary>Tenant subscription state shared by the shell, gating and billing page.</summary>
public sealed class SubscriptionService(ApiClient api)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public SubscriptionOverview? Current { get; private set; }
    public bool Loaded { get; private set; }
    public bool IsLoading { get; private set; }
    public string? LastError { get; private set; }

    public event Action? Changed;

    public bool IsBlocked =>
        Current?.Subscription?.IsExpired == true ||
        Current?.Status is "suspended" or "inactive";

    public bool HasFeature(string? feature)
    {
        if (string.IsNullOrWhiteSpace(feature) || !Loaded || Current is null) return true;
        if (!Current.HasPlan || Current.Features.Count == 0) return true;
        return Current.Features.Contains(feature, StringComparer.OrdinalIgnoreCase);
    }

    public async Task RefreshAsync()
    {
        IsLoading = true;
        var result = await api.GetAsync("subscription");
        IsLoading = false;

        if (result.Success && result.Data.ValueKind == JsonValueKind.Object)
        {
            try
            {
                Current = JsonSerializer.Deserialize<SubscriptionOverview>(result.Data.GetRawText(), JsonOptions);
                Loaded = Current is not null;
                LastError = null;
            }
            catch (JsonException)
            {
                LastError = "Respons status langganan tidak dikenali.";
            }
        }
        else if (!result.Offline)
        {
            LastError = result.Message;
        }

        Changed?.Invoke();
    }

    public async Task<(bool Success, string Message)> LoadBillingAsync()
    {
        IsLoading = true;
        var result = await api.GetAsync("billing");
        IsLoading = false;

        if (!result.Success || result.Data.ValueKind != JsonValueKind.Object)
        {
            LastError = result.Message;
            Changed?.Invoke();
            return (false, result.Message);
        }

        try
        {
            Current = JsonSerializer.Deserialize<SubscriptionOverview>(result.Data.GetRawText(), JsonOptions);
            Loaded = Current is not null;
            LastError = null;
            Changed?.Invoke();
            return (true, "");
        }
        catch (JsonException)
        {
            LastError = "Respons billing tidak dikenali.";
            Changed?.Invoke();
            return (false, LastError);
        }
    }

    public async Task<(bool Success, string Message, string? PaymentUrl)> CheckoutAsync(long planId, string billingCycle)
    {
        var result = await api.PostAsync("billing/checkout", new
        {
            plan_id = planId,
            billing_cycle = billingCycle,
        });

        if (!result.Success || result.Data.ValueKind != JsonValueKind.Object)
        {
            return (false, result.Message, null);
        }

        try
        {
            var checkout = JsonSerializer.Deserialize<CheckoutResponse>(result.Data.GetRawText(), JsonOptions);
            var url = checkout?.PaymentUrl;
            return (true, "Invoice dibuat. Lanjutkan pembayaran di browser.", url);
        }
        catch (JsonException)
        {
            return (false, "Respons pembayaran tidak dikenali.", null);
        }
    }

    public static bool OpenUrl(string? url)
    {
        if (string.IsNullOrWhiteSpace(url)) return false;

        try
        {
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
            return true;
        }
        catch
        {
            return false;
        }
    }
}
