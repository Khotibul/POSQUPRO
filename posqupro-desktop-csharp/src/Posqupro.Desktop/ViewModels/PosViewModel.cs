using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;
using Posqupro.Desktop.Views;

namespace Posqupro.Desktop.ViewModels;

public sealed class CartLine : ViewModelBase
{
    private decimal _quantity;
    private decimal _discount;
    private decimal _unitPrice;
    private string _quantityText;
    private string _priceText;

    public CartLine(Product product, decimal quantity = 1, decimal unitPrice = 0, decimal discount = 0)
    {
        Product = product;
        _quantity = quantity;
        _unitPrice = unitPrice > 0 ? unitPrice : product.EffectivePrice;
        _discount = discount;
        _quantityText = quantity.ToString("0.##");
        _priceText = ((int)_unitPrice).ToString();
    }

    public Product Product { get; }
    public long ProductId => Product.Id;
    public string Name => Product.Name;
    public string? Sku => Product.Sku;
    public decimal MaxQuantity => Product.Stock;
    public string StockLabel => Product.Type == "service" ? "Jasa" : $"Stok {Product.Stock:0.##}";
    public decimal TaxRate => Product.TaxRate;

    public decimal UnitPrice
    {
        get => _unitPrice;
        set
        {
            if (SetProperty(ref _unitPrice, Math.Max(0, value)))
            {
                _priceText = ((int)_unitPrice).ToString();
                OnPropertyChanged(nameof(PriceText));
                OnPropertyChanged(nameof(Subtotal));
            }
        }
    }

    public string PriceText
    {
        get => _priceText;
        set
        {
            if (SetProperty(ref _priceText, value))
            {
                if (decimal.TryParse(value, out var parsed))
                {
                    UnitPrice = parsed;
                }
            }
        }
    }

    public decimal Quantity
    {
        get => _quantity;
        set
        {
            var next = Math.Max(0, value);
            if (Product.Type != "service" && next > Product.Stock)
            {
                next = Product.Stock;
            }

            if (SetProperty(ref _quantity, next))
            {
                _quantityText = next.ToString("0.##");
                OnPropertyChanged(nameof(QuantityText));
                OnPropertyChanged(nameof(Subtotal));
            }
        }
    }

    public string QuantityText
    {
        get => _quantityText;
        set
        {
            if (SetProperty(ref _quantityText, value))
            {
                if (decimal.TryParse(value, out var parsed))
                {
                    Quantity = parsed;
                }
            }
        }
    }

    public decimal Discount
    {
        get => _discount;
        set
        {
            if (SetProperty(ref _discount, Math.Max(0, value)))
            {
                OnPropertyChanged(nameof(Subtotal));
            }
        }
    }

    public decimal Subtotal => Math.Max(0, Quantity * UnitPrice - Discount);
}

public sealed class PosViewModel : ViewModelBase
{
    private readonly ShellViewModel _shell;
    private readonly Dictionary<string, Product> _productsById = [];
    private CancellationTokenSource? _searchCts;
    private bool _paidTouched;
    private bool _recalculating;

    private string _searchText = "";
    private string _barcodeText = "";
    private Category? _selectedCategory;
    private Customer? _selectedCustomer;
    private PaymentMethod? _selectedPaymentMethod;
    private string _discountText = "0";
    private int _discountTypeIndex;
    private string _paidText = "0";
    private string _notes = "";
    private decimal _subtotal;
    private decimal _discountValue;
    private decimal _taxAmount;
    private decimal _grandTotal;
    private decimal _change;
    private string _barcodeFeedback = "";
    private bool _autoPrint = true;
    private bool _canEditPrice = true;
    private bool _canPark = true;
    private int _parkedCount;

