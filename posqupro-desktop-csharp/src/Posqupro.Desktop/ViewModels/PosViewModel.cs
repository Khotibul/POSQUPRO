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

    public CartLine(Product product, decimal quantity = 1, decimal unitPrice = 0, decimal discount = 0)
    {
        Product = product;
        _quantity = quantity;
        UnitPrice = unitPrice > 0 ? unitPrice : product.EffectivePrice;
        _discount = discount;
    }

    public Product Product { get; }
    public long ProductId => Product.Id;
    public string Name => Product.Name;
    public string? Sku => Product.Sku;
    public decimal UnitPrice { get; }
    public decimal MaxQuantity => Product.Stock;
    public string StockLabel => Product.Type == "service" ? "Jasa" : $"Stok {Product.Stock:0.##}";
    public decimal TaxRate => Product.TaxRate;

    public decimal Quantity
    {
        get => _quantity;
        set
        {
            if (SetProperty(ref _quantity, value))
            {
                OnPropertyChanged(nameof(Subtotal));
            }
        }
    }

    public decimal Discount
    {
        get => _discount;
        set
        {
            if (SetProperty(ref _discount, value))
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
    private bool _paidTouched;
    private bool _recalculating;

    private string _searchText = "";
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
        IncreaseCommand = new RelayCommand<CartLine>(line => ChangeQuantity(line, 1));
        DecreaseCommand = new RelayCommand<CartLine>(line => ChangeQuantity(line, -1));
        RemoveCommand = new RelayCommand<CartLine>(RemoveLine);
        ClearCartCommand = new RelayCommand(ClearCart);
        ParkCommand = new AsyncRelayCommand(ParkAsync);
        CheckoutCommand = new AsyncRelayCommand(CheckoutAsync);
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        SelectCategoryCommand = new AsyncRelayCommand(() => LoadProductsAsync());

        Cart.CollectionChanged += (_, _) => Recalculate();
        _ = LoadAsync();
    }

    public ObservableCollection<Product> Products { get; }
    public ObservableCollection<CartLine> Cart { get; }
    public ObservableCollection<Category> Categories { get; }
    public ObservableCollection<Customer> Customers { get; }
    public ObservableCollection<PaymentMethod> PaymentMethods { get; }

    public ICommand AddToCartCommand { get; }
    public ICommand AddByCodeCommand { get; }
    public ICommand IncreaseCommand { get; }
    public ICommand DecreaseCommand { get; }
    public ICommand RemoveCommand { get; }
    public ICommand ClearCartCommand { get; }
    public ICommand ParkCommand { get; }
    public ICommand CheckoutCommand { get; }
    public ICommand RefreshCommand { get; }
    public ICommand SelectCategoryCommand { get; }

    public string SearchText
    {
        get => _searchText;
        set
        {
            if (SetProperty(ref _searchText, value))
            {
                _ = LoadProductsAsync();
            }
        }
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
        set => SetProperty(ref _selectedPaymentMethod, value);
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

    public int ItemCount => Cart.Sum(line => (int)line.Quantity);
    public bool HasCart => Cart.Count > 0;
    public string CartSummary => $"{ItemCount} item";

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
            PaymentMethods.Add(method);
        }

        SelectedPaymentMethod = PaymentMethods.FirstOrDefault() ?? new PaymentMethod { Name = "CASH", Label = "Tunai" };

        var settingMap = await AppServices.Queries.GetSettingMapAsync();
        AutoPrint = settingMap.GetValueOrDefault("printer.auto.print", settingMap.GetValueOrDefault("receipt.autoprint.enabled", "true")) == "true";

        await LoadProductsAsync();
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

    private async Task AddByCodeAsync()
    {
        var code = SearchText.Trim();
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
            return;
        }

        AddProduct(product);
        SearchText = "";
        BarcodeFeedback = "";
    }

    private void AddProduct(Product product)
    {
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
        if (e.PropertyName == nameof(CartLine.Subtotal))
        {
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
        if (Cart.Count == 0 || !Ui.Confirm("Kosongkan keranjang?"))
        {
            return;
        }

        foreach (var line in Cart)
        {
            line.PropertyChanged -= LineOnPropertyChanged;
        }

        Cart.Clear();
        SelectedCustomer = Customers.FirstOrDefault();
        DiscountText = "0";
        Notes = "";
        _paidTouched = false;
        Recalculate();
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
            Subtotal = Cart.Sum(line => line.Subtotal);

            var discountInput = decimal.TryParse(DiscountText, out var parsed) ? parsed : 0;
            DiscountValue = DiscountTypeIndex == 1
                ? Math.Round(Subtotal * Math.Clamp(discountInput, 0, 100) / 100, 2)
                : Math.Clamp(discountInput, 0, Subtotal);

            var weightedTax = Cart.Sum(line => line.Subtotal * line.TaxRate / 100);
            var taxableShare = Subtotal > 0 ? (Subtotal - DiscountValue) / Subtotal : 0;
            TaxAmount = Math.Round(weightedTax * taxableShare, 2);

            GrandTotal = Math.Max(0, Subtotal - DiscountValue + TaxAmount);

            if (!_paidTouched || PaidText is "0" or "")
            {
                _paidText = GrandTotal.ToString("0.##");
                OnPropertyChanged(nameof(PaidText));
                _paidTouched = false;
            }

            var paid = decimal.TryParse(PaidText, out var paidParsed) ? paidParsed : 0;
            Change = Math.Max(0, paid - GrandTotal);

            OnPropertyChanged(nameof(ItemCount));
            OnPropertyChanged(nameof(HasCart));
            OnPropertyChanged(nameof(CartSummary));
        }
        finally
        {
            _recalculating = false;
        }
    }

    private SaleRequest BuildRequest() => new()
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
        PaidAmount = decimal.TryParse(PaidText, out var paid) ? paid : GrandTotal,
        PaymentMethod = (SelectedPaymentMethod?.Name ?? "CASH").ToLowerInvariant(),
        Notes = string.IsNullOrWhiteSpace(Notes) ? null : Notes.Trim(),
    };

    private async Task ParkAsync()
    {
        var result = await AppServices.Sales.ParkAsync(BuildRequest());
        if (!result.Success)
        {
            Ui.Error(result.Message);
            return;
        }

        StatusMessage = result.Message;
        ClearCartSilently();
        await AppServices.Sync.RefreshCountersAsync();
    }

    private async Task CheckoutAsync()
    {
        if (Cart.Count == 0)
        {
            Ui.Error("Keranjang masih kosong.");
            return;
        }

        var paid = decimal.TryParse(PaidText, out var parsedPaid) ? parsedPaid : 0;
        if (paid < GrandTotal)
        {
            Ui.Error("Jumlah bayar kurang dari total.");
            return;
        }

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

        var receipt = await new ReceiptService(AppServices.Settings).BuildTextAsync(sale);
        var window = new ReceiptWindow(sale, receipt) { Owner = System.Windows.Application.Current.MainWindow };
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

        _shell.Navigate("pos");
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
        Notes = "";
        _paidTouched = false;
        Recalculate();
    }
}
