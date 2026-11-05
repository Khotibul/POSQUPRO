using System.Collections.ObjectModel;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public sealed class StockCountItemDraft : ViewModelBase
{
    private Product? _product;
    private string _countedText = "";

    public Product? Product
    {
        get => _product;
        set => SetProperty(ref _product, value);
    }

    public decimal SystemQuantity { get; set; }

    public string CountedText
    {
        get => _countedText;
        set
        {
            if (SetProperty(ref _countedText, value))
            {
                OnPropertyChanged(nameof(Variance));
                OnPropertyChanged(nameof(LineSummary));
            }
        }
    }

    public decimal? Counted
    {
        get
        {
            if (string.IsNullOrWhiteSpace(CountedText))
            {
                return null;
            }

            return decimal.TryParse(CountedText, out var value) ? value : null;
        }
    }

    public decimal? Variance => Counted is null ? null : Counted.Value - SystemQuantity;

    public string LineSummary => Product is null
        ? "Pilih produk"
        : $"{Product.Name} · sistem {SystemQuantity:0.##} · hitung {CountedText}";
}

public sealed class StockCountsViewModel : ViewModelBase
{
    private StockCount? _selected;
    private string _search = "";
    private bool _isEditorOpen;
    private bool _isBlind;
    private string _notes = "";
    private StockCountItemDraft? _selectedDraft;
    private Product? _newProduct;

    public StockCountsViewModel()
    {
        Counts = [];
        DraftItems = [];
        Products = [];
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        NewCommand = new RelayCommand(BeginNew);
        CancelCommand = new RelayCommand(CancelEdit);
        SaveCommand = new AsyncRelayCommand(SaveAsync, () => _isEditorOpen);
        DeleteCommand = new AsyncRelayCommand(DeleteAsync, () => _selected is not null && _selected.Status == "draft");
        PostCommand = new AsyncRelayCommand(PostAsync, () => _selected is not null && _selected.Status is "draft" or "counted");
        AddItemCommand = new AsyncRelayCommand(AddItemAsync, () => _isEditorOpen);
        RemoveDraftItemCommand = new RelayCommand(() =>
        {
            if (_selectedDraft is not null)
            {
                DraftItems.Remove(_selectedDraft);
                _selectedDraft = null;
            }
        }, () => _selectedDraft is not null);
        SearchCommand = new AsyncRelayCommand(LoadAsync);
        _ = LoadAsync();
    }

    public ObservableCollection<StockCount> Counts { get; }
    public ObservableCollection<StockCountItemDraft> DraftItems { get; }
    public ObservableCollection<Product> Products { get; }
    public ICommand RefreshCommand { get; }
    public ICommand NewCommand { get; }
    public ICommand CancelCommand { get; }
    public ICommand SaveCommand { get; }
    public ICommand DeleteCommand { get; }
    public ICommand PostCommand { get; }
    public ICommand AddItemCommand { get; }
    public ICommand RemoveDraftItemCommand { get; }
    public ICommand SearchCommand { get; }

    public string Search
    {
        get => _search;
        set => SetProperty(ref _search, value);
    }

    public StockCount? Selected
    {
        get => _selected;
        set
        {
            if (SetProperty(ref _selected, value))
            {
                OnPropertyChanged(nameof(SelectedItems));
                OnPropertyChanged(nameof(CanPost));
                OnPropertyChanged(nameof(StatusLabel));
            }
        }
    }

    public StockCountItemDraft? SelectedDraft
    {
        get => _selectedDraft;
        set => SetProperty(ref _selectedDraft, value);
    }

    public Product? NewProduct
    {
        get => _newProduct;
        set => SetProperty(ref _newProduct, value);
    }

    public bool IsEditorOpen
    {
        get => _isEditorOpen;
        private set => SetProperty(ref _isEditorOpen, value);
    }

    public bool IsBlind
    {
        get => _isBlind;
        set => SetProperty(ref _isBlind, value);
    }

    public string Notes
    {
        get => _notes;
        set => SetProperty(ref _notes, value);
    }

    public bool CanPost => Selected is not null && Selected.Status is "draft" or "counted";

    public IReadOnlyList<StockCountItem> SelectedItems => Selected?.Items ?? [];

    public string StatusLabel => Selected is null ? "" : Selected.Status switch
    {
        "draft" => "Draf",
        "counted" => "Dihitung",
        "approved" => "Disetujui",
        "posted" => "Diposting",
        _ => Selected.Status,
    };

