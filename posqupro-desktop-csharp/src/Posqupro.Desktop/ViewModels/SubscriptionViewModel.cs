using System.Collections.ObjectModel;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public sealed class SubscriptionLimitRow
{
    public required string Label { get; init; }
    public required PlanLimit Limit { get; init; }
    public string Value => Limit.Display;
    public bool Ok => Limit.Ok;
}

public sealed class SubscriptionViewModel : ViewModelBase
{
    private bool _isYearly;
    private string _statusDetail = "";
    private string _statusLabel = "";
    private int _daysRemaining;

    public SubscriptionViewModel()
    {
        Limits = [];
        Plans = [];
        Invoices = [];
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        CheckoutCommand = new RelayCommand<BillingPlan>(plan =>
        {
            if (plan is not null)
            {
                _ = CheckoutAsync(plan);
            }
        });
        OpenBillingCommand = new RelayCommand(() =>
        {
            var url = AppServices.Subscription.Current?.BillingUrl;
            if (!SubscriptionService.OpenUrl(url))
            {
                Ui.Info("Tautan halaman billing belum tersedia. Buka /billing melalui browser setelah login web.");
            }
        });
        OpenPaymentCommand = new RelayCommand<BillingInvoice>(invoice =>
        {
            if (invoice is not null && !SubscriptionService.OpenUrl(invoice.PaymentUrl))
            {
                Ui.Info("Tautan pembayaran tidak dapat dibuka. Silakan buka halaman billing di browser.");
            }
        });
        ToggleCycleCommand = new RelayCommand(() =>
        {
            IsYearly = !IsYearly;
        });

        LoadFromCache();
        _ = LoadAsync();
    }

    public ObservableCollection<SubscriptionLimitRow> Limits { get; }
    public ObservableCollection<BillingPlan> Plans { get; }
    public ObservableCollection<BillingInvoice> Invoices { get; }
    public ICommand RefreshCommand { get; }
    public ICommand CheckoutCommand { get; }
    public ICommand OpenBillingCommand { get; }
    public ICommand OpenPaymentCommand { get; }
    public ICommand ToggleCycleCommand { get; }

    public string PlanName => AppServices.Subscription.Current?.Plan?.Name
        ?? AppServices.Subscription.Current?.Limits?.PlanName
        ?? "Belum ada paket";

    public string StatusLabel
    {
        get => _statusLabel;
        private set => SetProperty(ref _statusLabel, value);
    }

    public string StatusDetail
    {
        get => _statusDetail;
        private set => SetProperty(ref _statusDetail, value);
    }

    public int DaysRemaining
    {
        get => _daysRemaining;
        private set => SetProperty(ref _daysRemaining, value);
    }

    public bool IsBlocked => AppServices.Subscription.IsBlocked;
    public bool IpaymuEnabled => AppServices.Subscription.Current?.IpaymuEnabled ?? false;
    public bool CanCheckout => IpaymuEnabled && !IsBlocked || IpaymuEnabled;
    public string BillingUrl => AppServices.Subscription.Current?.BillingUrl ?? "";

    public bool IsYearly
    {
        get => _isYearly;
        set
        {
            if (SetProperty(ref _isYearly, value))
            {
                OnPropertyChanged(nameof(CycleLabel));
            }
        }
    }

    public string CycleLabel => IsYearly ? "Tahunan" : "Bulanan";

    private async Task LoadAsync()
    {
        IsBusy = true;
        var (success, message) = await AppServices.Subscription.LoadBillingAsync();
        IsBusy = false;

        if (!success)
        {
            StatusMessage = message;
            LoadFromCache();
            return;
        }

        LoadFromCache();
        StatusMessage = "Status langganan diperbarui.";
    }

    private void LoadFromCache()
    {
        var current = AppServices.Subscription.Current;
        var summary = current?.Subscription;
        var days = summary?.DaysRemaining ?? current?.DaysRemaining ?? 0;

        DaysRemaining = days;
        StatusLabel = current?.Status switch
        {
            "trial" => "Demo 30 Hari",
            "active" => "Aktif",
            "expired" => "Kedaluwarsa",
            "suspended" => "Ditangguhkan",
            "inactive" => "Tidak aktif",
            _ => "Belum ada langganan",
        };

        StatusDetail = summary?.IsExpired == true
            ? "Masa aktif telah berakhir. Pilih paket untuk melanjutkan."
            : summary?.IsTrial == true
                ? $"Sisa {days} hari demo. Semua fitur terbuka."
                : summary?.EndsAt is { } endsAt
                    ? $"Aktif sampai {endsAt.ToLocalTime():dd MMM yyyy} · {days} hari lagi"
                    : "Status langganan belum tersedia.";

        Limits.Clear();
        AddLimit("Pengguna", current?.Limits?.Users);
        AddLimit("Produk", current?.Limits?.Products);
        AddLimit("Pelanggan", current?.Limits?.Customers);
        AddLimit("Cabang", current?.Limits?.Branches);
        AddLimit("Transaksi bulan ini", current?.Limits?.TransactionsMonth);

        Plans.Clear();
        foreach (var plan in current?.Plans ?? [])
        {
            Plans.Add(plan);
        }

        Invoices.Clear();
        foreach (var invoice in current?.Invoices ?? [])
        {
            Invoices.Add(invoice);
        }

        OnPropertyChanged(nameof(PlanName));
        OnPropertyChanged(nameof(IsBlocked));
        OnPropertyChanged(nameof(IpaymuEnabled));
        OnPropertyChanged(nameof(CanCheckout));
        OnPropertyChanged(nameof(BillingUrl));
    }

    private void AddLimit(string label, PlanLimit? limit)
    {
        if (limit is null) return;
        Limits.Add(new SubscriptionLimitRow { Label = label, Limit = limit });
    }

    private async Task CheckoutAsync(BillingPlan plan)
    {
        if (!IpaymuEnabled)
        {
            Ui.Info("Pembayaran online belum dikonfigurasi di server. Hubungi administrator POSQUPRO.");
            return;
        }

        if (!Ui.Confirm($"Bayar paket {plan.Name} ({CycleLabel}) sekarang?", "Pembayaran"))
        {
            return;
        }

        IsBusy = true;
        var (success, message, url) = await AppServices.Subscription.CheckoutAsync(
            plan.Id,
            IsYearly ? "yearly" : "monthly");
        IsBusy = false;

        if (!success || string.IsNullOrWhiteSpace(url))
        {
            Ui.Error(message);
            return;
        }

        var opened = SubscriptionService.OpenUrl(url);
        Ui.Info(opened
            ? "Halaman pembayaran iPaymu dibuka di browser. Paket aktif otomatis setelah pembayaran diterima."
            : $"Buka tautan pembayaran berikut di browser:\n\n{url}");

        await LoadAsync();
    }
}
