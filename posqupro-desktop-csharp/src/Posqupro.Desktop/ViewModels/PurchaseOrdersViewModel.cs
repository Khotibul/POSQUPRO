using System.Collections.ObjectModel;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public sealed class PurchaseOrderItemDraft : ViewModelBase
{
    private Product? _product;
    private string _quantityText = "1";
    private string _unitCostText = "0";

    public Product? Product
    {
        get => _product;
        set => SetProperty(ref _product, value);
    }

    public string QuantityText
    {
        get => _quantityText;
        set => SetProperty(ref _quantityText, value);
    }

    public string UnitCostText
    {
        get => _unitCostText;
        set => SetProperty(ref _unitCostText, value);
    }

    public string LineSummary => Product is null
        ? "Pilih produk"
        : $"{Product.Name} × {QuantityText} @ Rp {UnitCostText}";
}

public sealed class PurchaseOrdersViewModel : ViewModelBase
{
    private PurchaseOrder? _selected;
    private Supplier? _selectedSupplier;
    private string _search = "";
    private bool _isEditorOpen;
    private string _notes = "";
    private string _expectedDateText = "";
    private decimal _subtotal;
    private decimal _grandTotal;
    private PurchaseOrderItemDraft? _selectedDraft;

    public PurchaseOrdersViewModel()
    {
        Orders = [];
        Suppliers = [];
        DraftItems = [];
        Products = [];
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        NewCommand = new RelayCommand(BeginNew);
        EditCommand = new RelayCommand(BeginEdit, () => _selected is not null && _selected.Status == "draft");
        CancelCommand = new RelayCommand(CancelEdit);
        SaveCommand = new AsyncRelayCommand(SaveAsync, () => _isEditorOpen);
        DeleteCommand = new AsyncRelayCommand(DeleteAsync, () => _selected is not null && _selected.Status == "draft");
        ReceiveCommand = new AsyncRelayCommand(ReceiveAsync, () => _selected is not null && _selected.Status is "draft" or "ordered");
        AddItemCommand = new AsyncRelayCommand(AddItemAsync, () => _isEditorOpen);
        RemoveDraftItemCommand = new RelayCommand(() =>
        {
            if (_selectedDraft is not null)
            {
                DraftItems.Remove(_selectedDraft);
                _selectedDraft = null;
                Recalculate();
            }
        }, () => _selectedDraft is not null);
        SearchCommand = new AsyncRelayCommand(LoadAsync);
        _ = LoadAsync();
    }

    public ObservableCollection<PurchaseOrder> Orders { get; }
    public ObservableCollection<Supplier> Suppliers { get; }
    public ObservableCollection<Product> Products { get; }
    public ObservableCollection<PurchaseOrderItemDraft> DraftItems { get; }
    public ICommand RefreshCommand { get; }
    public ICommand NewCommand { get; }
    public ICommand EditCommand { get; }
    public ICommand CancelCommand { get; }
    public ICommand SaveCommand { get; }
    public ICommand DeleteCommand { get; }
    public ICommand ReceiveCommand { get; }
    public ICommand AddItemCommand { get; }
    public ICommand RemoveDraftItemCommand { get; }
    public ICommand SearchCommand { get; }

    public string Search
    {
        get => _search;
        set => SetProperty(ref _search, value);
    }

    public PurchaseOrder? Selected
    {
        get => _selected;
        set
        {
            if (SetProperty(ref _selected, value))
            {
                OnPropertyChanged(nameof(SelectedItems));
                OnPropertyChanged(nameof(CanReceive));
                OnPropertyChanged(nameof(CanEdit));
            }
        }
    }

    public Supplier? SelectedSupplier
    {
        get => _selectedSupplier;
        set => SetProperty(ref _selectedSupplier, value);
    }

    public PurchaseOrderItemDraft? SelectedDraft
    {
        get => _selectedDraft;
        set => SetProperty(ref _selectedDraft, value);
    }

    public bool IsEditorOpen
    {
        get => _isEditorOpen;
        private set => SetProperty(ref _isEditorOpen, value);
    }

    public bool CanEdit => _selected is not null && _selected.Status == "draft";
    public bool CanReceive => _selected is not null && _selected.Status is "draft" or "ordered";

