using System.Collections.ObjectModel;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public sealed class ChartBar
{
    public required string Label { get; init; }
    public required decimal Value { get; init; }
    public required double Height { get; init; }
    public string Tooltip => $"{Value:N0}";
}

public sealed class ReportsViewModel : ViewModelBase
{
    private DateTime? _from = DateTime.Today.AddDays(-29);
    private DateTime? _to = DateTime.Today;
    private decimal _revenue;
    private int _transactions;
    private decimal _average;
    private decimal _itemsSold;
    private decimal _expenses;

    public ReportsViewModel()
    {
        Daily = [];
        TopProducts = [];
        Payments = [];
        LowStock = [];
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        Preset7Command = new AsyncRelayCommand(() => ApplyPreset(7));
        Preset30Command = new AsyncRelayCommand(() => ApplyPreset(30));
        Preset90Command = new AsyncRelayCommand(() => ApplyPreset(90));
        _ = LoadAsync();
    }

    public ObservableCollection<ChartBar> Daily { get; }
    public ObservableCollection<TopProduct> TopProducts { get; }
    public ObservableCollection<PaymentBreakdown> Payments { get; }
    public ObservableCollection<Product> LowStock { get; }
    public ICommand RefreshCommand { get; }
    public ICommand Preset7Command { get; }
    public ICommand Preset30Command { get; }
    public ICommand Preset90Command { get; }

    public DateTime? From
    {
        get => _from;
        set => SetProperty(ref _from, value);
    }

    public DateTime? To
    {
        get => _to;
        set => SetProperty(ref _to, value);
    }

    public decimal Revenue
    {
        get => _revenue;
        private set => SetProperty(ref _revenue, value);
    }

    public int Transactions
    {
        get => _transactions;
        private set => SetProperty(ref _transactions, value);
    }

    public decimal Average
    {
        get => _average;
        private set => SetProperty(ref _average, value);
    }

    public decimal ItemsSold
    {
        get => _itemsSold;
        private set => SetProperty(ref _itemsSold, value);
    }

    public decimal Expenses
    {
        get => _expenses;
        private set => SetProperty(ref _expenses, value);
    }

    public decimal NetCashflow => Revenue - Expenses;

    public int TotalProducts { get; private set; }
    public decimal StockCostValue { get; private set; }
    public decimal StockSellValue { get; private set; }
    public int LowStockCount { get; private set; }

    private async Task ApplyPreset(int days)
    {
        From = DateTime.Today.AddDays(-(days - 1));
        To = DateTime.Today;
        await LoadAsync();
    }

    private async Task LoadAsync()
    {
        var from = From ?? DateTime.Today.AddDays(-29);
        var to = To ?? DateTime.Today;
        var report = await AppServices.Queries.GetSalesReportAsync(from, to);

        Revenue = report.Revenue;
        Transactions = report.Transactions;
        Average = report.AverageBasket;
        ItemsSold = report.ItemsSold;
        Expenses = report.Expenses;

        var max = report.Daily.Count == 0 ? 1 : report.Daily.Max(point => point.Total);
        Daily.Clear();
        foreach (var point in report.Daily)
        {
            Daily.Add(new ChartBar
            {
                Label = DateTime.TryParse(point.Date, out var date) ? date.ToString("dd/MM") : point.Date,
                Value = point.Total,
                Height = Math.Max(3, (double)(point.Total / max) * 130),
            });
        }

        TopProducts.Clear();
        foreach (var product in report.TopProducts)
        {
            TopProducts.Add(product);
        }

        Payments.Clear();
        foreach (var payment in report.Payments)
        {
            Payments.Add(payment);
        }

        var inventory = await AppServices.Queries.GetInventoryReportAsync();
        TotalProducts = inventory.TotalProducts;
        StockCostValue = inventory.StockCostValue;
        StockSellValue = inventory.StockSellValue;
        LowStockCount = inventory.LowStockCount;
        LowStock.Clear();
        foreach (var product in inventory.LowStock)
        {
            LowStock.Add(product);
        }

        OnPropertyChanged(nameof(NetCashflow));
        OnPropertyChanged(nameof(TotalProducts));
        OnPropertyChanged(nameof(StockCostValue));
        OnPropertyChanged(nameof(StockSellValue));
        OnPropertyChanged(nameof(LowStockCount));
    }
}
