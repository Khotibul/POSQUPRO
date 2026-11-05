using Posqupro.Desktop.Data;
using Posqupro.Desktop.Models;

namespace Posqupro.Desktop.Services;

public sealed class DailyPoint
{
    public string Date { get; set; } = "";
    public decimal Total { get; set; }
    public int Count { get; set; }
}

public sealed class TopProduct
{
    public string Name { get; set; } = "";
    public decimal Quantity { get; set; }
    public decimal Revenue { get; set; }
}

public sealed class PaymentBreakdown
{
    public string Method { get; set; } = "";
    public decimal Total { get; set; }
}

public sealed class DashboardData
{
    public decimal TodayRevenue { get; set; }
    public int TodayTransactions { get; set; }
    public decimal MonthRevenue { get; set; }
    public int LowStockCount { get; set; }
    public List<Transaction> RecentTransactions { get; set; } = [];
    public List<Product> LowStockProducts { get; set; } = [];
}

public sealed class SalesReportData
{
    public decimal Revenue { get; set; }
    public int Transactions { get; set; }
    public decimal AverageBasket { get; set; }
    public decimal ItemsSold { get; set; }
    public decimal Expenses { get; set; }
    public List<DailyPoint> Daily { get; set; } = [];
    public List<TopProduct> TopProducts { get; set; } = [];
    public List<PaymentBreakdown> Payments { get; set; } = [];
}

public sealed class InventoryReportData
{
    public int TotalProducts { get; set; }
    public int LowStockCount { get; set; }
    public decimal StockCostValue { get; set; }
    public decimal StockSellValue { get; set; }
    public List<Product> LowStock { get; set; } = [];
}

/// <summary>Read models used by the desktop screens. Everything is served from the local database.</summary>
public sealed class LocalQueries(LocalDatabase database)
{
    public Task<List<Product>> GetProductsAsync(string? search = null, long? categoryId = null, bool includeInactive = false)
    {
        var where = new List<string>();
        if (!includeInactive)
        {
            where.Add("p.is_active=1");
        }

        if (categoryId is not null)
        {
            where.Add("p.category_id=$categoryId");
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            where.Add("(p.name LIKE $search OR p.sku LIKE $search OR p.barcode LIKE $search)");
        }

        var sql = $"""
            SELECT p.*, COALESCE(c.name, p.category_text, '') AS category_name, COALESCE(uq.symbol, '') AS unit_name,
                   COALESCE(tx.rate, 0) AS tax_rate
            FROM products p
            LEFT JOIN categories c ON c.id=p.category_id
            LEFT JOIN unit_quantities uq ON uq.id=p.unit_quantity_id
            LEFT JOIN taxes tx ON tx.id=p.tax_id
            {(where.Count > 0 ? "WHERE " + string.Join(" AND ", where) : "")}
            ORDER BY p.name
            """;

        return database.QueryAsync<Product>(sql, new
        {
            search = $"%{search}%",
            categoryId,
        });
    }

    public Task<Product?> FindProductByCodeAsync(string code) =>
        database.QuerySingleAsync<Product>(
            """
            SELECT p.*, COALESCE(c.name, p.category_text, '') AS category_name
            FROM products p LEFT JOIN categories c ON c.id=p.category_id
            WHERE p.barcode=$code OR p.sku=$code OR p.name=$code
            ORDER BY CASE WHEN p.barcode=$code THEN 0 WHEN p.sku=$code THEN 1 ELSE 2 END
            LIMIT 1
            """,
            new { code });

    public Task<Product?> GetProductAsync(long id) =>
        database.QuerySingleAsync<Product>(
            """
            SELECT p.*, COALESCE(c.name, p.category_text, '') AS category_name
            FROM products p LEFT JOIN categories c ON c.id=p.category_id
            WHERE p.id=$id
            """,
            new { id });

    public Task<List<Category>> GetCategoriesAsync() =>
        database.QueryAsync<Category>("SELECT * FROM categories ORDER BY name");

    public Task<Dictionary<string, string>> GetSettingMapAsync() => database.GetSettingMapAsync();

    public Task<List<UnitQuantity>> GetUnitsAsync() =>
        database.QueryAsync<UnitQuantity>("SELECT * FROM unit_quantities ORDER BY name");