    public PosViewModel(ShellViewModel shell)
    {
        _shell = shell;
        Products = [];
        Cart = [];
        Categories = [];
        Customers = [];
        PaymentMethods = [];

        AddToCartCommand = new RelayCommand<Product>(product =>
        {
            if (product is not null)
            {
                AddProduct(product);
            }
        });
        AddByCodeCommand = new AsyncRelayCommand(AddByCodeAsync);
        SearchEnterCommand = new AsyncRelayCommand(SearchEnterAsync);
        IncreaseCommand = new RelayCommand<CartLine>(line => ChangeQuantity(line, 1));
        DecreaseCommand = new RelayCommand<CartLine>(line => ChangeQuantity(line, -1));
        RemoveCommand = new RelayCommand<CartLine>(RemoveLine);
        ClearCartCommand = new RelayCommand(ClearCart);
        ParkCommand = new AsyncRelayCommand(ParkAsync, () => CanPark);
        CheckoutCommand = new AsyncRelayCommand(CheckoutAsync, () => HasCart);
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        SelectCategoryCommand = new AsyncRelayCommand(() => LoadProductsAsync());
        QuickCashCommand = new RelayCommand<object?>(QuickCash);
        ExactCashCommand = new RelayCommand(() => SetPaid(GrandTotal));
        FocusSearchCommand = new RelayCommand(() => RequestFocus?.Invoke(PosFocus.Search));
        FocusBarcodeCommand = new RelayCommand(() => RequestFocus?.Invoke(PosFocus.Barcode));
        FocusPaidCommand = new RelayCommand(() => RequestFocus?.Invoke(PosFocus.Paid));
        OpenParkedCommand = new RelayCommand(() => _shell.Navigate("parked"));

        Cart.CollectionChanged += (_, _) => Recalculate();
        _ = LoadAsync();
    }

    public enum PosFocus
    {
        Search,
        Barcode,
        Paid,
    }

    public event Action<PosFocus>? RequestFocus;

    public ObservableCollection<Product> Products { get; }
    public ObservableCollection<CartLine> Cart { get; }
    public ObservableCollection<Category> Categories { get; }
    public ObservableCollection<Customer> Customers { get; }
    public ObservableCollection<PaymentMethod> PaymentMethods { get; }

    public ICommand AddToCartCommand { get; }
    public ICommand AddByCodeCommand { get; }
    public ICommand SearchEnterCommand { get; }
    public ICommand IncreaseCommand { get; }
    public ICommand DecreaseCommand { get; }
    public ICommand RemoveCommand { get; }
    public ICommand ClearCartCommand { get; }
    public ICommand ParkCommand { get; }
    public ICommand CheckoutCommand { get; }
    public ICommand RefreshCommand { get; }
    public ICommand SelectCategoryCommand { get; }
    public ICommand QuickCashCommand { get; }
    public ICommand ExactCashCommand { get; }
    public ICommand FocusSearchCommand { get; }
    public ICommand FocusBarcodeCommand { get; }
    public ICommand FocusPaidCommand { get; }
    public ICommand OpenParkedCommand { get; }

    public sealed record QuickCashOption(string Label, decimal Amount);

    public IReadOnlyList<QuickCashOption> QuickCashOptions { get; } =
    [
        new("Uang Pas", -1),
        new("Rp10.000", 10_000),
        new("Rp20.000", 20_000),
        new("Rp50.000", 50_000),
        new("Rp100.000", 100_000),
        new("Rp200.000", 200_000),
        new("Rp500.000", 500_000),
    ];

    public string SearchText
    {
        get => _searchText;
        set
        {
            if (SetProperty(ref _searchText, value))
            {
                _ = DebouncedSearchAsync();
            }
        }
    }

    public string BarcodeText
    {
        get => _barcodeText;
        set => SetProperty(ref _barcodeText, value);
    }

    public Category? SelectedCategory
    {
        get => _selectedCategory;
        set
        {
            if (SetProperty(ref _selectedCategory, value))
            {
                _ = LoadProductsAsync();
            }
        }
    }

