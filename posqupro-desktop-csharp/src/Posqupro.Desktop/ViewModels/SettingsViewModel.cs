using System.Collections.ObjectModel;
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
    private string _printerType = "Windows";
    private string _printerName = "auto";
    private string _paperWidth = "80";
    private string _fontSize = "9";
    private string _fontFamily = "Consolas";
    private string _marginTop = "0";
    private string _marginBottom = "0";
    private string _marginLeft = "0";
    private string _spacingLine = "80";
    private string _alignment = "left";
    private string _drawerPrinter = "";
    private bool _autoPrint;

    public SettingsViewModel(ShellViewModel shell)
    {
        _shell = shell;
        PaymentMethods = [];
        SaveStoreCommand = new AsyncRelayCommand(SaveStoreAsync);
        SavePrinterCommand = new AsyncRelayCommand(SavePrinterAsync);
        OpenTaxesCommand = new RelayCommand(() => shell.Navigate("taxes"));
        RefreshCommand = new AsyncRelayCommand(LoadAsync);
        _ = LoadAsync();
    }

    public ObservableCollection<PaymentMethodRow> PaymentMethods { get; }
    public ICommand SaveStoreCommand { get; }
    public ICommand SavePrinterCommand { get; }
    public ICommand OpenTaxesCommand { get; }
    public ICommand RefreshCommand { get; }

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

    private async Task LoadAsync()
    {
        var map = await AppServices.Queries.GetSettingMapAsync();
        StoreName = map.GetValueOrDefault("store.name", "TOKO POSQU PRO");
        StorePhone = map.GetValueOrDefault("store.phone", "");
        StoreAddress = map.GetValueOrDefault("store.address", "");
        ReceiptHeader = map.GetValueOrDefault("receipt.header", "");
        ReceiptFooter = map.GetValueOrDefault("receipt.footer", "");
        PrinterType = map.GetValueOrDefault("printer.connection.type", "Windows");
        PrinterName = map.GetValueOrDefault("printer.name", "auto");
        PaperWidth = map.GetValueOrDefault("printer.paper.width", "80");
        FontSize = map.GetValueOrDefault("printer.font.size", "9");
        FontFamily = map.GetValueOrDefault("printer.font.family", "Consolas");
        MarginTop = map.GetValueOrDefault("printer.margin.top", "0");
        MarginBottom = map.GetValueOrDefault("printer.margin.bottom", "0");
        MarginLeft = map.GetValueOrDefault("printer.margin.left", "0");
        SpacingLine = map.GetValueOrDefault("printer.spacing.line", "80");
        Alignment = map.GetValueOrDefault("printer.alignment", "left");
        DrawerPrinter = map.GetValueOrDefault("drawer.printer", "");
        AutoPrint = map.GetValueOrDefault("printer.auto.print", "false") == "true";

        PaymentMethods.Clear();
        foreach (var method in await AppServices.Queries.GetPaymentMethodsAsync())
        {
            PaymentMethods.Add(new PaymentMethodRow(method, OnPaymentMethodToggled));
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
        await SaveSettingsAsync(new Dictionary<string, string>
        {
            ["printer.connection.type"] = PrinterType,
            ["printer.name"] = PrinterName,
            ["printer.paper.width"] = PaperWidth,
            ["printer.font.size"] = FontSize,
            ["printer.font.family"] = FontFamily,
            ["printer.margin.top"] = MarginTop,
            ["printer.margin.bottom"] = MarginBottom,
            ["printer.margin.left"] = MarginLeft,
            ["printer.spacing.line"] = SpacingLine,
            ["printer.alignment"] = Alignment,
            ["printer.auto.print"] = AutoPrint ? "true" : "false",
            ["drawer.printer"] = DrawerPrinter,
        }, "printer");
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