    public Task<List<Tax>> GetTaxesAsync() =>
        database.QueryAsync<Tax>("SELECT * FROM taxes ORDER BY name");

    public Task<List<Supplier>> GetSuppliersAsync() =>
        database.QueryAsync<Supplier>("SELECT * FROM suppliers ORDER BY name");

    public Task<List<Customer>> GetCustomersAsync() =>
        database.QueryAsync<Customer>("SELECT * FROM customers ORDER BY name");

    public Task<List<Branch>> GetBranchesAsync() =>
        database.QueryAsync<Branch>("SELECT * FROM branches ORDER BY name");

    public Task<List<Warehouse>> GetWarehousesAsync() =>
        database.QueryAsync<Warehouse>(
            """
            SELECT w.*, b.name AS branch_name FROM warehouses w
            LEFT JOIN branches b ON b.id=w.branch_id ORDER BY w.name
            """);

    public Task<List<UserInfo>> GetUsersAsync() =>
        database.QueryAsync<UserInfo>("SELECT * FROM users ORDER BY name");

    public Task<List<Register>> GetRegistersAsync() =>
        database.QueryAsync<Register>("SELECT * FROM registers ORDER BY name");

    public async Task<List<RegisterSession>> GetRegisterSessionsAsync(int limit = 100) =>
        await database.QueryAsync<RegisterSession>(
            """
            SELECT s.*, r.name AS register_name FROM register_sessions s
            LEFT JOIN registers r ON r.id=s.register_id
            ORDER BY s.opened_at DESC LIMIT $limit
            """,
            new { limit });

    public Task<RegisterSession?> GetOpenSessionAsync(long registerId) =>
        database.QuerySingleAsync<RegisterSession>(
            "SELECT * FROM register_sessions WHERE register_id=$registerId AND status='open' ORDER BY id DESC LIMIT 1",
            new { registerId });

    public Task<List<Transaction>> GetTransactionsAsync(
        string? search = null,
        string? type = null,
        DateTime? from = null,
        DateTime? to = null,
        int limit = 500)
    {
        var where = new List<string>();
        if (!string.IsNullOrWhiteSpace(search))
        {
            where.Add("t.invoice_number LIKE $search");
        }

        if (!string.IsNullOrWhiteSpace(type))
        {
            where.Add("t.type=$type");
        }

        if (from is not null)
        {
            where.Add("date(t.created_at) >= date($from)");
        }

        if (to is not null)
        {
            where.Add("date(t.created_at) <= date($to)");
        }

        var sql = $"""
            SELECT t.*, COALESCE(c.name,'Umum') AS customer_name, COALESCE(u.name,'') AS cashier_name,
                   (SELECT COUNT(*) FROM transaction_items i WHERE i.transaction_id=t.id) AS item_count
            FROM transactions t
            LEFT JOIN customers c ON c.id=t.customer_id
            LEFT JOIN users u ON u.id=t.user_id
            {(where.Count > 0 ? "WHERE " + string.Join(" AND ", where) : "")}
            ORDER BY t.created_at DESC, t.id DESC
            LIMIT $limit
            """;

        return database.QueryAsync<Transaction>(sql, new
        {
            search = $"%{search}%",
            type,
            from = from?.ToString("yyyy-MM-dd"),
            to = to?.ToString("yyyy-MM-dd"),
            limit,
        });
    }

    public Task<Transaction?> GetTransactionAsync(long id) =>
        database.QuerySingleAsync<Transaction>(
            """
            SELECT t.*, COALESCE(c.name,'Umum') AS customer_name, COALESCE(u.name,'') AS cashier_name
            FROM transactions t
            LEFT JOIN customers c ON c.id=t.customer_id
            LEFT JOIN users u ON u.id=t.user_id
            WHERE t.id=$id
            """,
            new { id });

    public Task<List<TransactionItem>> GetTransactionItemsAsync(long transactionId) =>
        database.QueryAsync<TransactionItem>(
            "SELECT * FROM transaction_items WHERE transaction_id=$transactionId ORDER BY id",
            new { transactionId });

    public Task<List<Payment>> GetPaymentsAsync(int limit = 200) =>
        database.QueryAsync<Payment>(
            "SELECT * FROM payments ORDER BY created_at DESC LIMIT $limit",
            new { limit });