    public Customer? SelectedCustomer
    {
        get => _selectedCustomer;
        set => SetProperty(ref _selectedCustomer, value);
    }

    public PaymentMethod? SelectedPaymentMethod
    {
        get => _selectedPaymentMethod;
        set
        {
            if (SetProperty(ref _selectedPaymentMethod, value))
            {
                Recalculate();
            }
        }
    }

    public bool AutoPrint
    {
        get => _autoPrint;
        set => SetProperty(ref _autoPrint, value);
    }

    public string DiscountText
    {
        get => _discountText;
        set
        {
            if (SetProperty(ref _discountText, value))
            {
                Recalculate();
            }
        }
    }

    public int DiscountTypeIndex
    {
        get => _discountTypeIndex;
        set
        {
            if (SetProperty(ref _discountTypeIndex, value))
            {
                Recalculate();
            }
        }
    }

    public string PaidText
    {
        get => _paidText;
        set
        {
            _paidTouched = true;
            if (SetProperty(ref _paidText, value))
            {
                Recalculate();
            }
        }
    }

    public string Notes
    {
        get => _notes;
        set => SetProperty(ref _notes, value);
    }

    public string BarcodeFeedback
    {
        get => _barcodeFeedback;
        private set => SetProperty(ref _barcodeFeedback, value);
    }

    public decimal Subtotal
    {
        get => _subtotal;
        private set => SetProperty(ref _subtotal, value);
    }

    public decimal DiscountValue
    {
        get => _discountValue;
        private set => SetProperty(ref _discountValue, value);
    }

    public decimal TaxAmount
    {
        get => _taxAmount;
        private set => SetProperty(ref _taxAmount, value);
    }

    public decimal GrandTotal
    {
        get => _grandTotal;
        private set => SetProperty(ref _grandTotal, value);
    }

    public decimal Change
    {
        get => _change;
        private set => SetProperty(ref _change, value);
    }

    public bool IsCreditSale =>
        SelectedPaymentMethod is not null &&
        (SelectedPaymentMethod.Name.Contains("CREDIT", StringComparison.OrdinalIgnoreCase) ||
         SelectedPaymentMethod.Name.Contains("UTANG", StringComparison.OrdinalIgnoreCase) ||
         SelectedPaymentMethod.Name.Contains("PIUTANG", StringComparison.OrdinalIgnoreCase) ||
         (SelectedPaymentMethod.Label?.Contains("kredit", StringComparison.OrdinalIgnoreCase) ?? false) ||
         (SelectedPaymentMethod.Label?.Contains("utang", StringComparison.OrdinalIgnoreCase) ?? false) ||
         (SelectedPaymentMethod.Label?.Contains("piutang", StringComparison.OrdinalIgnoreCase) ?? false));

    public int ItemCount => Cart.Sum(line => (int)line.Quantity);
    public bool HasCart => Cart.Count > 0;
    public string CartSummary => HasCart ? $"{ItemCount} item · Rp {GrandTotal:N0}" : "Keranjang kosong";

    public bool CanEditPrice
    {
        get => _canEditPrice;
        private set
        {
            if (SetProperty(ref _canEditPrice, value))
            {
                OnPropertyChanged(nameof(PriceEditHint));
            }
        }
    }

    public bool CanPark
    {
        get => _canPark;
        private set
        {
            if (SetProperty(ref _canPark, value))
            {
                (ParkCommand as AsyncRelayCommand)?.RaiseCanExecuteChanged();
            }
        }
    }

    public int ParkedCount
    {
        get => _parkedCount;
        private set
        {
            if (SetProperty(ref _parkedCount, value))
            {
                OnPropertyChanged(nameof(ParkedLabel));
            }
        }
    }

    public string ParkedLabel => ParkedCount > 0 ? $"Simpanan ({ParkedCount})" : "Simpanan";

    public string PriceEditHint => CanEditPrice
        ? "Harga bisa diedit"
        : "Harga terkunci · atur di Pengaturan → Kasir";

