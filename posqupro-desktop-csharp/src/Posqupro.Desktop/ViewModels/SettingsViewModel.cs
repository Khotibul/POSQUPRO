using System.Collections.ObjectModel;
using System.Printing;
using System.Windows.Input;
using Posqupro.Desktop.Models;
using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

public sealed class PaymentMethodRow : ViewModelBase
{
    private readonly Action<PaymentMethodRow> _onToggle;
    private bool _isActive;

    public PaymentMethodRow(PaymentMethod method, Action<PaymentMethodRow> onToggle)
    {
        Id = method.Id;
        Name = method.Name;
        Label = method.Label ?? method.Name;
        _isActive = method.Active;
        _onToggle = onToggle;
    }

    public long Id { get; }
    public string Name { get; }
    public string Label { get; }

    public bool IsActive
    {
        get => _isActive;
        set
        {
            if (SetProperty(ref _isActive, value))
            {
                _onToggle(this);
            }
        }
    }
}

public sealed class SettingsViewModel : ViewModelBase
{
    private readonly ShellViewModel _shell;
    private string _storeName = "";
    private string _storePhone = "";
    private string _storeAddress = "";
    private string _receiptHeader = "";
    private string _receiptFooter = "";
    private string _printerType = "OS Default";
    private string _printerName = "";
    private string _bluetoothMac = "";
    private string _paperWidth = "48";
    private string _fontSize = "8";
    private string _fontFamily = "";
    private string _marginTop = "0";
    private string _marginBottom = "0";
    private string _marginLeft = "0";
    private string _spacingLine = "100";
    private string _alignment = "left";
    private string _drawerPrinter = "";
    private bool _autoPrint = true;
    private bool _drawerEnabled;
    private string _receiptLogoPath = "";
    private string _selectedPrinter = "";
    private int _posEditPriceIndex = 1;
    private bool _posParkEnabled = true;

    public SettingsViewModel(ShellViewModel shell)
    {
        _shell = shell;
        PaymentMethods = [];
        PrinterOptions = [];
        SaveStoreCommand = new AsyncRelayCommand(SaveStoreAsync);
        SavePrinterCommand = new AsyncRelayCommand(SavePrinterAsync);
        SavePosCommand = new AsyncRelayCommand(SavePosAsync);
        DetectPrintersCommand = new AsyncRelayCommand(DetectPrintersAsync);
        TestPrintCommand = new AsyncRelayCommand(TestPrintAsync);
        ClearLogoCommand = new RelayCommand(() => ReceiptLogoPath = "");
        OpenTaxesCommand = new RelayCommand(() => shell.Navigate("taxes"));
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        _ = LoadAsync();
    }

    public ObservableCollection<PaymentMethodRow> PaymentMethods { get; }
    public ObservableCollection<string> PrinterOptions { get; }
    public ICommand SaveStoreCommand { get; }
    public ICommand SavePrinterCommand { get; }
    public ICommand SavePosCommand { get; }
    public ICommand DetectPrintersCommand { get; }
    public ICommand TestPrintCommand { get; }
    public ICommand ClearLogoCommand { get; }
    public ICommand OpenTaxesCommand { get; }
    public ICommand RefreshCommand { get; }

    public IReadOnlyList<string> ConnectionTypes { get; } = ["OS Default", "USB", "Bluetooth"];
    public IReadOnlyList<string> FontSizeOptions { get; } =
        ["Auto", "7", "8", "10", "12", "14", "16", "18", "20", "22", "24"];
    public IReadOnlyList<string> FontFamilyOptions { get; } =
        ["", "Lucida Console", "Courier New", "Consolas", "Arial", "Tahoma", "Segoe UI", "Verdana", "Times New Roman", "Calibri"];
    public IReadOnlyList<string> AlignmentOptions { get; } = ["left", "center", "right"];
    public IReadOnlyList<string> PaperWidthOptions { get; } = ["32", "42", "48", "58", "72", "80"];
    public IReadOnlyList<string> PosEditPriceLabels { get; } =
        ["Tidak diizinkan", "Hanya Admin", "Semua role"];

    public int PosEditPriceIndex
    {
        get => _posEditPriceIndex;
        set => SetProperty(ref _posEditPriceIndex, value);
    }

    public bool PosParkEnabled
    {
        get => _posParkEnabled;
        set => SetProperty(ref _posParkEnabled, value);
    }

    public string TenantName => AppServices.Settings.Value.TenantName ?? "POSQUPRO";
    public string PlanName => AppServices.Settings.Value.PlanName ?? "—";
    public string LicenseCode => AppServices.Settings.Value.LicenseCode ?? "—";
    public string TenantStatus => AppServices.Settings.Value.TenantStatus ?? "—";
    public string AccountName => AppServices.Settings.Value.UserName ?? "—";
    public string AccountEmail => AppServices.Settings.Value.UserEmail ?? "—";
    public string RoleName => _shell.RoleLabel;