    private async Task LoadAsync()
    {
        var counts = await AppServices.Queries.GetStockCountsAsync();
        Counts.Clear();
        foreach (var count in counts)
        {
            if (!string.IsNullOrWhiteSpace(Search) &&
                !count.CountNumber.Contains(Search, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            Counts.Add(count);
        }

        Products.Clear();
        foreach (var product in await AppServices.Queries.GetProductsAsync())
        {
            Products.Add(product);
        }

        StatusMessage = $"{Counts.Count} stock opname.";
    }

    private void BeginNew()
    {
        Selected = null;
        DraftItems.Clear();
        Notes = "";
        IsBlind = false;
        IsEditorOpen = true;
    }

    private void CancelEdit()
    {
        IsEditorOpen = false;
        DraftItems.Clear();
    }

    private async Task AddItemAsync()
    {
        var product = NewProduct ?? Products.FirstOrDefault();
        if (product is null)
        {
            Ui.Error("Belum ada produk.");
            return;
        }

        if (DraftItems.Any(draft => draft.Product?.Id == product.Id))
        {
            Ui.Error("Produk sudah ada di daftar.");
            return;
        }

        var draft = new StockCountItemDraft
        {
            Product = product,
            SystemQuantity = product.Stock,
            CountedText = product.Stock.ToString("0.##"),
        };
        DraftItems.Add(draft);
        SelectedDraft = draft;
        NewProduct = null;
        await Task.CompletedTask;
    }

    private async Task SaveAsync()
    {
        if (DraftItems.Count == 0)
        {
            Ui.Error("Tambahkan minimal satu produk.");
            return;
        }

        var values = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
        {
            ["count_number"] = $"SC-{DateTime.Now:yyMMddHHmmss}",
            ["user_id"] = AppServices.Settings.Value.UserId,
            ["status"] = "counted",
            ["is_blind"] = IsBlind,
            ["counted_at"] = DateTime.Now,
            ["notes"] = string.IsNullOrWhiteSpace(Notes) ? null : Notes.Trim(),
            ["created_at"] = DateTime.Now,
        };

        var existing = Selected;
        var isNew = existing is null;
        long localId;
        if (isNew)
        {
            localId = await AppServices.Db.InsertAsync("stock_counts", values);
        }
        else
        {
            localId = existing!.Id;
            await AppServices.Db.UpdateAsync("stock_counts", localId, values);
            await AppServices.Db.ExecuteAsync(
                "DELETE FROM stock_count_items WHERE stock_count_id=$id",
                new { id = localId });
        }

        foreach (var draft in DraftItems)
        {
            if (draft.Product is null)
            {
                continue;
            }

            var item = new Dictionary<string, object?>
            {
                ["stock_count_id"] = localId,
                ["product_id"] = draft.Product.Id,
                ["system_quantity"] = draft.SystemQuantity,
                ["counted_quantity"] = draft.Counted,
                ["variance"] = draft.Variance,
                ["notes"] = null,
            };

            var itemId = await AppServices.Db.InsertAsync("stock_count_items", item);
            await AppServices.Db.EnqueueAsync("stock_count_item", isNew ? "create" : "update", itemId, item);
        }

        await AppServices.Db.EnqueueAsync(
            "stock_count",
            isNew ? "create" : "update",
            localId,
            new Dictionary<string, object?>(values));

        IsEditorOpen = false;
        DraftItems.Clear();
        StatusMessage = isNew ? "Stock opname dibuat." : "Stock opname diperbarui.";
        await LoadAsync();
        await AppServices.Sync.RefreshCountersAsync();
    }

    private async Task DeleteAsync()
    {
        if (Selected is null || Selected.Status != "draft" || !Ui.Confirm($"Hapus {Selected.CountNumber}?", "Hapus"))
        {
            return;
        }

        await AppServices.Db.ExecuteAsync(
            "DELETE FROM stock_count_items WHERE stock_count_id=$id",
            new { id = Selected.Id });
        await AppServices.Db.DeleteAsync("stock_counts", Selected.Id);

        if (Selected.ServerId is not null)
        {
            await AppServices.Db.EnqueueAsync("stock_count", "delete", Selected.Id, new
            {
                server_id = Selected.ServerId,
            });
        }

        Selected = null;
        StatusMessage = "Stock opname dihapus.";
        await LoadAsync();
        await AppServices.Sync.RefreshCountersAsync();
    }

    private async Task PostAsync()
    {
        if (Selected is null)
        {
            return;
        }

        if (Selected.Items.All(item => item.CountedQuantity is null))
        {
            Ui.Error("Belum ada hasil hitung.");
            return;
        }

        if (!Ui.Confirm($"Posting stok untuk {Selected.CountNumber}? Stok produk akan disesuaikan.", "Posting"))
        {
            return;
        }

        await AppServices.Db.EnqueueAsync("stock_count", "post", Selected.Id, new
        {
            items = Selected.Items
                .Where(item => item.CountedQuantity is not null)
                .Select(item => new Dictionary<string, object?>
                {
                    ["stock_count_item_id"] = item.Id,
                    ["product_id"] = item.ProductId,
                    ["counted_quantity"] = item.CountedQuantity,
                })
                .ToList<object?>(),
        });

        await AppServices.Db.UpdateAsync("stock_counts", Selected.Id, new Dictionary<string, object?>
        {
            ["status"] = "posted",
            ["posted_at"] = DateTime.Now,
        });

        StatusMessage = "Posting stok diantrekan.";
        await LoadAsync();
        await AppServices.Sync.RefreshCountersAsync();
        await AppServices.Sync.RunAsync();
    }
}