    public async Task RefreshParkedAsync()
    {
        try
        {
            var items = await AppServices.Queries.GetParkedAsync();
            ParkedCount = items.Count;
        }
        catch
        {
            ParkedCount = 0;
        }
    }

    public void LoadLines(IEnumerable<SaleLineInput> lines)
    {
        Cart.Clear();
        foreach (var line in lines)
        {
            if (_productsById.TryGetValue(line.ProductId.ToString(), out var product))
            {
                Cart.Add(new CartLine(product, line.Quantity, line.UnitPrice, line.Discount));
            }
            else
            {
                var placeholder = new Product
                {
                    Id = line.ProductId,
                    Name = line.ProductName,
                    Sku = line.Sku ?? "",
                    Stock = 999_999,
                    SellingPrice = line.UnitPrice,
                };
                Cart.Add(new CartLine(placeholder, line.Quantity, line.UnitPrice, line.Discount));
            }
        }

        AttachCartHandlers();
        Recalculate();
        RequestFocus?.Invoke(PosFocus.Barcode);
    }

    private async Task LoadAsync()
    {
        Categories.Clear();
        Categories.Add(new Category { Id = 0, Name = "Semua Kategori" });
        foreach (var category in await AppServices.Queries.GetCategoriesAsync())
        {
            Categories.Add(category);
        }

        SelectedCategory = Categories.FirstOrDefault();

        Customers.Clear();
        Customers.Add(new Customer { Id = 0, Name = "Pelanggan Umum" });
        foreach (var customer in await AppServices.Queries.GetCustomersAsync())
        {
            Customers.Add(customer);
        }

        SelectedCustomer = Customers.FirstOrDefault();

        PaymentMethods.Clear();
        var methods = await AppServices.Queries.GetPaymentMethodsAsync();
        foreach (var method in methods.Where(item => item.Active))
        {
            if (string.IsNullOrWhiteSpace(method.Label))
            {
                method.Label = method.Name;
            }

            PaymentMethods.Add(method);
        }

        SelectedPaymentMethod = PaymentMethods.FirstOrDefault() ?? new PaymentMethod { Name = "CASH", Label = "Tunai" };

        var settingMap = await AppServices.Queries.GetSettingMapAsync();
        AutoPrint = settingMap.GetValueOrDefault("printer.auto.print", settingMap.GetValueOrDefault("receipt.autoprint.enabled", "true")) == "true";

        var priceMode = settingMap.GetValueOrDefault("pos.edit.price.mode", "admin");
        var role = (AppServices.Settings.Value.UserRole ?? "").ToUpperInvariant();
        var isAdmin = role is "ADMIN" or "OWNER" or "SUPER ADMIN" or "SUPERADMIN";
        CanEditPrice = priceMode switch
        {
            "none" => false,
            "all" => true,
            _ => isAdmin,
        };
        CanPark = settingMap.GetValueOrDefault("pos.park.enabled", "true") == "true";

        await LoadProductsAsync();
        await RefreshParkedAsync();
    }

    private async Task DebouncedSearchAsync()
    {
        _searchCts?.Cancel();
        var cts = new CancellationTokenSource();
        _searchCts = cts;
        try
        {
            await Task.Delay(250, cts.Token);
            await LoadProductsAsync();
        }
        catch (TaskCanceledException)
        {
            // newer keystroke superseded this search
        }
    }

    private async Task LoadProductsAsync()
    {
        var rows = await AppServices.Queries.GetProductsAsync(
            SearchText,
            SelectedCategory?.Id > 0 ? SelectedCategory.Id : null);

        Products.Clear();
        _productsById.Clear();
        foreach (var product in rows)
        {
            Products.Add(product);
            _productsById[product.Id.ToString()] = product;
        }
    }