    public string StoreName { get => _storeName; set => SetProperty(ref _storeName, value); }
    public string StorePhone { get => _storePhone; set => SetProperty(ref _storePhone, value); }
    public string StoreAddress { get => _storeAddress; set => SetProperty(ref _storeAddress, value); }
    public string ReceiptHeader { get => _receiptHeader; set => SetProperty(ref _receiptHeader, value); }
    public string ReceiptFooter { get => _receiptFooter; set => SetProperty(ref _receiptFooter, value); }

    public string PrinterType { get => _printerType; set => SetProperty(ref _printerType, value); }
    public string PrinterName { get => _printerName; set => SetProperty(ref _printerName, value); }
    public string SelectedPrinter
    {
        get => _selectedPrinter;
        set
        {
            if (SetProperty(ref _selectedPrinter, value) && !string.IsNullOrWhiteSpace(value) && value != "Deteksi otomatis...")
            {
                PrinterName = value;
            }
        }
    }

    public string BluetoothMac { get => _bluetoothMac; set => SetProperty(ref _bluetoothMac, value); }
    public string PaperWidth { get => _paperWidth; set => SetProperty(ref _paperWidth, value); }
    public string FontSize { get => _fontSize; set => SetProperty(ref _fontSize, value); }
    public string FontFamily { get => _fontFamily; set => SetProperty(ref _fontFamily, value); }
    public string MarginTop { get => _marginTop; set => SetProperty(ref _marginTop, value); }
    public string MarginBottom { get => _marginBottom; set => SetProperty(ref _marginBottom, value); }
    public string MarginLeft { get => _marginLeft; set => SetProperty(ref _marginLeft, value); }
    public string SpacingLine { get => _spacingLine; set => SetProperty(ref _spacingLine, value); }
    public string Alignment { get => _alignment; set => SetProperty(ref _alignment, value); }
    public string DrawerPrinter { get => _drawerPrinter; set => SetProperty(ref _drawerPrinter, value); }
    public bool AutoPrint { get => _autoPrint; set => SetProperty(ref _autoPrint, value); }
    public bool DrawerEnabled { get => _drawerEnabled; set => SetProperty(ref _drawerEnabled, value); }
    public string ReceiptLogoPath { get => _receiptLogoPath; set => SetProperty(ref _receiptLogoPath, value); }

    public bool IsBluetooth => string.Equals(PrinterType, "Bluetooth", StringComparison.OrdinalIgnoreCase);

    public string FontSizeLabel => FontSize is "Auto" or "0" or "" ? "Auto" : $"{FontSize}pt";

    private async Task LoadAsync()
    {
        var map = await AppServices.Queries.GetSettingMapAsync();
        StoreName = map.GetValueOrDefault("store.name", "TOKO POSQU PRO");
        StorePhone = map.GetValueOrDefault("store.phone", "");
        StoreAddress = map.GetValueOrDefault("store.address", "");
        ReceiptHeader = map.GetValueOrDefault("receipt.header", "Terima Kasih Telah Berbelanja");
        ReceiptFooter = map.GetValueOrDefault("receipt.footer", "Barang yang sudah dibeli tidak dapat ditukar/dikembalikan");
        PrinterType = map.GetValueOrDefault("printer.connection.type", "OS Default");
        PrinterName = map.GetValueOrDefault("printer.name", "");
        BluetoothMac = map.GetValueOrDefault("printer.bluetooth.mac", "");
        PaperWidth = map.GetValueOrDefault("printer.paper.width", "48");
        FontSize = map.GetValueOrDefault("printer.font.size", "8");
        FontFamily = map.GetValueOrDefault("printer.font.family", "");
        MarginTop = map.GetValueOrDefault("printer.margin.top", "0");
        MarginBottom = map.GetValueOrDefault("printer.margin.bottom", "0");
        MarginLeft = map.GetValueOrDefault("printer.margin.left", "0");
        SpacingLine = map.GetValueOrDefault("printer.spacing.line", "100");
        Alignment = map.GetValueOrDefault("printer.alignment", "left");
        DrawerPrinter = map.GetValueOrDefault("drawer.printer", "");
        ReceiptLogoPath = map.GetValueOrDefault("receipt.logo.path", "");
        AutoPrint = map.GetValueOrDefault("printer.auto.print", map.GetValueOrDefault("receipt.autoprint.enabled", "true")) == "true";
        DrawerEnabled = map.GetValueOrDefault("drawer.enabled", "false") == "true";

        var priceMode = map.GetValueOrDefault("pos.edit.price.mode", "admin");
        PosEditPriceIndex = priceMode switch
        {
            "none" => 0,
            "all" => 2,
            _ => 1,
        };
        PosParkEnabled = map.GetValueOrDefault("pos.park.enabled", "true") == "true";

        SelectedPrinter = string.IsNullOrWhiteSpace(PrinterName) ? "Deteksi otomatis..." : PrinterName;
        OnPropertyChanged(nameof(IsBluetooth));
        OnPropertyChanged(nameof(FontSizeLabel));

        await DetectPrintersAsync(silent: true);

        PaymentMethods.Clear();
        foreach (var method in await AppServices.Queries.GetPaymentMethodsAsync())
        {
            PaymentMethods.Add(new PaymentMethodRow(method, OnPaymentMethodToggled));
        }
    }

