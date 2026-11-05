using Posqupro.Desktop.Services;

namespace Posqupro.Desktop.ViewModels;

/// <summary>Screen definitions for the shared master-data editor.</summary>
public static class CrudCatalog
{
    private static Func<Task<List<ChoiceOption>>> Lookup(string table, string column = "name") =>
        async () =>
        {
            var rows = await AppServices.Db.QueryRowsAsync($"SELECT id, {column} AS label FROM {table} ORDER BY {column}");
            return rows
                .Where(row => row["id"] is not null)
                .Select(row => new ChoiceOption(
                    Convert.ToInt64(row["id"]),
                    row["label"]?.ToString() ?? ""))
                .ToList();
        };

    public static readonly FieldDef[] ProductFields =
    [
        new() { Key = "name", Label = "Nama Produk", Required = true },
        new() { Key = "sku", Label = "SKU", Placeholder = "Kosongkan untuk otomatis" },
        new() { Key = "barcode", Label = "Barcode" },
        new() { Key = "category_id", Label = "Kategori", Kind = FieldKind.Choice, OptionsLoader = Lookup("categories") },
        new() { Key = "unit_quantity_id", Label = "Satuan", Kind = FieldKind.Choice, OptionsLoader = Lookup("unit_quantities", "name") },
        new() { Key = "tax_id", Label = "Pajak", Kind = FieldKind.Choice, OptionsLoader = Lookup("taxes") },
        new() { Key = "supplier_id", Label = "Supplier", Kind = FieldKind.Choice, OptionsLoader = Lookup("suppliers") },
        new() { Key = "type", Label = "Tipe", Kind = FieldKind.TextChoice, TextOptions = ["finished_goods", "raw_material", "service"] },
        new() { Key = "cost_price", Label = "Harga Beli", Kind = FieldKind.Decimal },
        new() { Key = "selling_price", Label = "Harga Jual", Kind = FieldKind.Decimal, Required = true },
        new() { Key = "stock", Label = "Stok", Kind = FieldKind.Number },
        new() { Key = "min_stock", Label = "Stok Minimum", Kind = FieldKind.Number },
        new() { Key = "description", Label = "Deskripsi" },
        new() { Key = "is_active", Label = "Aktif", Kind = FieldKind.Bool },
    ];

    public static CrudDefinition Products() => new()
    {
        Title = "Produk",
        Entity = "product",
        Table = "products",
        Resource = "products",
        SelectSql = """
            SELECT p.*, COALESCE(c.name, p.category_text, '') AS category_name
            FROM products p LEFT JOIN categories c ON c.id=p.category_id
            """,
        Fields = [.. ProductFields],
        Columns =
        [
            new() { Key = "name", Header = "Produk", Width = 240, Bold = true },
            new() { Key = "sku", Header = "SKU", Width = 120 },
            new() { Key = "category_name", Header = "Kategori", Width = 140 },
            new() { Key = "stock", Header = "Stok", Width = 70, StringFormat = "{0:N0}" },
            new() { Key = "min_stock", Header = "Min", Width = 60, StringFormat = "{0:N0}" },
            new() { Key = "selling_price", Header = "Harga Jual", Width = 120, StringFormat = "Rp {0:N0}" },
            new() { Key = "is_active", Header = "Status", Width = 80 },
        ],
        SearchColumns = ["p.name", "p.sku", "p.barcode"],
        OrderBy = " ORDER BY p.name",
        BeforeSave = async (_, values) =>
        {
            values["price"] = values.GetValueOrDefault("selling_price");
            values["updated_at"] = DateTime.Now;
            if (values.GetValueOrDefault("category_id") is long categoryId)
            {
                values["category_text"] = await AppServices.Db.ScalarAsync<string>(
                    "SELECT name FROM categories WHERE id=$id", new { id = categoryId });
            }

            await Task.CompletedTask;
        },
    };

