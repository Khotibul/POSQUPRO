using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Threading;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public sealed class ShellViewModel : ViewModelBase
{
    private readonly DispatcherTimer _timer;
    private readonly Dictionary<string, object> _pageCache = [];
    private object? _currentPage;
    private NavItem? _selectedNav;
    private string _currentKey = "";
    private bool _isOnline;
    private bool _isSyncing;
    private string _syncStatus = "";
    private string _pendingLabel = "";
    private string _lastSyncLabel = "";
    private string _currentPageTitle = "";

    public ShellViewModel()
    {
        NavItems = new ObservableCollection<NavItem>(BuildNavItems());
        NavView = CollectionViewSource.GetDefaultView(NavItems);
        NavView.GroupDescriptions.Add(new PropertyGroupDescription(nameof(NavItem.Section)));

        NavigateCommand = new RelayCommand<NavItem>(item =>
        {
            if (item is not null)
            {
                SelectedNav = item;
            }
        });
        SyncCommand = new AsyncRelayCommand(SyncNowAsync);
        LogoutCommand = new AsyncRelayCommand(LogoutAsync);

        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(20) };
        _timer.Tick += async (_, _) => await AppServices.Sync.TickAsync();
        _timer.Start();

        AppServices.Sync.Changed += OnSyncChanged;
        RefreshSyncState();

        var first = NavItems.FirstOrDefault();
        if (first is not null)
        {
            SelectedNav = first;
        }

        _ = StartAsync();
    }

    public event Action? LoggedOut;

    public ObservableCollection<NavItem> NavItems { get; }
    public ICollectionView NavView { get; }
    public ICommand NavigateCommand { get; }
    public ICommand SyncCommand { get; }
    public ICommand LogoutCommand { get; }

    public string UserName => AppServices.Settings.Value.UserName ?? "Pengguna";
    public string RoleLabel => MapRole(AppServices.Settings.Value.UserRole);
    public string TenantLabel => string.IsNullOrWhiteSpace(AppServices.Settings.Value.TenantName)
        ? "POSQUPRO"
        : $"{AppServices.Settings.Value.TenantName} · {AppServices.Settings.Value.PlanName ?? "Plan"}";
    public string LicenseLabel => string.IsNullOrWhiteSpace(AppServices.Settings.Value.LicenseCode)
        ? "Lisensi belum tersedia"
        : $"Lisensi {AppServices.Settings.Value.LicenseCode}";

    public object? CurrentPage
    {
        get => _currentPage;
        private set => SetProperty(ref _currentPage, value);
    }

    public string CurrentPageTitle
    {
        get => _currentPageTitle;
        private set => SetProperty(ref _currentPageTitle, value);
    }

    public NavItem? SelectedNav
    {
        get => _selectedNav;
        set
        {
            if (!SetProperty(ref _selectedNav, value) || value is null)
            {
                return;
            }

            if (value.Key != _currentKey)
            {
                NavigateTo(value);
            }
        }
    }

    public bool IsOnline
    {
        get => _isOnline;
        private set => SetProperty(ref _isOnline, value);
    }

    public bool IsSyncing
    {
        get => _isSyncing;
        private set => SetProperty(ref _isSyncing, value);
    }

    public string SyncStatus
    {
        get => _syncStatus;
        private set => SetProperty(ref _syncStatus, value);
    }

    public string PendingLabel
    {
        get => _pendingLabel;
        private set => SetProperty(ref _pendingLabel, value);
    }

    public string LastSyncLabel
    {
        get => _lastSyncLabel;
        private set => SetProperty(ref _lastSyncLabel, value);
    }

    public string OnlineLabel => IsOnline ? "Online" : "Offline";

    public string FooterVersion => "POSQUPRO Desktop 1.0 · offline-first";

    public void Navigate(string key)
    {
        var item = NavItems.FirstOrDefault(candidate => candidate.Key == key);
        if (item is not null)
        {
            NavigateTo(item);
            _selectedNav = item;
            OnPropertyChanged(nameof(SelectedNav));
        }
    }

    public PosViewModel EnsurePos()
    {
        if (_pageCache.TryGetValue("pos", out var cached) && cached is PosViewModel existing)
        {
            return existing;
        }

        var created = new PosViewModel(this);
        _pageCache["pos"] = created;
        return created;
    }

    public void NavigateByShortcut(string shortcut)
    {
        var item = NavItems.FirstOrDefault(candidate =>
            string.Equals(candidate.Shortcut, shortcut, StringComparison.OrdinalIgnoreCase));
        if (item is not null)
        {
            Navigate(item.Key);
        }
    }

    private async Task StartAsync()
    {
        await AppServices.Sync.TickAsync();
        if (IsOnline && AppServices.Settings.Value.LastSyncAt is null)
        {
            await AppServices.Sync.RunAsync(full: true);
        }
    }

    private void NavigateTo(NavItem item)
    {
        _currentKey = item.Key;
        CurrentPageTitle = item.Label;

        if (_pageCache.TryGetValue(item.Key, out var cached) && item.Key == "pos")
        {
            CurrentPage = cached;
            return;
        }

        var (title, viewModel) = PageFactory.Create(item.Key, this);
        CurrentPageTitle = title;

        if (item.Key == "pos")
        {
            _pageCache[item.Key] = viewModel;
        }

        CurrentPage = viewModel;
    }

    private async Task SyncNowAsync()
    {
        await AppServices.Sync.RunAsync(full: true);
        RefreshSyncState();
    }

    private async Task LogoutAsync()
    {
        if (!Ui.Confirm("Keluar dari aplikasi? Data lokal tetap tersimpan.", "Logout"))
        {
            return;
        }

        _timer.Stop();
        AppServices.Sync.Changed -= OnSyncChanged;
        await AppServices.Auth.LogoutAsync();
        LoggedOut?.Invoke();
    }

    private void OnSyncChanged()
    {
        var dispatcher = Application.Current?.Dispatcher;
        if (dispatcher is null || dispatcher.CheckAccess())
        {
            RefreshSyncState();
        }
        else
        {
            dispatcher.Invoke(RefreshSyncState);
        }
    }

    private void RefreshSyncState()
    {
        IsOnline = AppServices.Sync.IsOnline;
        IsSyncing = AppServices.Sync.IsSyncing;
        SyncStatus = AppServices.Sync.StatusMessage;
        PendingLabel = AppServices.Sync.PendingCount == 0
            ? "Tersinkron"
            : $"{AppServices.Sync.PendingCount} antre";
        LastSyncLabel = AppServices.Sync.LastSyncAt is null
            ? "Belum pernah sinkron"
            : $"Sinkron terakhir {AppServices.Sync.LastSyncAt:dd MMM HH:mm}";
        OnPropertyChanged(nameof(OnlineLabel));
    }

    private static string MapRole(string? role) => (role ?? "").ToUpperInvariant() switch
    {
        "OWNER" => "Super Admin",
        "ADMIN" => "Admin",
        "MANAGER" => "Warehouse Manager",
        "CASHIER" => "Cashier",
        "FINANCE" => "Finance",
        _ => role ?? "Pengguna",
    };

    private IEnumerable<NavItem> BuildNavItems()
    {
        var role = MapRole(AppServices.Settings.Value.UserRole);
        bool Allowed(params string[] roles) => roles.Length == 0 || roles.Contains(role);

        var items = new List<NavItem>
        {
            new() { Key = "dashboard", Label = "Dashboard", Section = "UTAMA", Glyph = "\uE80F", Shortcut = "F1" },
            new() { Key = "pos", Label = "POS / Kasir", Section = "UTAMA", Glyph = "\uE7BF", Shortcut = "F2", Roles = ["Super Admin", "Admin", "Cashier"] },
            new() { Key = "parked", Label = "Transaksi Tertunda", Section = "UTAMA", Glyph = "\uE769", Roles = ["Super Admin", "Admin", "Cashier"] },

            new() { Key = "transactions", Label = "Riwayat Transaksi", Section = "PENJUALAN", Glyph = "\uE8A5", Shortcut = "F4", Roles = ["Super Admin", "Admin", "Finance"] },
            new() { Key = "customers", Label = "Pelanggan", Section = "PENJUALAN", Glyph = "\uE716", Roles = ["Super Admin", "Admin", "Cashier"] },
            new() { Key = "register", Label = "Kas & Shift", Section = "PENJUALAN", Glyph = "\uE8EF", Shortcut = "F9", Roles = ["Super Admin", "Admin", "Cashier"] },

            new() { Key = "products", Label = "Produk", Section = "INVENTORI", Glyph = "\uE7B8", Roles = ["Super Admin", "Admin", "Warehouse Manager", "Cashier"] },
            new() { Key = "categories", Label = "Kategori", Section = "INVENTORI", Glyph = "\uE8EC", Roles = ["Super Admin", "Admin", "Warehouse Manager"] },
            new() { Key = "units", Label = "Satuan", Section = "INVENTORI", Glyph = "\uE9D2", Roles = ["Super Admin", "Admin", "Warehouse Manager"] },
            new() { Key = "inventory", Label = "Inventory", Section = "INVENTORI", Glyph = "\uE7B8", Shortcut = "F5", Roles = ["Super Admin", "Admin", "Warehouse Manager"] },
            new() { Key = "warehouses", Label = "Gudang", Section = "INVENTORI", Glyph = "\uE80F", Roles = ["Super Admin", "Admin", "Warehouse Manager"] },
            new() { Key = "purchase-orders", Label = "Purchase Order", Section = "INVENTORI", Glyph = "\uE7BF", Shortcut = "F7", Roles = ["Super Admin", "Admin", "Warehouse Manager"] },
            new() { Key = "stock-counts", Label = "Stock Opname", Section = "INVENTORI", Glyph = "\uE9F9", Shortcut = "F8", Roles = ["Super Admin", "Admin", "Warehouse Manager"] },
            new() { Key = "suppliers", Label = "Supplier", Section = "INVENTORI", Glyph = "\uE716", Roles = ["Super Admin", "Admin", "Warehouse Manager"] },

            new() { Key = "reports", Label = "Laporan & Analitik", Section = "KEUANGAN", Glyph = "\uE9D2", Shortcut = "F6", Roles = ["Super Admin", "Admin", "Finance"] },
            new() { Key = "expenses", Label = "Pengeluaran", Section = "KEUANGAN", Glyph = "\uE8EF", Roles = ["Super Admin", "Admin", "Finance"] },
            new() { Key = "taxes", Label = "Pajak", Section = "KEUANGAN", Glyph = "\uE8EC", Roles = ["Super Admin", "Admin", "Finance"] },

            new() { Key = "branches", Label = "Cabang", Section = "ADMINISTRASI", Glyph = "\uE80F", Roles = ["Super Admin", "Admin"] },
            new() { Key = "users", Label = "Pengguna & RBAC", Section = "ADMINISTRASI", Glyph = "\uE716", Roles = ["Super Admin", "Admin"] },
            new() { Key = "activity-logs", Label = "Log Aktivitas", Section = "ADMINISTRASI", Glyph = "\uE8A5", Roles = ["Super Admin", "Admin", "Finance"] },
            new() { Key = "settings", Label = "Pengaturan", Section = "ADMINISTRASI", Glyph = "\uE713", Shortcut = "F10", Roles = ["Super Admin", "Admin"] },
            new() { Key = "sync", Label = "Sinkronisasi", Section = "ADMINISTRASI", Glyph = "\uE895" },
        };

        return items.Where(item => Allowed(item.Roles));
    }
}