    private async Task DetectPrintersAsync() => await DetectPrintersAsync(silent: false);

    private Task DetectPrintersAsync(bool silent)
    {
        try
        {
            var current = PrinterName;
            PrinterOptions.Clear();
            PrinterOptions.Add("Deteksi otomatis...");

            using var server = new LocalPrintServer();
            foreach (var queue in server.GetPrintQueues())
            {
                PrinterOptions.Add(queue.Name);
            }

            SelectedPrinter = !string.IsNullOrWhiteSpace(current) && PrinterOptions.Contains(current)
                ? current
                : "Deteksi otomatis...";

            if (!silent)
            {
                StatusMessage = $"{Math.Max(0, PrinterOptions.Count - 1)} printer ditemukan.";
            }
        }
        catch (Exception exception)
        {
            if (!silent)
            {
                StatusMessage = exception.Message;
            }
        }

        return Task.CompletedTask;
    }

    private async Task TestPrintAsync()
    {
        await SavePrinterAsync();
        var sale = new SaleResult
        {
            TransactionId = 0,
            InvoiceNumber = "TEST-0001",
            Subtotal = 10000,
            Discount = 0,
            Tax = 0,
            Total = 10000,
            Paid = 10000,
            Change = 0,
            PaymentMethod = "CASH",
            CreatedAt = DateTime.Now,
            Lines =
            [
                new SaleLineInput { ProductId = 1, ProductName = "Produk Contoh", Quantity = 1, UnitPrice = 10000 },
            ],
        };

        try
        {
            await new ReceiptService(AppServices.Settings).PrintAsync(sale, showDialog: true);
            StatusMessage = "Tes cetak dikirim.";
        }
        catch (Exception exception)
        {
            StatusMessage = exception.Message;
            Ui.Error(exception.Message);
        }
    }

    private async Task SaveStoreAsync()
    {
        await SaveSettingsAsync(new Dictionary<string, string>
        {
            ["store.name"] = StoreName,
            ["store.phone"] = StorePhone,
            ["store.address"] = StoreAddress,
            ["receipt.header"] = ReceiptHeader,
            ["receipt.footer"] = ReceiptFooter,
        }, "store");
    }

    private async Task SavePrinterAsync()
    {
        var fontSize = FontSize is "Auto" or "" ? "0" : FontSize;
        await SaveSettingsAsync(new Dictionary<string, string>
        {
            ["printer.connection.type"] = PrinterType,
            ["printer.name"] = SelectedPrinter == "Deteksi otomatis..." ? "" : (string.IsNullOrWhiteSpace(PrinterName) ? SelectedPrinter : PrinterName),
            ["printer.bluetooth.mac"] = BluetoothMac,
            ["printer.paper.width"] = PaperWidth,
            ["printer.font.size"] = fontSize,
            ["printer.font.family"] = FontFamily,
            ["printer.margin.top"] = MarginTop,
            ["printer.margin.bottom"] = MarginBottom,
            ["printer.margin.left"] = MarginLeft,
            ["printer.spacing.line"] = SpacingLine,
            ["printer.alignment"] = Alignment,
            ["printer.auto.print"] = AutoPrint ? "true" : "false",
            ["receipt.autoprint.enabled"] = AutoPrint ? "true" : "false",
            ["drawer.enabled"] = DrawerEnabled ? "true" : "false",
            ["drawer.printer"] = DrawerPrinter,
            ["receipt.logo.path"] = ReceiptLogoPath,
        }, "printer");

        PrinterName = SelectedPrinter == "Deteksi otomatis..." ? "" : PrinterName;
        OnPropertyChanged(nameof(IsBluetooth));
        OnPropertyChanged(nameof(FontSizeLabel));
    }

    private async Task SavePosAsync()
    {
        var mode = PosEditPriceIndex switch
        {
            0 => "none",
            2 => "all",
            _ => "admin",
        };

        await SaveSettingsAsync(new Dictionary<string, string>
        {
            ["pos.edit.price.mode"] = mode,
            ["pos.park.enabled"] = PosParkEnabled ? "true" : "false",
        }, "pos");
    }

    private async Task SaveSettingsAsync(Dictionary<string, string> values, string group)
    {
        foreach (var (key, value) in values)
        {
            await AppServices.Db.SetSettingAsync(new SettingItem
            {
                Key = key,
                Value = value,
                Group = group,
                Type = "string",
            });

            await AppServices.Db.EnqueueAsync("setting", "update", 0, new
            {
                key,
                value,
                group,
                type = "string",
            });
        }

        StatusMessage = "Pengaturan disimpan.";
        await AppServices.Sync.RefreshCountersAsync();
    }

    private void OnPaymentMethodToggled(PaymentMethodRow row)
    {
        _ = AppServices.Db.ExecuteAsync(
            "UPDATE payment_methods SET active=$active WHERE id=$id",
            new { active = row.IsActive ? 1 : 0, id = row.Id });
        StatusMessage = $"Metode {row.Label} {(row.IsActive ? "diaktifkan" : "dinonaktifkan")}.";
    }
}