    public static CrudDefinition Categories() => new()
    {
        Title = "Kategori",
        Entity = "category",
        Table = "categories",
        Resource = "categories",
        SelectSql = "SELECT * FROM categories",
        Fields =
        [
            new() { Key = "name", Label = "Nama Kategori", Required = true },
            new() { Key = "description", Label = "Deskripsi" },
            new() { Key = "is_active", Label = "Aktif", Kind = FieldKind.Bool },
        ],
        Columns =
        [
            new() { Key = "name", Header = "Kategori", Width = 240, Bold = true },
            new() { Key = "description", Header = "Deskripsi", Width = 320 },
            new() { Key = "is_active", Header = "Status", Width = 90 },
        ],
        SearchColumns = ["name"],
        OrderBy = " ORDER BY name",
    };

    public static CrudDefinition Units() => new()
    {
        Title = "Satuan",
        Entity = "unit",
        Table = "unit_quantities",
        Resource = "unit-quantities",
        SelectSql = "SELECT * FROM unit_quantities",
        Fields =
        [
            new() { Key = "name", Label = "Nama Satuan", Required = true },
            new() { Key = "symbol", Label = "Simbol", Required = true },
            new() { Key = "description", Label = "Deskripsi" },
        ],
        Columns =
        [
            new() { Key = "name", Header = "Satuan", Width = 220, Bold = true },
            new() { Key = "symbol", Header = "Simbol", Width = 120 },
            new() { Key = "description", Header = "Deskripsi", Width = 320 },
        ],
        SearchColumns = ["name", "symbol"],
        OrderBy = " ORDER BY name",
    };

    public static CrudDefinition Taxes() => new()
    {
        Title = "Pajak",
        Entity = "tax",
        Table = "taxes",
        Resource = "taxes",
        SelectSql = "SELECT * FROM taxes",
        Fields =
        [
            new() { Key = "name", Label = "Nama Pajak", Required = true },
            new() { Key = "rate", Label = "Tarif (%)", Kind = FieldKind.Decimal, Required = true },
            new() { Key = "is_active", Label = "Aktif", Kind = FieldKind.Bool },
        ],
        Columns =
        [
            new() { Key = "name", Header = "Pajak", Width = 260, Bold = true },
            new() { Key = "rate", Header = "Tarif", Width = 120, StringFormat = "{0:0.##}%" },
            new() { Key = "is_active", Header = "Status", Width = 90 },
        ],
        SearchColumns = ["name"],
        OrderBy = " ORDER BY name",
    };

    public static CrudDefinition Customers() => new()
    {
        Title = "Pelanggan",
        Entity = "customer",
        Table = "customers",
        Resource = "customers",
        SelectSql = "SELECT * FROM customers",
        Fields =
        [
            new() { Key = "name", Label = "Nama", Required = true },
            new() { Key = "email", Label = "Email" },
            new() { Key = "phone", Label = "Telepon" },
            new() { Key = "address", Label = "Alamat" },
            new() { Key = "credit_limit", Label = "Limit Kredit", Kind = FieldKind.Decimal },
            new() { Key = "is_active", Label = "Aktif", Kind = FieldKind.Bool },
        ],
        Columns =
        [
            new() { Key = "name", Header = "Pelanggan", Width = 240, Bold = true },
            new() { Key = "phone", Header = "Telepon", Width = 150 },
            new() { Key = "email", Header = "Email", Width = 220 },
            new() { Key = "credit_limit", Header = "Limit", Width = 120, StringFormat = "Rp {0:N0}" },
            new() { Key = "is_active", Header = "Status", Width = 80 },
        ],
        SearchColumns = ["name", "phone", "email"],
        OrderBy = " ORDER BY name",
    };

    public static CrudDefinition Suppliers() => new()
    {
        Title = "Supplier",
        Entity = "supplier",
        Table = "suppliers",
        Resource = "suppliers",
        SelectSql = "SELECT * FROM suppliers",
        Fields =
        [
            new() { Key = "code", Label = "Kode", Placeholder = "Kosongkan untuk otomatis" },
            new() { Key = "name", Label = "Nama Supplier", Required = true },
            new() { Key = "email", Label = "Email" },
            new() { Key = "phone", Label = "Telepon" },
            new() { Key = "address", Label = "Alamat" },
            new() { Key = "contact_person", Label = "Kontak Person" },
            new() { Key = "is_active", Label = "Aktif", Kind = FieldKind.Bool },
        ],
        Columns =
        [
            new() { Key = "code", Header = "Kode", Width = 110 },
            new() { Key = "name", Header = "Supplier", Width = 220, Bold = true },
            new() { Key = "phone", Header = "Telepon", Width = 150 },
            new() { Key = "contact_person", Header = "Kontak", Width = 160 },
            new() { Key = "is_active", Header = "Status", Width = 80 },
        ],
        SearchColumns = ["name", "code", "phone"],
        OrderBy = " ORDER BY name",
    };