    private async Task SearchEnterAsync()
    {
        var code = SearchText.Trim();
        if (string.IsNullOrWhiteSpace(code))
        {
            await LoadProductsAsync();
            return;
        }

        var exact = Products.FirstOrDefault(candidate =>
                        string.Equals(candidate.Barcode, code, StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(candidate.Sku, code, StringComparison.OrdinalIgnoreCase))
                    ?? await AppServices.Queries.FindProductByCodeAsync(code);

        if (exact is not null &&
            (string.Equals(exact.Barcode, code, StringComparison.OrdinalIgnoreCase) ||
             string.Equals(exact.Sku, code, StringComparison.OrdinalIgnoreCase)))
        {
            AddProduct(exact);
            SearchText = "";
            BarcodeFeedback = "";
            RequestFocus?.Invoke(PosFocus.Barcode);
            return;
        }

        if (Products.Count == 1)
        {
            AddProduct(Products[0]);
            SearchText = "";
            BarcodeFeedback = "";
            RequestFocus?.Invoke(PosFocus.Barcode);
            return;
        }

        await LoadProductsAsync();
        if (Products.Count == 0)
        {
            BarcodeFeedback = $"Tidak ada produk untuk \"{code}\".";
        }
        else
        {
            BarcodeFeedback = "";
        }
    }

    private async Task AddByCodeAsync()
    {
        var code = (string.IsNullOrWhiteSpace(BarcodeText) ? SearchText : BarcodeText).Trim();
        if (string.IsNullOrWhiteSpace(code))
        {
            return;
        }

        var product = Products.FirstOrDefault(candidate =>
                          string.Equals(candidate.Barcode, code, StringComparison.OrdinalIgnoreCase) ||
                          string.Equals(candidate.Sku, code, StringComparison.OrdinalIgnoreCase))
                      ?? await AppServices.Queries.FindProductByCodeAsync(code);

        if (product is null)
        {
            BarcodeFeedback = $"Produk dengan kode \"{code}\" tidak ditemukan.";
            BarcodeText = "";
            RequestFocus?.Invoke(PosFocus.Barcode);
            return;
        }

        AddProduct(product);
        BarcodeText = "";
        if (SearchText == code)
        {
            SearchText = "";
        }

        BarcodeFeedback = $"{product.Name} ditambahkan.";
        RequestFocus?.Invoke(PosFocus.Barcode);
    }

    private void AddProduct(Product product)
    {
        if (!product.IsActive)
        {
            Ui.Error("Produk tidak aktif.");
            return;
        }

        if (product.Type != "service" && product.Stock <= 0)
        {
            Ui.Error("Stok produk ini habis.");
            return;
        }

        var existing = Cart.FirstOrDefault(line => line.ProductId == product.Id);
        if (existing is not null)
        {
            if (product.Type == "service" || existing.Quantity < product.Stock)
            {
                existing.Quantity += 1;
                Recalculate();
            }
            else
            {
                Ui.Error($"Maksimal stok {product.Stock:0.##}.");
            }

            return;
        }

        var line = new CartLine(product);
        line.PropertyChanged += LineOnPropertyChanged;
        Cart.Add(line);
        Recalculate();
    }

    private void AttachCartHandlers()
    {
        foreach (var line in Cart)
        {
            line.PropertyChanged -= LineOnPropertyChanged;
            line.PropertyChanged += LineOnPropertyChanged;
        }
    }

    private void LineOnPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(CartLine.Subtotal) or nameof(CartLine.Quantity) or nameof(CartLine.UnitPrice))
        {
            if (sender is CartLine line && line.Quantity <= 0 && Cart.Contains(line))
            {
                RemoveLine(line);
                return;
            }

            Recalculate();
        }
    }

    private void ChangeQuantity(CartLine? line, int delta)
    {
        if (line is null)
        {
            return;
        }

        var next = line.Quantity + delta;
        if (next <= 0)
        {
            RemoveLine(line);
            return;
        }

        if (line.Product.Type != "service" && next > line.MaxQuantity)
        {
            Ui.Error($"Stok tersedia {line.MaxQuantity:0.##}.");
            return;
        }

        line.Quantity = next;
        Recalculate();
    }

    private void RemoveLine(CartLine? line)
    {
        if (line is null)
        {
            return;
        }

        line.PropertyChanged -= LineOnPropertyChanged;
        Cart.Remove(line);
        Recalculate();
    }

    private void ClearCart()
    {
        if (Cart.Count == 0)
        {
            return;
        }

        if (!Ui.Confirm("Kosongkan keranjang?"))
        {
            return;
        }

        ClearCartSilently();
    }

    private void ClearCartSilently()
    {
        foreach (var line in Cart)
        {
            line.PropertyChanged -= LineOnPropertyChanged;
        }

        Cart.Clear();
        SelectedCustomer = Customers.FirstOrDefault();
        DiscountText = "0";
        DiscountTypeIndex = 0;
        Notes = "";
        _paidTouched = false;
        _paidText = "0";
        OnPropertyChanged(nameof(PaidText));
        BarcodeFeedback = "";
        Recalculate();
    }

    private void QuickCash(object? parameter)
    {
        switch (parameter)
        {
            case null:
                SetPaid(GrandTotal);
                return;
            case QuickCashOption option:
                SetPaid(option.Amount < 0 ? GrandTotal : option.Amount);
                return;
            case string text when text == "-1":
                SetPaid(GrandTotal);
                return;
            case string text when decimal.TryParse(text, out var amount):
                SetPaid(amount);
                return;
            case decimal amountDecimal:
                SetPaid(amountDecimal < 0 ? GrandTotal : amountDecimal);
                return;
        }
    }

    private void SetPaid(decimal amount)
    {
        _paidTouched = true;
        PaidText = Math.Max(0, amount).ToString("0.##");
        RequestFocus?.Invoke(PosFocus.Paid);
    }

    private void Recalculate()
    {
        if (_recalculating)
        {
            return;
        }

        _recalculating = true;
        try
        {
            Subtotal = Math.Round(Cart.Sum(line => line.Subtotal), 2);

            var discountInput = decimal.TryParse(DiscountText, out var parsed) ? parsed : 0;
            DiscountValue = DiscountTypeIndex == 1
                ? Math.Round(Subtotal * Math.Clamp(discountInput, 0, 100) / 100, 2)
                : Math.Round(Math.Clamp(discountInput, 0, Subtotal), 2);

            var weightedTax = Cart.Sum(line => line.Subtotal * line.TaxRate / 100);
            var taxableShare = Subtotal > 0 ? (Subtotal - DiscountValue) / Subtotal : 0;
            TaxAmount = Math.Round(weightedTax * taxableShare, 2);

            GrandTotal = Math.Max(0, Math.Round(Subtotal - DiscountValue + TaxAmount, 2));

            if (!_paidTouched || PaidText is "0" or "")
            {
                _paidText = GrandTotal.ToString("0.##");
                OnPropertyChanged(nameof(PaidText));
                _paidTouched = false;
            }

            var paid = decimal.TryParse(PaidText, out var paidParsed) ? paidParsed : 0;
            Change = Math.Max(0, Math.Round(paid - GrandTotal, 2));

            OnPropertyChanged(nameof(ItemCount));
            OnPropertyChanged(nameof(HasCart));
            OnPropertyChanged(nameof(CartSummary));
            OnPropertyChanged(nameof(IsCreditSale));
            (CheckoutCommand as AsyncRelayCommand)?.RaiseCanExecuteChanged();
        }
        finally
        {
            _recalculating = false;
        }
    }

    private SaleRequest BuildRequest()
    {
        var method = SelectedPaymentMethod?.Name ?? "CASH";
        var paid = decimal.TryParse(PaidText, out var paidParsed) ? paidParsed : GrandTotal;
        if (!IsCreditSale && paid < GrandTotal)
        {
            paid = GrandTotal;
        }

        if (IsCreditSale && paid <= 0)
        {
            paid = 0;
        }

        return new SaleRequest
        {
            Lines = Cart.Select(line => new SaleLineInput
            {
                ProductId = line.ProductId,
                ProductName = line.Name,
                Sku = line.Sku,
                Quantity = line.Quantity,
                UnitPrice = line.UnitPrice,
                Discount = line.Discount,
            }).ToList(),
            CustomerId = SelectedCustomer?.Id > 0 ? SelectedCustomer.Id : null,
            Discount = DiscountValue,
            TaxAmount = TaxAmount,
            PaidAmount = paid,
            PaymentMethod = method.ToLowerInvariant(),
            Notes = string.IsNullOrWhiteSpace(Notes) ? null : Notes.Trim(),
        };
    }

    private async Task ParkAsync()
    {
        if (Cart.Count == 0)
        {
            Ui.Error("Keranjang masih kosong.");
            return;
        }

        if (!CanPark)
        {
            Ui.Error("Fitur simpan keranjang dinonaktifkan di Pengaturan.");
            return;
        }

        var fields = Views.Dialogs.PromptWindow.Ask(
            System.Windows.Application.Current.MainWindow,
            "Simpan Keranjang",
            "Simpan isi keranjang — bisa dilanjutkan kapan saja dari menu Transaksi Tertunda.",
            new Views.Dialogs.PromptField("label", "Nama simpanan", $"Keranjang {DateTime.Now:dd/MM HH:mm}"));

        if (fields is null)
        {
            return;
        }

        var label = fields.GetValueOrDefault("label", "")?.Trim();
        if (string.IsNullOrWhiteSpace(label))
        {
            label = $"Keranjang {DateTime.Now:yyyyMMddHHmmss}";
        }

        var result = await AppServices.Sales.ParkAsync(BuildRequest(), label);
        if (!result.Success)
        {
            Ui.Error(result.Message);
            return;
        }

        StatusMessage = result.Message;
        ClearCartSilently();
        await AppServices.Sync.RefreshCountersAsync();
        await RefreshParkedAsync();
        RequestFocus?.Invoke(PosFocus.Barcode);
    }

    private async Task CheckoutAsync()
    {
        if (Cart.Count == 0)
        {
            Ui.Error("Keranjang masih kosong.");
            return;
        }

        var paid = decimal.TryParse(PaidText, out var parsedPaid) ? parsedPaid : 0;
        if (!IsCreditSale && paid < GrandTotal)
        {
            Ui.Error($"Jumlah bayar kurang dari total ({GrandTotal:N0}).");
            RequestFocus?.Invoke(PosFocus.Paid);
            return;
        }

        IsBusy = true;
        try
        {
            var result = await AppServices.Sales.CheckoutAsync(BuildRequest());
            if (!result.Success || result.Result is null)
            {
                Ui.Error(result.Message);
                return;
            }

            var sale = result.Result;
            StatusMessage = $"Transaksi {sale.InvoiceNumber} tersimpan.";
            ClearCartSilently();
            await LoadProductsAsync();
            await AppServices.Sync.RefreshCountersAsync();
            await RefreshParkedAsync();

            var receipt = await new ReceiptService(AppServices.Settings).BuildTextAsync(sale);
            var window = new ReceiptWindow(sale, receipt)
            {
                Owner = System.Windows.Application.Current.MainWindow,
            };
            window.ShowDialog();

            if (AutoPrint)
            {
                try
                {
                    await new ReceiptService(AppServices.Settings).PrintAsync(sale, showDialog: false);
                }
                catch
                {
                    // printer unavailable — receipt preview already shown
                }
            }

            RequestFocus?.Invoke(PosFocus.Barcode);
        }
        finally
        {
            IsBusy = false;
        }
    }
}
