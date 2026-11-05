using Posqupro.Desktop.ViewModels;

namespace Posqupro.Desktop.ViewModels;

/// <summary>Creates the view model for a navigation key (cached by the shell).</summary>
public static class PageFactory
{
    public static (string Title, object ViewModel) Create(string key, ShellViewModel shell) => key switch
    {
        "dashboard" => ("Dashboard", new DashboardViewModel(shell)),
        "pos" => ("POS / Kasir", new PosViewModel(shell)),
        "parked" => ("Transaksi Tertunda", new ParkedViewModel(shell)),
        "transactions" => ("Riwayat Transaksi", new TransactionsViewModel()),
        "customers" => ("Pelanggan", new CrudViewModel(CrudCatalog.Customers(), shell)),
        "register" => ("Kas & Shift", new RegisterViewModel()),
        "products" => ("Produk", new CrudViewModel(CrudCatalog.Products(), shell)),
        "categories" => ("Kategori", new CrudViewModel(CrudCatalog.Categories(), shell)),
        "units" => ("Satuan", new CrudViewModel(CrudCatalog.Units(), shell)),
        "inventory" => ("Inventory", new InventoryViewModel()),
        "warehouses" => ("Gudang", new CrudViewModel(CrudCatalog.Warehouses(), shell)),
        "purchase-orders" => ("Purchase Order", new PurchaseOrdersViewModel()),
        "stock-counts" => ("Stock Opname", new StockCountsViewModel()),
        "suppliers" => ("Supplier", new CrudViewModel(CrudCatalog.Suppliers(), shell)),
        "reports" => ("Laporan & Analitik", new ReportsViewModel()),
        "expenses" => ("Pengeluaran", new CrudViewModel(CrudCatalog.Expenses(), shell)),
        "taxes" => ("Pajak", new CrudViewModel(CrudCatalog.Taxes(), shell)),
        "branches" => ("Cabang", new CrudViewModel(CrudCatalog.Branches(), shell)),
        "users" => ("Pengguna & RBAC", new CrudViewModel(CrudCatalog.Users(), shell)),
        "activity-logs" => ("Log Aktivitas", new CrudViewModel(CrudCatalog.ActivityLogs(), shell)),
        "settings" => ("Pengaturan", new SettingsViewModel(shell)),
        "sync" => ("Sinkronisasi", new SyncViewModel()),
        _ => ("POSQUPRO", new DashboardViewModel(shell)),
    };
}