    public static CrudDefinition Branches() => new()
    {
        Title = "Cabang",
        Entity = "branch",
        Table = "branches",
        Resource = "branches",
        SelectSql = "SELECT * FROM branches",
        Fields =
        [
            new() { Key = "code", Label = "Kode Cabang", Required = true },
            new() { Key = "name", Label = "Nama Cabang", Required = true },
            new() { Key = "address", Label = "Alamat" },
            new() { Key = "phone", Label = "Telepon" },
            new() { Key = "active", Label = "Aktif", Kind = FieldKind.Bool },
        ],
        Columns =
        [
            new() { Key = "code", Header = "Kode", Width = 110 },
            new() { Key = "name", Header = "Cabang", Width = 240, Bold = true },
            new() { Key = "phone", Header = "Telepon", Width = 150 },
            new() { Key = "active", Header = "Status", Width = 80 },
        ],
        SearchColumns = ["name", "code"],
        OrderBy = " ORDER BY name",
    };

    public static CrudDefinition Warehouses() => new()
    {
        Title = "Gudang",
        Entity = "warehouse",
        Table = "warehouses",
        Resource = "warehouses",
        SelectSql = """
            SELECT w.*, b.name AS branch_name FROM warehouses w
            LEFT JOIN branches b ON b.id=w.branch_id
            """,
        Fields =
        [
            new() { Key = "branch_id", Label = "Cabang", Kind = FieldKind.Choice, Required = true, OptionsLoader = Lookup("branches") },
            new() { Key = "code", Label = "Kode Gudang", Required = true },
            new() { Key = "name", Label = "Nama Gudang", Required = true },
            new() { Key = "phone", Label = "Telepon" },
            new() { Key = "address", Label = "Alamat" },
            new() { Key = "active", Label = "Aktif", Kind = FieldKind.Bool },
        ],
        Columns =
        [
            new() { Key = "code", Header = "Kode", Width = 110 },
            new() { Key = "name", Header = "Gudang", Width = 220, Bold = true },
            new() { Key = "branch_name", Header = "Cabang", Width = 180 },
            new() { Key = "address", Header = "Alamat", Width = 260 },
            new() { Key = "active", Header = "Status", Width = 80 },
        ],
        SearchColumns = ["w.name", "w.code"],
        OrderBy = " ORDER BY w.name",
    };

    public static CrudDefinition Users() => new()
    {
        Title = "Pengguna & RBAC",
        Entity = "user",
        Table = "users",
        Resource = "users",
        SelectSql = "SELECT * FROM users",
        Fields =
        [
            new() { Key = "name", Label = "Nama", Required = true },
            new() { Key = "email", Label = "Email", Required = true },
            new() { Key = "phone", Label = "Telepon" },
            new() { Key = "role", Label = "Role", Kind = FieldKind.TextChoice, Required = true, TextOptions = ["Admin", "Cashier", "Warehouse Manager", "Finance"] },
            new() { Key = "password", Label = "Password", Kind = FieldKind.Password },
            new() { Key = "is_active", Label = "Aktif", Kind = FieldKind.Bool },
        ],
        Columns =
        [
            new() { Key = "name", Header = "Pengguna", Width = 220, Bold = true },
            new() { Key = "email", Header = "Email", Width = 240 },
            new() { Key = "role", Header = "Role", Width = 160 },
            new() { Key = "phone", Header = "Telepon", Width = 140 },
            new() { Key = "is_active", Header = "Status", Width = 80 },
        ],
        SearchColumns = ["name", "email"],
        OrderBy = " ORDER BY name",
        PayloadTransform = values =>
        {
            var payload = new Dictionary<string, object?>
            {
                ["name"] = values.GetValueOrDefault("name"),
                ["email"] = values.GetValueOrDefault("email"),
                ["phone"] = values.GetValueOrDefault("phone"),
                ["is_active"] = values.GetValueOrDefault("is_active"),
                ["roles"] = new[] { values.GetValueOrDefault("role")?.ToString() ?? "Cashier" },
            };

            var password = values.GetValueOrDefault("password")?.ToString();
            if (!string.IsNullOrWhiteSpace(password))
            {
                payload["password"] = password;
            }

            return payload;
        },
    };

