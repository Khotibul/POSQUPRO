using System.Collections.ObjectModel;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public sealed class MovementOption
{
    public required string Key { get; init; }
    public required string Label { get; init; }
    public override string ToString() => Label;
}

public sealed class InventoryViewModel : ViewModelBase
{
    private Product? _selectedProduct;
    private InventoryHistory? _selectedHistory;
    private MovementOption? _selectedMovement;
    private string _quantityText = "";
    private string _reason = "";
    private int _totalProducts;
    private decimal _stockValue;
    private int _lowStockCount;

    public InventoryViewModel()
    {
        Products = [];
        History = [];
        Movements =
        [
            new MovementOption { Key = "in", Label = "Stok Masuk" },
            new MovementOption { Key = "out", Label = "Stok Keluar" },
            new MovementOption { Key = "adjustment", Label = "Set Stok (Opname)" },
        ];
        SelectedMovement = Movements[0];
        AdjustCommand = new AsyncRelayCommand(AdjustAsync, () => _selectedProduct is not null);
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        _ = LoadAsync();
    }

    public ObservableCollection<Product> Products { get; }
    public ObservableCollection<InventoryHistory> History { get; }
    public IReadOnlyList<MovementOption> Movements { get; }
    public ICommand AdjustCommand { get; }
    public ICommand RefreshCommand { get; }

    public Product? SelectedProduct
    {
        get => _selectedProduct;
        set => SetProperty(ref _selectedProduct, value);
    }

    public InventoryHistory? SelectedHistory
    {
        get => _selectedHistory;
        set => SetProperty(ref _selectedHistory, value);
    }

    public MovementOption? SelectedMovement
    {
        get => _selectedMovement;
        set => SetProperty(ref _selectedMovement, value);
    }

    public string QuantityText
    {
        get => _quantityText;
        set => SetProperty(ref _quantityText, value);
    }

    public string Reason
    {
        get => _reason;
        set => SetProperty(ref _reason, value);
    }

    public int TotalProducts
    {
        get => _totalProducts;
        private set => SetProperty(ref _totalProducts, value);
    }

    public decimal StockValue
    {
        get => _stockValue;
        private set => SetProperty(ref _stockValue, value);
    }

    public int LowStockCount
    {
        get => _lowStockCount;
        private set => SetProperty(ref _lowStockCount, value);
    }

    private async Task LoadAsync()
    {
        var products = await AppServices.Queries.GetProductsAsync();
        Products.Clear();
        foreach (var product in products)
        {
            Products.Add(product);
        }

        var history = await AppServices.Queries.GetInventoryHistoryAsync();
        History.Clear();
        foreach (var entry in history)
        {
            History.Add(entry);
        }

        var report = await AppServices.Queries.GetInventoryReportAsync();
        TotalProducts = report.TotalProducts;
        StockValue = report.StockCostValue;
        LowStockCount = report.LowStockCount;
    }

    private async Task AdjustAsync()
    {
        if (SelectedProduct is null || SelectedMovement is null)
        {
            return;
        }

        if (!decimal.TryParse(QuantityText, out var quantity) || quantity <= 0)
        {
            Ui.Error("Jumlah stok harus lebih dari 0.");
            return;
        }

        await AppServices.Sales.AdjustStockAsync(
            SelectedProduct.Id,
            SelectedMovement.Key,
            quantity,
            string.IsNullOrWhiteSpace(Reason) ? null : Reason.Trim());

        StatusMessage = $"Stok {SelectedProduct.Name} diperbarui.";
        QuantityText = "";
        Reason = "";
        await LoadAsync();
        await AppServices.Sync.RefreshCountersAsync();
    }
}