    public IReadOnlyList<PurchaseOrderItem> SelectedItems => Selected?.Items ?? [];

    public string Notes
    {
        get => _notes;
        set => SetProperty(ref _notes, value);
    }

    public string ExpectedDateText
    {
        get => _expectedDateText;
        set => SetProperty(ref _expectedDateText, value);
    }

    public decimal Subtotal
    {
        get => _subtotal;
        private set => SetProperty(ref _subtotal, value);
    }

    public decimal GrandTotal
    {
        get => _grandTotal;
        private set => SetProperty(ref _grandTotal, value);
    }

    public string StatusLabel => Selected is null ? "" : Selected.Status switch
    {
        "draft" => "Draf",
        "ordered" => "Dipesan",
        "received" => "Diterima",
        "cancelled" => "Dibatalkan",
        _ => Selected.Status,
    };

    private async Task LoadAsync()
    {
        var orders = await AppServices.Queries.GetPurchaseOrdersAsync();
        Orders.Clear();
        foreach (var order in orders)
        {
            if (!string.IsNullOrWhiteSpace(Search) &&
                !order.PoNumber.Contains(Search, StringComparison.OrdinalIgnoreCase) &&
                !order.SupplierName.Contains(Search, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            Orders.Add(order);
        }

        Suppliers.Clear();
        foreach (var supplier in await AppServices.Queries.GetSuppliersAsync())
        {
            Suppliers.Add(supplier);
        }

        Products.Clear();
        foreach (var product in await AppServices.Queries.GetProductsAsync())
        {
            Products.Add(product);
        }

        StatusMessage = $"{Orders.Count} purchase order.";
    }

    private void BeginNew()
    {
        Selected = null;
        DraftItems.Clear();
        Notes = "";
        ExpectedDateText = DateTime.Today.AddDays(7).ToString("yyyy-MM-dd");
        SelectedSupplier = Suppliers.FirstOrDefault();
        IsEditorOpen = true;
        Recalculate();
    }

    private void BeginEdit()
    {
        if (Selected is null)
        {
            return;
        }

        DraftItems.Clear();
        foreach (var item in Selected.Items)
        {
            DraftItems.Add(new PurchaseOrderItemDraft
            {
                Product = Products.FirstOrDefault(p => p.Id == item.ProductId) ?? item.Product,
                QuantityText = item.Quantity.ToString("0.##"),
                UnitCostText = item.UnitCost.ToString("0.##"),
            });
        }

        Notes = Selected.Notes ?? "";
        ExpectedDateText = Selected.ExpectedDate?.ToString("yyyy-MM-dd") ?? "";
        SelectedSupplier = Suppliers.FirstOrDefault(s => s.Id == Selected.SupplierId) ?? Selected.Supplier;
        IsEditorOpen = true;
        Recalculate();
    }

    private void CancelEdit()
    {
        IsEditorOpen = false;
        DraftItems.Clear();
    }

    private async Task AddItemAsync()
    {
        var product = Products.FirstOrDefault();
        if (product is null)
        {
            Ui.Error("Belum ada produk.");
            return;
        }

        var draft = new PurchaseOrderItemDraft
        {
            Product = product,
            QuantityText = "1",
            UnitCostText = product.CostPrice.ToString("0.##"),
        };
        DraftItems.Add(draft);
        SelectedDraft = draft;
        await Task.CompletedTask;
        Recalculate();
    }

    private async Task SaveAsync()
    {
        if (DraftItems.Count == 0)
        {
            Ui.Error("Tambahkan minimal satu item.");
            return;
        }

        if (SelectedSupplier is null)
        {
            Ui.Error("Pilih supplier.");
            return;
        }

        var items = new List<Dictionary<string, object?>>();
        foreach (var draft in DraftItems)
        {
            if (draft.Product is null || !decimal.TryParse(draft.QuantityText, out var qty) || qty <= 0)
            {
                Ui.Error("Item tidak valid.");
                return;
            }

            if (!decimal.TryParse(draft.UnitCostText, out var cost))
            {
                cost = 0;
            }

            items.Add(new Dictionary<string, object?>
            {
                ["product_id"] = draft.Product.Id,
                ["quantity"] = qty,
                ["unit_cost"] = cost,
                ["discount"] = 0m,
                ["subtotal"] = qty * cost,
            });
        }

        Recalculate();
        var values = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
        {
            ["po_number"] = $"PO-{DateTime.Now:yyMMddHHmmss}",
            ["supplier_id"] = SelectedSupplier.Id,
            ["user_id"] = AppServices.Settings.Value.UserId,
            ["status"] = "draft",
            ["expected_date"] = string.IsNullOrWhiteSpace(ExpectedDateText) ? null : ExpectedDateText,
            ["subtotal"] = Subtotal,
            ["discount"] = 0m,
            ["tax_amount"] = 0m,
            ["total"] = GrandTotal,
            ["notes"] = string.IsNullOrWhiteSpace(Notes) ? null : Notes.Trim(),
            ["created_at"] = DateTime.Now,
        };

        var existing = Selected;
        var isNew = existing is null;
        long localId;
        if (isNew)
        {
            localId = await AppServices.Db.InsertAsync("purchase_orders", values);
        }
        else
        {
            localId = existing!.Id;
            await AppServices.Db.UpdateAsync("purchase_orders", localId, values);
            await AppServices.Db.ExecuteAsync(
                "DELETE FROM purchase_order_items WHERE purchase_order_id=$id",
                new { id = localId });
        }

        foreach (var item in items)
        {
            item["purchase_order_id"] = localId;
            var itemId = await AppServices.Db.InsertAsync("purchase_order_items", item);
            await AppServices.Db.EnqueueAsync("purchase_order_item", isNew ? "create" : "update", itemId, item);
        }

        await AppServices.Db.EnqueueAsync(
            "purchase_order",
            isNew ? "create" : "update",
            localId,
            new Dictionary<string, object?>(values));

        IsEditorOpen = false;
        DraftItems.Clear();
        StatusMessage = isNew ? "Purchase order dibuat." : "Purchase order diperbarui.";
        await LoadAsync();
        await AppServices.Sync.RefreshCountersAsync();
    }

    private async Task DeleteAsync()
    {
        if (Selected is null || Selected.Status != "draft" || !Ui.Confirm($"Hapus {Selected.PoNumber}?", "Hapus"))
        {
            return;
        }

        await AppServices.Db.ExecuteAsync(
            "DELETE FROM purchase_order_items WHERE purchase_order_id=$id",
            new { id = Selected.Id });
        await AppServices.Db.DeleteAsync("purchase_orders", Selected.Id);

        if (Selected.ServerId is not null)
        {
            await AppServices.Db.EnqueueAsync("purchase_order", "delete", Selected.Id, new
            {
                server_id = Selected.ServerId,
            });
        }

        Selected = null;
        StatusMessage = "Purchase order dihapus.";
        await LoadAsync();
        await AppServices.Sync.RefreshCountersAsync();
    }

    private async Task ReceiveAsync()
    {
        if (Selected is null || Selected.Items.Count == 0)
        {
            Ui.Error("Purchase order tanpa item.");
            return;
        }

        if (!Ui.Confirm($"Terima barang untuk {Selected.PoNumber}?", "Terima Barang"))
        {
            return;
        }

        var items = Selected.Items.Select(item => new Dictionary<string, object?>
        {
            ["purchase_order_item_id"] = item.Id,
            ["quantity"] = item.Quantity - item.ReceivedQuantity,
        }).Where(pair => Convert.ToDecimal(pair["quantity"] ?? 0) > 0).ToList();

        if (items.Count == 0)
        {
            Ui.Error("Semua item sudah diterima.");
            return;
        }

        await AppServices.Db.EnqueueAsync("purchase_order", "receive", Selected.Id, new
        {
            items,
        });

        StatusMessage = "Penerimaan diantrekan untuk sinkronisasi.";
        await LoadAsync();
        await AppServices.Sync.RefreshCountersAsync();
        await AppServices.Sync.RunAsync();
    }

    private void Recalculate()
    {
        decimal subtotal = 0;
        foreach (var draft in DraftItems)
        {
            if (!decimal.TryParse(draft.QuantityText, out var qty))
            {
                qty = 0;
            }

            if (!decimal.TryParse(draft.UnitCostText, out var cost))
            {
                cost = 0;
            }

            subtotal += qty * cost;
        }

        Subtotal = subtotal;
        GrandTotal = subtotal;
    }
}