    public Task<List<Expense>> GetExpensesAsync() =>
        database.QueryAsync<Expense>(
            """
            SELECT e.*, COALESCE(b.name,'') AS branch_name, COALESCE(u.name,'') AS user_name
            FROM expenses e
            LEFT JOIN branches b ON b.id=e.branch_id
            LEFT JOIN users u ON u.id=e.user_id
            ORDER BY e.created_at DESC, e.id DESC
            """);

    public Task<List<ParkedTransaction>> GetParkedAsync()
    {
        return LoadParkedAsync();
    }

    private async Task<List<ParkedTransaction>> LoadParkedAsync()
    {
        var rows = await database.QueryAsync<ParkedTransaction>(
            """
            SELECT p.*, COALESCE(c.name,'Umum') AS customer_name FROM parked_transactions p
            LEFT JOIN customers c ON c.id=p.customer_id
            ORDER BY p.created_at DESC
            """);

        foreach (var row in rows)
        {
            row.Items = SalesService.DeserializeParkedItems(row.ItemsJson)
                .Select(line => new CartLineDto
                {
                    ProductId = line.ProductId,
                    ProductName = line.ProductName,
                    Sku = line.Sku,
                    Quantity = line.Quantity,
                    UnitPrice = line.UnitPrice,
                    Discount = line.Discount,
                    Subtotal = line.Quantity * line.UnitPrice - line.Discount,
                })
                .ToList();
            row.Customer = string.IsNullOrEmpty(row.CustomerName) ? null : new Customer { Name = row.CustomerName };
        }

        return rows;
    }

    public Task<List<InventoryHistory>> GetInventoryHistoryAsync(int limit = 200) =>
        database.QueryAsync<InventoryHistory>(
            """
            SELECT h.*, COALESCE(p.name,'') AS product_name, COALESCE(u.name,'') AS user_name
            FROM inventory_histories h
            LEFT JOIN products p ON p.id=h.product_id
            LEFT JOIN users u ON u.id=h.user_id
            ORDER BY h.created_at DESC, h.id DESC LIMIT $limit
            """,
            new { limit });

    public async Task<List<PurchaseOrder>> GetPurchaseOrdersAsync()
    {
        var orders = await database.QueryAsync<PurchaseOrder>(
            """
            SELECT po.*, COALESCE(s.name,'') AS supplier_name FROM purchase_orders po
            LEFT JOIN suppliers s ON s.id=po.supplier_id
            ORDER BY po.created_at DESC, po.id DESC
            """);

        foreach (var order in orders)
        {
            order.Items = await GetPurchaseOrderItemsAsync(order.Id);
        }

        return orders;
    }

    public Task<List<PurchaseOrderItem>> GetPurchaseOrderItemsAsync(long purchaseOrderId) =>
        database.QueryAsync<PurchaseOrderItem>(
            """
            SELECT i.*, COALESCE(p.name,'') AS product_name FROM purchase_order_items i
            LEFT JOIN products p ON p.id=i.product_id
            WHERE i.purchase_order_id=$purchaseOrderId ORDER BY i.id
            """,
            new { purchaseOrderId });

    public async Task<List<StockCount>> GetStockCountsAsync()
    {
        var counts = await database.QueryAsync<StockCount>(
            """
            SELECT sc.*, COALESCE(u.name,'') AS creator_name FROM stock_counts sc
            LEFT JOIN users u ON u.id=sc.user_id
            ORDER BY sc.created_at DESC, sc.id DESC
            """);

        foreach (var count in counts)
        {
            count.Items = await GetStockCountItemsAsync(count.Id);
        }

        return counts;
    }

    public Task<List<StockCountItem>> GetStockCountItemsAsync(long stockCountId) =>
        database.QueryAsync<StockCountItem>(
            """
            SELECT i.*, COALESCE(p.name,'') AS product_name FROM stock_count_items i
            LEFT JOIN products p ON p.id=i.product_id
            WHERE i.stock_count_id=$stockCountId ORDER BY i.id
            """,
            new { stockCountId });

    public Task<List<SupplierInvoice>> GetSupplierInvoicesAsync() =>
        database.QueryAsync<SupplierInvoice>(
            """
            SELECT si.*, COALESCE(s.name,'') AS supplier_name FROM supplier_invoices si
            LEFT JOIN suppliers s ON s.id=si.supplier_id
            ORDER BY si.invoice_date DESC, si.id DESC
            """);