    public static CrudDefinition Registers() => new()
    {
        Title = "Register / Mesin Kasir",
        Entity = "register",
        Table = "registers",
        Resource = "registers",
        SelectSql = "SELECT * FROM registers",
        Fields =
        [
            new() { Key = "name", Label = "Nama Register", Required = true },
            new() { Key = "code", Label = "Kode", Required = true },
            new() { Key = "description", Label = "Deskripsi" },
            new() { Key = "is_active", Label = "Aktif", Kind = FieldKind.Bool },
        ],
        Columns =
        [
            new() { Key = "name", Header = "Register", Width = 220, Bold = true },
            new() { Key = "code", Header = "Kode", Width = 120 },
            new() { Key = "description", Header = "Deskripsi", Width = 300 },
            new() { Key = "is_active", Header = "Status", Width = 80 },
        ],
        SearchColumns = ["name", "code"],
        OrderBy = " ORDER BY name",
    };

    public static CrudDefinition Expenses() => new()
    {
        Title = "Pengeluaran",
        Entity = "expense",
        Table = "expenses",
        Resource = "expenses",
        SelectSql = """
            SELECT e.*, COALESCE(b.name,'') AS branch_name, COALESCE(u.name,'') AS user_name
            FROM expenses e
            LEFT JOIN branches b ON b.id=e.branch_id
            LEFT JOIN users u ON u.id=e.user_id
            """,
        Fields =
        [
            new() { Key = "branch_id", Label = "Cabang", Kind = FieldKind.Choice, OptionsLoader = Lookup("branches") },
            new() { Key = "category", Label = "Kategori", Required = true },
            new() { Key = "description", Label = "Keterangan" },
            new() { Key = "amount", Label = "Jumlah", Kind = FieldKind.Decimal, Required = true },
        ],
        Columns =
        [
            new() { Key = "created_at", Header = "Tanggal", Width = 140 },
            new() { Key = "category", Header = "Kategori", Width = 160, Bold = true },
            new() { Key = "description", Header = "Keterangan", Width = 280 },
            new() { Key = "amount", Header = "Jumlah", Width = 130, StringFormat = "Rp {0:N0}" },
            new() { Key = "branch_name", Header = "Cabang", Width = 140 },
        ],
        SearchColumns = ["e.category", "e.description"],
        OrderBy = " ORDER BY e.created_at DESC",
        BeforeSave = (_, values) =>
        {
            values["created_at"] = DateTime.Now;
            values["user_id"] = AppServices.Settings.Value.UserId;
            return Task.CompletedTask;
        },
        PayloadTransform = values => new Dictionary<string, object?>
        {
            ["branch_id"] = values.GetValueOrDefault("branch_id"),
            ["category"] = values.GetValueOrDefault("category"),
            ["description"] = values.GetValueOrDefault("description"),
            ["amount"] = (long)Convert.ToDecimal(values.GetValueOrDefault("amount") ?? 0),
        },
    };

    public static CrudDefinition ActivityLogs() => new()
    {
        Title = "Log Aktivitas",
        Entity = "activity_log",
        Table = "activity_logs",
        Resource = "activity-logs",
        SelectSql = """
            SELECT a.*, COALESCE(u.name,'Sistem') AS user_name FROM activity_logs a
            LEFT JOIN users u ON u.id=a.user_id
            """,
        Fields = [],
        Columns =
        [
            new() { Key = "created_at", Header = "Waktu", Width = 150 },
            new() { Key = "user_name", Header = "Pengguna", Width = 150 },
            new() { Key = "event", Header = "Event", Width = 180, Bold = true },
            new() { Key = "description", Header = "Deskripsi", Width = 380 },
            new() { Key = "subject_type", Header = "Subjek", Width = 180 },
        ],
        SearchColumns = ["a.event", "a.description"],
        OrderBy = " ORDER BY a.created_at DESC",
        CanCreate = false,
        CanDelete = false,
    };
}
