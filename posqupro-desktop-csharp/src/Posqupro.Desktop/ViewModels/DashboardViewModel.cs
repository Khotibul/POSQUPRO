using System.Collections.ObjectModel;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public sealed class DashboardViewModel : ViewModelBase
{
    private readonly ShellViewModel _shell;
    private decimal _todayRevenue;
    private int _todayTransactions;
    private decimal _monthRevenue;
    private int _lowStockCount;
    private string _greeting = "";

    public DashboardViewModel(ShellViewModel shell)
    {
        _shell = shell;
        RecentTransactions = [];
        LowStockProducts = [];
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        OpenPosCommand = new RelayCommand(() => shell.Navigate("pos"));
        OpenProductsCommand = new RelayCommand(() => shell.Navigate("products"));
        OpenReportsCommand = new RelayCommand(() => shell.Navigate("reports"));
        Greeting = $"Halo, {AppServices.Settings.Value.UserName ?? "Pengguna"}";
        _ = LoadAsync();
    }

    public ObservableCollection<Transaction> RecentTransactions { get; }
    public ObservableCollection<Product> LowStockProducts { get; }
    public ICommand RefreshCommand { get; }
    public ICommand OpenPosCommand { get; }
    public ICommand OpenProductsCommand { get; }
    public ICommand OpenReportsCommand { get; }

    public string Greeting
    {
        get => _greeting;
        private set => SetProperty(ref _greeting, value);
    }

    public string TodayLabel => DateTime.Now.ToString("dddd, dd MMMM yyyy");
    public string StoreLabel => AppServices.Settings.Value.TenantName ?? "POSQUPRO";

    public decimal TodayRevenue
    {
        get => _todayRevenue;
        private set => SetProperty(ref _todayRevenue, value);
    }

    public int TodayTransactions
    {
        get => _todayTransactions;
        private set => SetProperty(ref _todayTransactions, value);
    }

    public decimal MonthRevenue
    {
        get => _monthRevenue;
        private set => SetProperty(ref _monthRevenue, value);
    }

    public int LowStockCount
    {
        get => _lowStockCount;
        private set => SetProperty(ref _lowStockCount, value);
    }

    private async Task LoadAsync()
    {
        var data = await AppServices.Queries.GetDashboardAsync();
        TodayRevenue = data.TodayRevenue;
        TodayTransactions = data.TodayTransactions;
        MonthRevenue = data.MonthRevenue;
        LowStockCount = data.LowStockCount;

        RecentTransactions.Clear();
        foreach (var transaction in data.RecentTransactions)
        {
            RecentTransactions.Add(transaction);
        }

        LowStockProducts.Clear();
        foreach (var product in data.LowStockProducts)
        {
            LowStockProducts.Add(product);
        }
    }
}