    public Task<List<ActivityLog>> GetActivityLogsAsync(int limit = 300) =>
        database.QueryAsync<ActivityLog>(
            """
            SELECT a.*, COALESCE(u.name,'Sistem') AS user_name FROM activity_logs a
            LEFT JOIN users u ON u.id=a.user_id
            ORDER BY a.created_at DESC, a.id DESC LIMIT $limit
            """,
            new { limit });

    public async Task<List<PaymentMethod>> GetPaymentMethodsAsync()
    {
        var rows = await database.QueryAsync<PaymentMethod>("SELECT * FROM payment_methods ORDER BY id");
        if (rows.Count > 0)
        {
            return rows;
        }

        foreach (var (name, label) in new[] { ("CASH", "Tunai"), ("CARD", "Kartu"), ("QRIS", "QRIS"), ("TRANSFER", "Transfer") })
        {
            await database.InsertAsync("payment_methods", new Dictionary<string, object?>
            {
                ["name"] = name,
                ["label"] = label,
                ["active"] = 1,
            });
        }

        return await database.QueryAsync<PaymentMethod>("SELECT * FROM payment_methods ORDER BY id");
    }

    public async Task EnsureDefaultSettingsAsync()
    {
        var defaults = new Dictionary<string, (string Value, string Group, string Label)>
        {
            ["store.name"] = ("TOKO POSQU PRO", "store", "Nama Toko"),
            ["store.phone"] = ("", "store", "Telepon Toko"),
            ["store.address"] = ("", "store", "Alamat Toko"),
            ["receipt.header"] = ("Terima Kasih Telah Berbelanja", "store", "Header Struk"),
            ["receipt.footer"] = ("SIMPLE · SMART · SUCCESS", "store", "Footer Struk"),
            ["printer.connection.type"] = ("Windows", "printer", "Tipe Koneksi"),
            ["printer.name"] = ("auto", "printer", "Nama Printer"),
            ["printer.paper.width"] = ("80", "printer", "Lebar Kertas (mm)"),
            ["printer.font.size"] = ("9", "printer", "Ukuran Font"),
            ["printer.font.family"] = ("Consolas", "printer", "Font"),
            ["printer.margin.top"] = ("0", "printer", "Margin Atas"),
            ["printer.margin.bottom"] = ("0", "printer", "Margin Bawah"),
            ["printer.margin.left"] = ("0", "printer", "Margin Kiri"),
            ["printer.spacing.line"] = ("80", "printer", "Spasi Baris"),
            ["printer.alignment"] = ("left", "printer", "Perataan"),
            ["printer.auto.print"] = ("false", "printer", "Cetak Otomatis"),
            ["drawer.printer"] = ("", "printer", "Printer Laci Kas"),
        };

        var existing = await database.GetSettingMapAsync();
        foreach (var (key, (value, group, label)) in defaults)
        {
            if (!existing.ContainsKey(key))
            {
                await database.SetSettingAsync(new SettingItem
                {
                    Key = key,
                    Value = value,
                    Group = group,
                    Label = label,
                    Type = "string",
                });
            }
        }
    }

    public async Task<DashboardData> GetDashboardAsync()
    {
        var data = new DashboardData
        {
            TodayRevenue = await database.ScalarAsync<decimal>(
                "SELECT COALESCE(SUM(total),0) FROM transactions WHERE type='sell' AND status='completed' AND date(created_at)=date('now','localtime')"),
            TodayTransactions = await database.ScalarAsync<int>(
                "SELECT COUNT(*) FROM transactions WHERE type='sell' AND date(created_at)=date('now','localtime')"),
            MonthRevenue = await database.ScalarAsync<decimal>(
                "SELECT COALESCE(SUM(total),0) FROM transactions WHERE type='sell' AND status='completed' AND strftime('%Y-%m', created_at)=strftime('%Y-%m','now','localtime')"),
            LowStockCount = await database.ScalarAsync<int>(
                "SELECT COUNT(*) FROM products WHERE is_active=1 AND stock <= min_stock"),
            RecentTransactions = await database.QueryAsync<Transaction>(
                """
                SELECT t.*, COALESCE(c.name,'Umum') AS customer_name, COALESCE(u.name,'') AS cashier_name
                FROM transactions t LEFT JOIN customers c ON c.id=t.customer_id
                LEFT JOIN users u ON u.id=t.user_id
                WHERE date(t.created_at)=date('now','localtime')
                ORDER BY t.created_at DESC, t.id DESC LIMIT 6
                """),
            LowStockProducts = await database.QueryAsync<Product>(
                """
                SELECT p.*, COALESCE(c.name,p.category_text,'') AS category_name
                FROM products p LEFT JOIN categories c ON c.id=p.category_id
                WHERE p.is_active=1 AND p.stock <= p.min_stock ORDER BY p.stock LIMIT 8
                """),
        };

        return data;
    }

