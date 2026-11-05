using System.Globalization;
using System.IO;
using System.Reflection;
using System.Text.Json;
using Microsoft.Data.Sqlite;
using Posqupro.Desktop.Models;

namespace Posqupro.Desktop.Data;

/// <summary>
/// Local SQLite store. The desktop app is offline-first: every read and write goes to
/// this database, and a queue of pending operations is pushed to the Laravel API when online.
/// </summary>
public sealed class LocalDatabase
{
    private readonly string _connectionString;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private static readonly Dictionary<Type, Dictionary<string, PropertyInfo>> PropertyCache = [];
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public string DatabasePath { get; }

    public LocalDatabase(string? databasePath = null)
    {
        var folder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "POSQUPRO");
        Directory.CreateDirectory(folder);

        DatabasePath = databasePath ?? Path.Combine(folder, "posqupro.db");
        _connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = DatabasePath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Cache = SqliteCacheMode.Shared,
        }.ToString();
    }

    public async Task InitializeAsync()
    {
        await using var connection = await OpenAsync();
        var command = connection.CreateCommand();
        command.CommandText = Schema;
        await command.ExecuteNonQueryAsync();
    }

    private async Task<SqliteConnection> OpenAsync()
    {
        var connection = new SqliteConnection(_connectionString);
        await connection.OpenAsync();
        var pragma = connection.CreateCommand();
        pragma.CommandText = "PRAGMA journal_mode=WAL; PRAGMA foreign_keys=OFF; PRAGMA busy_timeout=5000;";
        await pragma.ExecuteNonQueryAsync();
        return connection;
    }

    private async Task<T> LockedAsync<T>(Func<SqliteConnection, Task<T>> action)
    {
        await _gate.WaitAsync();
        try
        {
            await using var connection = await OpenAsync();
            return await action(connection);
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task LockedAsync(Func<SqliteConnection, Task> action)
    {
        await _gate.WaitAsync();
        try
        {
            await using var connection = await OpenAsync();
            await action(connection);
        }
        finally
        {
            _gate.Release();
        }
    }

    public Task<int> ExecuteAsync(string sql, object? args = null) =>
        LockedAsync(async connection =>
        {
            await using var command = BuildCommand(connection, sql, args);
            return await command.ExecuteNonQueryAsync();
        });

    public Task<T?> ScalarAsync<T>(string sql, object? args = null) =>
        LockedAsync(async connection =>
        {
            await using var command = BuildCommand(connection, sql, args);
            var value = await command.ExecuteScalarAsync();
            if (value is null || value is DBNull)
            {
                return default;
            }

            return (T)Convert.ChangeType(value, Nullable.GetUnderlyingType(typeof(T)) ?? typeof(T), CultureInfo.InvariantCulture);
        });

    public Task<List<T>> QueryAsync<T>(string sql, object? args = null) where T : new() =>
        LockedAsync(async connection =>
        {
            await using var command = BuildCommand(connection, sql, args);
            await using var reader = await command.ExecuteReaderAsync();
            var map = GetPropertyMap(typeof(T));
            var rows = new List<T>();

            while (await reader.ReadAsync())
            {
                var item = new T();
                for (var i = 0; i < reader.FieldCount; i++)
                {
                    var column = Normalize(reader.GetName(i));
                    if (!map.TryGetValue(column, out var property))
                    {
                        continue;
                    }

                    var raw = reader.IsDBNull(i) ? null : reader.GetValue(i);
                    property.SetValue(item, ConvertValue(raw, property.PropertyType));
                }

                rows.Add(item);
            }

            return rows;
        });

    public Task<List<Dictionary<string, object?>>> QueryRowsAsync(string sql, object? args = null) =>
        LockedAsync(async connection =>
        {
            await using var command = BuildCommand(connection, sql, args);
            await using var reader = await command.ExecuteReaderAsync();
            var rows = new List<Dictionary<string, object?>>();

            while (await reader.ReadAsync())
            {
                var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                for (var i = 0; i < reader.FieldCount; i++)
                {
                    row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
                }

                rows.Add(row);
            }

            return rows;
        });

    public async Task<T?> QuerySingleAsync<T>(string sql, object? args = null) where T : new()
    {
        var rows = await QueryAsync<T>(sql, args);
        return rows.Count > 0 ? rows[0] : default;
    }

    public Task<int> InsertAsync(string table, IReadOnlyDictionary<string, object?> values) =>
        LockedAsync(async connection =>
        {
            await using var command = BuildInsertCommand(connection, table, values, returning: true);
            var result = await command.ExecuteScalarAsync();
            return Convert.ToInt32(result, CultureInfo.InvariantCulture);
        });

    /// <summary>
    /// Insert a server row, or update the local row that already mirrors it (matched by server_id).
    /// Returns the local row id.
    /// </summary>
    public Task<int> UpsertByServerIdAsync(
        string table,
        IReadOnlyDictionary<string, object?> values,
        IReadOnlyCollection<string>? preserveOnUpdate = null) =>
        LockedAsync(async connection =>
        {
            var serverId = values.TryGetValue("server_id", out var sid) ? sid : null;
            if (serverId is null)
            {
                await using var insert = BuildInsertCommand(connection, table, values, returning: true);
                return Convert.ToInt32(await insert.ExecuteScalarAsync(), CultureInfo.InvariantCulture);
            }

            var updates = values.Keys
                .Where(key => !string.Equals(key, "server_id", StringComparison.OrdinalIgnoreCase) && !string.Equals(key, "id", StringComparison.OrdinalIgnoreCase))
                .Where(key => preserveOnUpdate is null || !preserveOnUpdate.Contains(key, StringComparer.OrdinalIgnoreCase))
                .Select(key => $"{key}=excluded.{key}")
                .ToList();

            await using var command = BuildInsertCommand(connection, table, values, returning: true, updates);
            var result = await command.ExecuteScalarAsync();
            if (result is not null && result is not DBNull)
            {
                return Convert.ToInt32(result, CultureInfo.InvariantCulture);
            }

            await using var lookup = connection.CreateCommand();
            lookup.CommandText = $"SELECT id FROM {table} WHERE server_id=$server_id LIMIT 1";
            lookup.Parameters.AddWithValue("$server_id", serverId);
            return Convert.ToInt32(await lookup.ExecuteScalarAsync(), CultureInfo.InvariantCulture);
        });

    public Task UpdateAsync(string table, long id, IReadOnlyDictionary<string, object?> values) =>
        LockedAsync(async connection =>
        {
            await using var command = connection.CreateCommand();
            var sets = values.Keys.ToList();
            command.CommandText = $"UPDATE {table} SET {string.Join(", ", sets.Select(k => $"{k}=${k.TrimStart('@')}"))} WHERE id=$id";
            foreach (var key in sets)
            {
                command.Parameters.AddWithValue($"${key.TrimStart('@')}", ToDb(values[key]));
            }

            command.Parameters.AddWithValue("$id", id);
            await command.ExecuteNonQueryAsync();
        });

    public Task DeleteAsync(string table, long id) =>
        ExecuteAsync($"DELETE FROM {table} WHERE id=$id", new { id });

    public Task<int> CountAsync(string table) =>
        ScalarAsync<int>($"SELECT COUNT(*) FROM {table}");

    public Task<string?> GetMetaAsync(string key) =>
        ScalarAsync<string>("SELECT value FROM sync_meta WHERE key=$key", new { key });

    public Task SetMetaAsync(string key, string? value) =>
        ExecuteAsync(
            "INSERT INTO sync_meta (key, value) VALUES ($key, $value) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            new { key, value });

    public Task SetSettingAsync(SettingItem item) =>
        ExecuteAsync(
            """
            INSERT INTO settings (key, group_name, value, type, label, is_public, updated_at)
            VALUES ($key, $group, $value, $type, $label, $public, $updated)
            ON CONFLICT(key) DO UPDATE SET group_name=excluded.group_name, value=excluded.value,
                type=excluded.type, label=excluded.label, is_public=excluded.is_public, updated_at=excluded.updated_at
            """,
            new
            {
                key = item.Key,
                group = item.Group,
                value = item.Value,
                type = item.Type,
                label = item.Label,
                @public = item.IsPublic ? 1 : 0,
                updated = DateTime.UtcNow.ToString("o"),
            });

    public async Task<Dictionary<string, string>> GetSettingMapAsync()
    {
        var rows = await QueryAsync<SettingItem>("SELECT key, group_name AS \"group\", value, type, label, is_public FROM settings");
        return rows
            .GroupBy(row => row.Key, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.First().Value ?? "", StringComparer.OrdinalIgnoreCase);
    }

    public async Task<string?> GetSettingAsync(string key)
    {
        var map = await GetSettingMapAsync();
        return map.TryGetValue(key, out var value) ? value : null;
    }

    public async Task EnqueueAsync(string entity, string operation, long localId, object payload)
    {
        await ExecuteAsync(
            """
            INSERT INTO sync_queue (entity, operation, local_id, payload, attempts, created_at, next_attempt_at)
            VALUES ($entity, $operation, $localId, $payload, 0, $created, $created)
            """,
            new
            {
                entity,
                operation,
                localId,
                payload = JsonSerializer.Serialize(payload, JsonOptions),
                created = DateTime.UtcNow.ToString("o"),
            });
    }

    public Task<List<SyncQueueItem>> GetQueueAsync() =>
        QueryAsync<SyncQueueItem>("SELECT * FROM sync_queue ORDER BY id");

    public Task<int> QueueCountAsync() => ScalarAsync<int>("SELECT COUNT(*) FROM sync_queue");

    public Task RemoveQueueItemAsync(long id) =>
        ExecuteAsync("DELETE FROM sync_queue WHERE id=$id", new { id });

    public Task MarkQueueFailureAsync(long id, string error) =>
        ExecuteAsync(
            "UPDATE sync_queue SET attempts=attempts+1, last_error=$error, next_attempt_at=$next WHERE id=$id",
            new { id, error, next = DateTime.UtcNow.AddMinutes(1).ToString("o") });

    public async Task<long?> ResolveServerIdAsync(string table, long? localId)
    {
        if (localId is null or 0)
        {
            return null;
        }

        return await ScalarAsync<long?>($"SELECT server_id FROM {table} WHERE id=$id", new { id = localId });
    }

    public async Task<string> NextInvoiceNumberAsync()
    {
        var sequence = await ScalarAsync<long>("SELECT COALESCE(MAX(id),0)+1 FROM transactions");
        return $"INV-OFF-{DateTime.Now:yyyyMMdd}-{sequence:0000}";
    }

    private static SqliteCommand BuildCommand(SqliteConnection connection, string sql, object? args)
    {
        var command = connection.CreateCommand();
        command.CommandText = sql;
        if (args is null)
        {
            return command;
        }

        if (args is IReadOnlyDictionary<string, object?> dictionary)
        {
            foreach (var (key, value) in dictionary)
            {
                command.Parameters.AddWithValue($"${key.TrimStart('@')}", ToDb(value));
            }

            return command;
        }

        foreach (var property in args.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance))
        {
            command.Parameters.AddWithValue($"${property.Name}", ToDb(property.GetValue(args)));
        }

        return command;
    }

    private static SqliteCommand BuildInsertCommand(
        SqliteConnection connection,
        string table,
        IReadOnlyDictionary<string, object?> values,
        bool returning,
        IReadOnlyCollection<string>? updates = null)
    {
        var command = connection.CreateCommand();
        var columns = values.Keys.ToList();
        var parameters = columns.Select(column => $"${column}").ToList();

        var conflict = "";
        if (updates is not null)
        {
            conflict = $" ON CONFLICT(server_id) DO UPDATE SET {string.Join(", ", updates)}";
        }

        command.CommandText =
            $"INSERT INTO {table} ({string.Join(", ", columns)}) VALUES ({string.Join(", ", parameters)}){conflict}" +
            (returning ? " RETURNING id" : "");

        foreach (var column in columns)
        {
            command.Parameters.AddWithValue($"${column}", ToDb(values[column]));
        }

        return command;
    }

    private static object ToDb(object? value) => value switch
    {
        null => DBNull.Value,
        bool boolean => boolean ? 1 : 0,
        DateTime dateTime => dateTime.ToString("o", CultureInfo.InvariantCulture),
        DateTimeOffset dateTimeOffset => dateTimeOffset.ToString("o", CultureInfo.InvariantCulture),
        decimal number => (double)number,
        Enum enumeration => enumeration.ToString(),
        _ => value,
    };

    private static object? ConvertValue(object? raw, Type targetType)
    {
        if (raw is null or DBNull)
        {
            return targetType.IsValueType && Nullable.GetUnderlyingType(targetType) is null
                ? Activator.CreateInstance(targetType)
                : null;
        }

        var type = Nullable.GetUnderlyingType(targetType) ?? targetType;
        if (type == typeof(string))
        {
            return raw.ToString();
        }

        if (type == typeof(bool))
        {
            return raw switch
            {
                bool boolean => boolean,
                string text => text is "1" or "true" or "True",
                _ => Convert.ToInt64(raw, CultureInfo.InvariantCulture) != 0,
            };
        }

        if (type == typeof(DateTime))
        {
            return raw is DateTime value
                ? value
                : DateTime.Parse(raw.ToString()!, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
        }

        if (type == typeof(decimal))
        {
            return Convert.ToDecimal(raw, CultureInfo.InvariantCulture);
        }

        if (type == typeof(double))
        {
            return Convert.ToDouble(raw, CultureInfo.InvariantCulture);
        }

        if (type.IsEnum)
        {
            return Enum.Parse(type, raw.ToString()!, true);
        }

        return Convert.ChangeType(raw, type, CultureInfo.InvariantCulture);
    }

    private static string Normalize(string name) =>
        name.Replace("_", "", StringComparison.Ordinal).ToLowerInvariant();

    private static Dictionary<string, PropertyInfo> GetPropertyMap(Type type)
    {
        lock (PropertyCache)
        {
            if (PropertyCache.TryGetValue(type, out var cached))
            {
                return cached;
            }

            var map = new Dictionary<string, PropertyInfo>(StringComparer.OrdinalIgnoreCase);
            foreach (var property in type.GetProperties(BindingFlags.Public | BindingFlags.Instance))
            {
                if (!property.CanWrite)
                {
                    continue;
                }

                map[Normalize(property.Name)] = property;
            }

            PropertyCache[type] = map;
            return map;
        }
    }

    private const string Schema = """
        CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            name TEXT NOT NULL,
            slug TEXT,
            description TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS unit_quantities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            name TEXT NOT NULL,
            symbol TEXT,
            description TEXT,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS taxes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            name TEXT NOT NULL,
            rate REAL NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS suppliers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            code TEXT,
            name TEXT NOT NULL,
            email TEXT,
            phone TEXT,
            address TEXT,
            contact_person TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            name TEXT NOT NULL,
            email TEXT,
            phone TEXT,
            address TEXT,
            credit_limit REAL NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS branches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            code TEXT NOT NULL,
            name TEXT NOT NULL,
            address TEXT,
            phone TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS warehouses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            branch_id INTEGER,
            code TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT,
            address TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            name TEXT NOT NULL,
            email TEXT,
            role TEXT,
            phone TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS registers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            description TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS register_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            register_id INTEGER,
            user_id INTEGER,
            opening_float REAL NOT NULL DEFAULT 0,
            expected_cash REAL,
            actual_cash REAL,
            over_short REAL,
            status TEXT NOT NULL DEFAULT 'open',
            opened_at TEXT,
            closed_at TEXT,
            notes TEXT,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            name TEXT NOT NULL,
            sku TEXT NOT NULL,
            barcode TEXT,
            category_id INTEGER,
            category_text TEXT,
            unit_quantity_id INTEGER,
            tax_id INTEGER,
            supplier_id INTEGER,
            type TEXT NOT NULL DEFAULT 'finished_goods',
            cost_price REAL NOT NULL DEFAULT 0,
            selling_price REAL NOT NULL DEFAULT 0,
            price REAL NOT NULL DEFAULT 0,
            stock REAL NOT NULL DEFAULT 0,
            min_stock REAL NOT NULL DEFAULT 5,
            is_active INTEGER NOT NULL DEFAULT 1,
            description TEXT,
            image TEXT,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            invoice_number TEXT,
            type TEXT NOT NULL DEFAULT 'sell',
            customer_id INTEGER,
            supplier_id INTEGER,
            user_id INTEGER,
            subtotal REAL NOT NULL DEFAULT 0,
            discount REAL NOT NULL DEFAULT 0,
            tax_amount REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL DEFAULT 0,
            paid_amount REAL NOT NULL DEFAULT 0,
            change_amount REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'completed',
            notes TEXT,
            payment_method TEXT,
            created_at TEXT,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS transaction_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            transaction_id INTEGER NOT NULL,
            product_id INTEGER,
            product_name TEXT,
            sku TEXT,
            quantity REAL NOT NULL DEFAULT 0,
            unit_price REAL NOT NULL DEFAULT 0,
            discount REAL NOT NULL DEFAULT 0,
            subtotal REAL NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            sale_id INTEGER,
            transaction_id INTEGER,
            method TEXT NOT NULL DEFAULT 'CASH',
            amount REAL NOT NULL DEFAULT 0,
            reference_no TEXT,
            created_at TEXT
        );

        CREATE TABLE IF NOT EXISTS expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            branch_id INTEGER,
            shift_id INTEGER,
            user_id INTEGER,
            category TEXT NOT NULL,
            description TEXT,
            amount REAL NOT NULL DEFAULT 0,
            created_at TEXT
        );

        CREATE TABLE IF NOT EXISTS parked_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            invoice_number TEXT,
            customer_id INTEGER,
            items_json TEXT NOT NULL DEFAULT '[]',
            subtotal REAL NOT NULL DEFAULT 0,
            discount REAL NOT NULL DEFAULT 0,
            tax_amount REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL DEFAULT 0,
            notes TEXT,
            user_id INTEGER,
            created_at TEXT
        );

        CREATE TABLE IF NOT EXISTS purchase_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            po_number TEXT,
            supplier_id INTEGER,
            user_id INTEGER,
            status TEXT NOT NULL DEFAULT 'draft',
            expected_date TEXT,
            subtotal REAL NOT NULL DEFAULT 0,
            discount REAL NOT NULL DEFAULT 0,
            tax_amount REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL DEFAULT 0,
            notes TEXT,
            created_at TEXT
        );

        CREATE TABLE IF NOT EXISTS purchase_order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            purchase_order_id INTEGER NOT NULL,
            product_id INTEGER,
            quantity REAL NOT NULL DEFAULT 0,
            received_quantity REAL NOT NULL DEFAULT 0,
            unit_cost REAL NOT NULL DEFAULT 0,
            discount REAL NOT NULL DEFAULT 0,
            subtotal REAL NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS stock_counts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            count_number TEXT,
            user_id INTEGER,
            status TEXT NOT NULL DEFAULT 'draft',
            is_blind INTEGER NOT NULL DEFAULT 0,
            counted_at TEXT,
            approved_at TEXT,
            posted_at TEXT,
            notes TEXT,
            created_at TEXT
        );

        CREATE TABLE IF NOT EXISTS stock_count_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            stock_count_id INTEGER NOT NULL,
            product_id INTEGER,
            system_quantity REAL NOT NULL DEFAULT 0,
            counted_quantity REAL,
            variance REAL,
            notes TEXT
        );

        CREATE TABLE IF NOT EXISTS supplier_invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            supplier_id INTEGER,
            purchase_order_id INTEGER,
            invoice_number TEXT NOT NULL,
            invoice_date TEXT,
            due_date TEXT,
            amount REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'pending',
            notes TEXT
        );

        CREATE TABLE IF NOT EXISTS inventory_histories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            product_id INTEGER,
            user_id INTEGER,
            type TEXT NOT NULL DEFAULT 'in',
            quantity REAL NOT NULL DEFAULT 0,
            stock_before REAL,
            stock_after REAL,
            reason TEXT,
            created_at TEXT
        );

        CREATE TABLE IF NOT EXISTS activity_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            user_id INTEGER,
            event TEXT,
            description TEXT,
            subject_type TEXT,
            subject_id INTEGER,
            created_at TEXT
        );

        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            group_name TEXT,
            value TEXT,
            type TEXT,
            label TEXT,
            is_public INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT
        );

        CREATE TABLE IF NOT EXISTS payment_methods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER UNIQUE,
            name TEXT NOT NULL,
            label TEXT,
            active INTEGER NOT NULL DEFAULT 1
        );

        CREATE TABLE IF NOT EXISTS sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity TEXT NOT NULL,
            operation TEXT NOT NULL,
            local_id INTEGER NOT NULL DEFAULT 0,
            payload TEXT NOT NULL DEFAULT '{}',
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at TEXT NOT NULL,
            next_attempt_at TEXT
        );

        CREATE TABLE IF NOT EXISTS sync_meta (
            key TEXT PRIMARY KEY,
            value TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_products_server ON products(server_id);
        CREATE INDEX IF NOT EXISTS idx_transactions_created ON transactions(created_at);
        CREATE INDEX IF NOT EXISTS idx_transaction_items_tx ON transaction_items(transaction_id);
        CREATE INDEX IF NOT EXISTS idx_parked_created ON parked_transactions(created_at);
        CREATE INDEX IF NOT EXISTS idx_queue_created ON sync_queue(created_at);
        """;
}

