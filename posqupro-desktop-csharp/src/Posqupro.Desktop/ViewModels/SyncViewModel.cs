using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public sealed class SyncViewModel : ViewModelBase
{
    private SyncQueueItem? _selected;
    private bool _autoSync;
    private string _baseUrl = "";
    private bool _isOnline;
    private bool _isSyncing;
    private int _pending;
    private int _failed;
    private string _lastSync = "";

    public SyncViewModel()
    {
        Queue = [];
        RunCommand = new AsyncRelayCommand(SyncNowAsync);
        RetryCommand = new AsyncRelayCommand(RetryAsync, () => _selected is not null);
        DiscardCommand = new AsyncRelayCommand(DiscardAsync, () => _selected is not null);
        SaveConnectionCommand = new AsyncRelayCommand(SaveConnectionAsync);
        RefreshCommand = new AsyncRelayCommand(RefreshAsync);
        AutoSync = AppServices.Settings.Value.AutoSync;
        BaseUrl = AppServices.Settings.NormalizedBaseUrl;
        AppServices.Sync.Changed += OnSyncChanged;
        _ = RefreshAsync();
    }

    public ObservableCollection<SyncQueueItem> Queue { get; }
    public ICommand RunCommand { get; }
    public ICommand RetryCommand { get; }
    public ICommand DiscardCommand { get; }
    public ICommand SaveConnectionCommand { get; }
    public ICommand RefreshCommand { get; }

    public SyncQueueItem? Selected
    {
        get => _selected;
        set => SetProperty(ref _selected, value);
    }

    public bool AutoSync
    {
        get => _autoSync;
        set
        {
            if (SetProperty(ref _autoSync, value))
            {
                AppServices.Settings.Value.AutoSync = value;
                AppServices.Settings.Save();
                StatusMessage = value ? "Sinkronisasi otomatis aktif." : "Sinkronisasi otomatis dimatikan.";
            }
        }
    }

    public string BaseUrl
    {
        get => _baseUrl;
        set => SetProperty(ref _baseUrl, value);
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

    public int Pending
    {
        get => _pending;
        private set => SetProperty(ref _pending, value);
    }

    public int Failed
    {
        get => _failed;
        private set => SetProperty(ref _failed, value);
    }

    public string LastSync
    {
        get => _lastSync;
        private set => SetProperty(ref _lastSync, value);
    }

    public string DeviceId => AppServices.Settings.Value.DeviceId;

    private void OnSyncChanged()
    {
        var dispatcher = Application.Current?.Dispatcher;
        if (dispatcher is null || dispatcher.CheckAccess())
        {
            _ = RefreshAsync();
        }
        else
        {
            dispatcher.Invoke(() => _ = RefreshAsync());
        }
    }

    private async Task RefreshAsync()
    {
        var queue = await AppServices.Db.GetQueueAsync();
        Queue.Clear();
        foreach (var item in queue)
        {
            Queue.Add(item);
        }

        Pending = queue.Count;
        Failed = queue.Count(item => item.Attempts > 0);
        IsOnline = AppServices.Sync.IsOnline;
        IsSyncing = AppServices.Sync.IsSyncing;
        LastSync = AppServices.Sync.LastSyncAt is null
            ? "Belum pernah sinkron"
            : AppServices.Sync.LastSyncAt.Value.ToString("dd MMM yyyy HH:mm:ss");
        OnPropertyChanged(nameof(DeviceId));
    }

    private async Task SyncNowAsync()
    {
        await AppServices.Sync.RunAsync(full: true);
        await RefreshAsync();
        StatusMessage = AppServices.Sync.StatusMessage;
    }

    private async Task RetryAsync()
    {
        if (Selected is null)
        {
            return;
        }

        await AppServices.Sync.RetryQueueItemAsync(Selected.Id);
        await RefreshAsync();
    }

    private async Task DiscardAsync()
    {
        if (Selected is null || !Ui.Confirm("Buang perubahan yang gagal disinkronkan? Data di server tidak akan berubah.", "Buang Antrean"))
        {
            return;
        }

        await AppServices.Sync.DiscardQueueItemAsync(Selected.Id);
        await RefreshAsync();
    }

    private async Task SaveConnectionAsync()
    {
        AppServices.Settings.Value.BaseUrl = BaseUrl.Trim();
        AppServices.Settings.Save();
        StatusMessage = "Alamat server disimpan.";
        await AppServices.Sync.TickAsync();
        await RefreshAsync();
    }
}