    public async Task<SalesReportData> GetSalesReportAsync(DateTime from, DateTime to)
    {
        var args = new { from = from.ToString("yyyy-MM-dd"), to = to.ToString("yyyy-MM-dd") };
        var revenue = await database.ScalarAsync<decimal>(
            "SELECT COALESCE(SUM(total),0) FROM transactions WHERE type='sell' AND status='completed' AND date(created_at) BETWEEN date($from) AND date($to)",
            args);
        var transactions = await database.ScalarAsync<int>(
            "SELECT COUNT(*) FROM transactions WHERE type='sell' AND status='completed' AND date(created_at) BETWEEN date($from) AND date($to)",
            args);
        var itemsSold = await database.ScalarAsync<decimal>(
            """
            SELECT COALESCE(SUM(i.quantity),0) FROM transaction_items i
            JOIN transactions t ON t.id=i.transaction_id
            WHERE t.type='sell' AND t.status='completed' AND date(t.created_at) BETWEEN date($from) AND date($to)
            """,
            args);
        var expenses = await database.ScalarAsync<decimal>(
            "SELECT COALESCE(SUM(amount),0) FROM expenses WHERE date(created_at) BETWEEN date($from) AND date($to)",
            args);

        var daily = await database.QueryAsync<DailyPoint>(
            """
            SELECT date(created_at) AS date, SUM(total) AS total, COUNT(*) AS count
            FROM transactions WHERE type='sell' AND status='completed'
              AND date(created_at) BETWEEN date($from) AND date($to)
            GROUP BY date(created_at) ORDER BY date(created_at)
            """,
            args);

        var top = await database.QueryAsync<TopProduct>(
            """
            SELECT COALESCE(i.product_name, p.name, 'Produk') AS name,
                   SUM(i.quantity) AS quantity, SUM(i.subtotal) AS revenue
            FROM transaction_items i
            JOIN transactions t ON t.id=i.transaction_id
            LEFT JOIN products p ON p.id=i.product_id
            WHERE t.type='sell' AND t.status='completed' AND date(t.created_at) BETWEEN date($from) AND date($to)
            GROUP BY i.product_id, name ORDER BY quantity DESC LIMIT 10
            """,
            args);

        var payments = await database.QueryAsync<PaymentBreakdown>(
            """
            SELECT p.method AS method, SUM(p.amount) AS total FROM payments p
            JOIN transactions t ON t.id=p.transaction_id
            WHERE t.type='sell' AND t.status='completed' AND date(t.created_at) BETWEEN date($from) AND date($to)
            GROUP BY p.method ORDER BY total DESC
            """,
            args);

        return new SalesReportData
        {
            Revenue = revenue,
            Transactions = transactions,
            AverageBasket = transactions == 0 ? 0 : revenue / transactions,
            ItemsSold = itemsSold,
            Expenses = expenses,
            Daily = daily,
            TopProducts = top,
            Payments = payments,
        };
    }

    public async Task<InventoryReportData> GetInventoryReportAsync()
    {
        var lowStock = await database.QueryAsync<Product>(
            """
            SELECT p.*, COALESCE(c.name,p.category_text,'') AS category_name
            FROM products p LEFT JOIN categories c ON c.id=p.category_id
            WHERE p.is_active=1 AND p.stock <= p.min_stock ORDER BY p.stock
            """);

        return new InventoryReportData
        {
            TotalProducts = await database.CountAsync("products"),
            LowStockCount = lowStock.Count,
            StockCostValue = await database.ScalarAsync<decimal>("SELECT COALESCE(SUM(stock * cost_price),0) FROM products"),
            StockSellValue = await database.ScalarAsync<decimal>("SELECT COALESCE(SUM(stock * selling_price),0) FROM products"),
            LowStock = lowStock,
        };
    }
}
