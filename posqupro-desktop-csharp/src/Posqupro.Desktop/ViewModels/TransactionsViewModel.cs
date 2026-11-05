using System.Collections.ObjectModel;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;
using Posqupro.Desktop.Views;

namespace Posqupro.Desktop.ViewModels;

public sealed class TransactionTypeOption
{
    public required string Key { get; init; }
    public required string Label { get; init; }
    public override string ToString() => Label;
}

public sealed class TransactionsViewModel : ViewModelBase
{
    private Transaction? _selected;
    private string _search = "";
    private TransactionTypeOption? _selectedType;
    private DateTime? _from = DateTime.Today.AddDays(-30);
    private DateTime? _to = DateTime.Today;
    private bool _isDetailOpen;

    public TransactionsViewModel()
    {
        Transactions = [];
        DetailItems = [];
        Types =
        [
            new TransactionTypeOption { Key = "", Label = "Semua Tipe" },
            new TransactionTypeOption { Key = "sell", Label = "Penjualan" },
            new TransactionTypeOption { Key = "buy", Label = "Pembelian" },
        ];
        SelectedType = Types[0];
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        PrintCommand = new AsyncRelayCommand(PrintAsync, () => _selected is not null);
        VoidCommand = new AsyncRelayCommand(VoidAsync, () => _selected is not null);
        CloseDetailCommand = new RelayCommand(() => IsDetailOpen = false);
        _ = LoadAsync();
    }

    public ObservableCollection<Transaction> Transactions { get; }
    public ObservableCollection<TransactionItem> DetailItems { get; }
    public IReadOnlyList<TransactionTypeOption> Types { get; }
    public ICommand RefreshCommand { get; }
    public ICommand PrintCommand { get; }
    public ICommand VoidCommand { get; }
    public ICommand CloseDetailCommand { get; }

    public string Search
    {
        get => _search;
        set => SetProperty(ref _search, value);
    }

    public TransactionTypeOption? SelectedType
    {
        get => _selectedType;
        set => SetProperty(ref _selectedType, value);
    }

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

    public Transaction? Selected
    {
        get => _selected;
        set
        {
            if (SetProperty(ref _selected, value))
            {
                _ = LoadDetailAsync();
            }
        }
    }

    public bool IsDetailOpen
    {
        get => _isDetailOpen;
        private set => SetProperty(ref _isDetailOpen, value);
    }

    public string DetailInvoice => Selected?.InvoiceNumber ?? "";
    public string DetailCustomer => Selected?.CustomerName ?? "Umum";
    public string DetailCashier => Selected?.CashierName ?? "";
    public decimal DetailSubtotal => Selected?.Subtotal ?? 0;
    public decimal DetailDiscount => Selected?.Discount ?? 0;
    public decimal DetailTax => Selected?.TaxAmount ?? 0;
    public decimal DetailTotal => Selected?.Total ?? 0;
    public decimal DetailPaid => Selected?.PaidAmount ?? 0;
    public decimal DetailChange => Selected?.ChangeAmount ?? 0;
    public string DetailMethod => Selected?.PaymentMethod ?? "";
    public string DetailDate => Selected?.CreatedAt?.ToString("dd MMM yyyy HH:mm") ?? "";

    private async Task LoadAsync()
    {
        var rows = await AppServices.Queries.GetTransactionsAsync(
            string.IsNullOrWhiteSpace(Search) ? null : Search,
            SelectedType?.Key,
            From,
            To);

        Transactions.Clear();
        foreach (var transaction in rows)
        {
            Transactions.Add(transaction);
        }

        StatusMessage = $"{Transactions.Count} transaksi ditemukan.";
    }

    private async Task LoadDetailAsync()
    {
        DetailItems.Clear();
        if (Selected is null)
        {
            IsDetailOpen = false;
            return;
        }

        foreach (var item in await AppServices.Queries.GetTransactionItemsAsync(Selected.Id))
        {
            DetailItems.Add(item);
        }

        IsDetailOpen = true;
        OnPropertyChanged(nameof(DetailInvoice));
        OnPropertyChanged(nameof(DetailCustomer));
        OnPropertyChanged(nameof(DetailCashier));
        OnPropertyChanged(nameof(DetailSubtotal));
        OnPropertyChanged(nameof(DetailDiscount));
        OnPropertyChanged(nameof(DetailTax));
        OnPropertyChanged(nameof(DetailTotal));
        OnPropertyChanged(nameof(DetailPaid));
        OnPropertyChanged(nameof(DetailChange));
        OnPropertyChanged(nameof(DetailMethod));
        OnPropertyChanged(nameof(DetailDate));
    }

    private async Task PrintAsync()
    {
        if (Selected is null)
        {
            return;
        }

        if (DetailItems.Count == 0)
        {
            await LoadDetailAsync();
        }

        var sale = new SaleResult
        {
            TransactionId = Selected.Id,
            InvoiceNumber = Selected.InvoiceNumber,
            Subtotal = Selected.Subtotal,
            Discount = Selected.Discount,
            Tax = Selected.TaxAmount,
            Total = Selected.Total,
            Paid = Selected.PaidAmount,
            Change = Selected.ChangeAmount,
            PaymentMethod = Selected.PaymentMethod ?? "CASH",
            CustomerName = Selected.CustomerName,
            CreatedAt = Selected.CreatedAt ?? DateTime.Now,
            Lines = DetailItems.Select(item => new SaleLineInput
            {
                ProductId = item.ProductId ?? 0,
                ProductName = item.ProductName ?? item.Product?.Name ?? "Produk",
                Quantity = item.Quantity,
                UnitPrice = item.UnitPrice,
                Discount = item.Discount,
            }).ToList(),
        };

        var text = await new ReceiptService(AppServices.Settings).BuildTextAsync(sale);
        var window = new ReceiptWindow(sale, text) { Owner = System.Windows.Application.Current.MainWindow };
        window.ShowDialog();
    }

    private async Task VoidAsync()
    {
        if (Selected is null || !Ui.Confirm($"Hapus transaksi {Selected.InvoiceNumber}?", "Hapus Transaksi"))
        {
            return;
        }

        StatusMessage = await AppServices.Sales.VoidTransactionAsync(Selected);
        Selected = null;
        IsDetailOpen = false;
        await LoadAsync();
        await AppServices.Sync.RefreshCountersAsync();
    }
}
