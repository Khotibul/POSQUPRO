using System.Globalization;
using System.Text.Json;
using Posqupro.Desktop.Data;
using Posqupro.Desktop.Models;

namespace Posqupro.Desktop.Services;

public readonly record struct PushResult(bool Ok, bool Offline, string? Error)
{
    public static PushResult Success => new(true, false, null);
    public static PushResult OfflineResult => new(false, true, null);
    public static PushResult Failed(string error) => new(false, false, error);
}

/// <summary>
/// Bidirectional sync. Local writes are queued in <c>sync_queue</c> and pushed when the API is
/// reachable; master data and recent transactions are pulled back into SQLite.
/// </summary>
public sealed class SyncService(LocalDatabase database, ApiClient api, AppSettingsStore settings)
{
    private static readonly Dictionary<string, string> IdTables = new(StringComparer.OrdinalIgnoreCase)
    {
        ["category_id"] = "categories",
        ["unit_quantity_id"] = "unit_quantities",
        ["tax_id"] = "taxes",
        ["supplier_id"] = "suppliers",
        ["customer_id"] = "customers",
        ["branch_id"] = "branches",
        ["warehouse_id"] = "warehouses",
        ["product_id"] = "products",
        ["register_id"] = "registers",
        ["user_id"] = "users",
        ["purchase_order_id"] = "purchase_orders",
        ["stock_count_id"] = "stock_counts",
    };

    private static readonly JsonSerializerOptions PayloadJson = new(JsonSerializerDefaults.Web);
    private readonly SemaphoreSlim _gate = new(1, 1);
    private DateTime _lastRun = DateTime.MinValue;

    public bool IsOnline { get; private set; }
    public bool IsSyncing { get; private set; }
    public string StatusMessage { get; private set; } = "Belum tersinkron.";
    public DateTime? LastSyncAt => settings.Value.LastSyncAt;
    public int PendingCount { get; private set; }
    public int FailedCount { get; private set; }
    public bool AuthExpired { get; private set; }

    public event Action? Changed;

    public async Task TickAsync()
    {
        var ping = await api.PingAsync();
        var wasOnline = IsOnline;
        IsOnline = ping.Success;

        if (!IsOnline)
        {
            PendingCount = await database.QueueCountAsync();
            if (wasOnline || StatusMessage != "Mode offline. Perubahan disimpan lokal dan dikirim saat online.")
            {
                StatusMessage = "Mode offline. Perubahan disimpan lokal dan dikirim saat online.";
            }

            Notify();
            return;
        }

        if (!settings.Value.AutoSync || IsSyncing || AuthExpired || string.IsNullOrWhiteSpace(settings.Value.Token))
        {
            PendingCount = await database.QueueCountAsync();
            Notify();
            return;
        }

        var due = settings.Value.LastSyncAt is null
                  || DateTime.Now - settings.Value.LastSyncAt > TimeSpan.FromMinutes(5)
                  || PendingCount > 0;

        if (!due || DateTime.Now - _lastRun < TimeSpan.FromSeconds(40))
        {
            PendingCount = await database.QueueCountAsync();
            Notify();
            return;
        }

        await RunAsync(full: settings.Value.LastSyncAt is null);
    }

    public async Task RunAsync(bool full = false)
    {
        if (IsSyncing)
        {
            return;
        }

        await _gate.WaitAsync();
        try
        {
            IsSyncing = true;
            _lastRun = DateTime.Now;
            StatusMessage = "Menyinkronkan data...";
            Notify();

            var pushed = await PushAsync();
            if (!IsOnline)
            {
                StatusMessage = "Koneksi terputus saat sinkronisasi. Data tetap tersimpan lokal.";
                return;
            }

            await PullAsync(full);

            settings.Value.LastSyncAt = DateTime.Now;
            settings.Save();
            StatusMessage = $"Sinkron selesai {DateTime.Now:HH:mm}. {pushed} perubahan dikirim.";
        }
        catch (Exception exception)
        {
            StatusMessage = $"Sinkronisasi gagal: {exception.Message}";
        }
        finally
        {
            PendingCount = await database.QueueCountAsync();
            var queue = await database.GetQueueAsync();
            FailedCount = queue.Count(item => item.Attempts > 0);
            IsSyncing = false;
            _gate.Release();
            Notify();
        }
    }

    public async Task RetryQueueItemAsync(long queueId)
    {
        await database.ExecuteAsync(
            "UPDATE sync_queue SET attempts=0, last_error=NULL WHERE id=$id",
            new { id = queueId });
        await RunAsync();
    }

    public async Task DiscardQueueItemAsync(long queueId) =>
        await database.RemoveQueueItemAsync(queueId);

    public async Task RefreshCountersAsync()
    {
        PendingCount = await database.QueueCountAsync();
        var queue = await database.GetQueueAsync();
        FailedCount = queue.Count(item => item.Attempts > 0);
        Notify();
    }

    private void Notify()
    {
        Changed?.Invoke();
    }

    private async Task<int> PushAsync()
    {
        var queue = await database.GetQueueAsync();
        var pushed = 0;

        foreach (var item in queue)
        {
            if (!IsOnline)
            {
                break;
            }

            PushResult result;
            try
            {
                result = await PushItemAsync(item);
            }
            catch (Exception exception)
            {
                result = PushResult.Failed(exception.Message);
            }

            if (result.Ok)
            {
                await database.RemoveQueueItemAsync(item.Id);
                pushed++;
            }
            else if (result.Offline)
            {
                IsOnline = false;
                break;
            }
            else
            {
                await database.MarkQueueFailureAsync(item.Id, result.Error ?? "Gagal menyinkronkan data.");
                if (item.Attempts >= 4)
                {
                    // Keep the item for manual retry, but stop blocking later independent changes.
                    continue;
                }
            }
        }

        return pushed;
    }

    private async Task<PushResult> PushItemAsync(SyncQueueItem item)
    {
        return item.Entity switch
        {
            "category" => await PushMasterAsync("categories", "categories", item),
            "unit" => await PushMasterAsync("unit-quantities", "unit_quantities", item),
            "tax" => await PushMasterAsync("taxes", "taxes", item),
            "supplier" => await PushMasterAsync("suppliers", "suppliers", item),
            "customer" => await PushMasterAsync("customers", "customers", item),
            "branch" => await PushMasterAsync("branches", "branches", item),
            "warehouse" => await PushMasterAsync("warehouses", "warehouses", item),
            "user" => await PushMasterAsync("users", "users", item),
            "register" => await PushMasterAsync("registers", "registers", item),
            "product" => await PushProductAsync(item),
            "expense" => await PushMasterAsync("expenses", "expenses", item),
            "supplier_invoice" => await PushMasterAsync("supplier-invoices", "supplier_invoices", item),
            "transaction" => await PushTransactionAsync(item),
            "parked_transaction" => await PushParkedAsync(item),
            "purchase_order" => await PushPurchaseOrderAsync(item),
            "stock_count" => await PushStockCountAsync(item),
            "register_session" => await PushRegisterSessionAsync(item),
            "inventory" => await PushInventoryAsync(item),
            "setting" => await PushSettingAsync(item),
            _ => PushResult.Failed($"Entitas sinkronisasi tidak dikenal: {item.Entity}"),
        };
    }

    private async Task<PushResult> PushMasterAsync(string resource, string table, SyncQueueItem item)
    {
        switch (item.Operation)
        {
            case "create":
            {
                var payload = await BuildPayloadAsync(item.Payload);
                var result = await api.PostAsync(resource, payload);
                if (!result.Success)
                {
                    return MapFailure(result);
                }

                var updates = new Dictionary<string, object?> { ["server_id"] = Json.Long(result.Data, "id") };
                CopyIfPresent(result.Data, updates, "code");
                CopyIfPresent(result.Data, updates, "slug");
                await database.UpdateAsync(table, item.LocalId, updates);
                return PushResult.Success;
            }
            case "update":
            {
                var serverId = await database.ResolveServerIdAsync(table, item.LocalId);
                if (serverId is null)
                {
                    return PushResult.Failed("Data belum memiliki ID server. Sinkronkan ulang.");
                }

                var payload = await BuildPayloadAsync(item.Payload);
                var result = await api.PutAsync($"{resource}/{serverId}", payload);
                return result.Success ? PushResult.Success : MapFailure(result);
            }
            case "delete":
            {
                var serverId = await database.ResolveServerIdAsync(table, item.LocalId);
                if (serverId is not null)
                {
                    var result = await api.DeleteAsync($"{resource}/{serverId}");
                    if (!result.Success && !result.Offline && result.StatusCode != 404)
                    {
                        return MapFailure(result);
                    }
                }

                await database.DeleteAsync(table, item.LocalId);
                return PushResult.Success;
            }
            default:
                return PushResult.Failed($"Operasi {item.Operation} tidak didukung.");
        }
    }

    private async Task<PushResult> PushProductAsync(SyncQueueItem item)
    {
        var payload = await BuildPayloadAsync(item.Payload);
        if (item.Operation == "create")
        {
            var result = await api.PostAsync("products", payload);
            if (!result.Success)
            {
                return MapFailure(result);
            }

            await database.UpdateAsync("products", item.LocalId, new Dictionary<string, object?>
            {
                ["server_id"] = Json.Long(result.Data, "id"),
            });
            return PushResult.Success;
        }

        return await PushMasterAsync("products", "products", item);
    }

    private async Task<PushResult> PushTransactionAsync(SyncQueueItem item)
    {
        if (item.Operation == "delete")
        {
            var existingServerId = await database.ResolveServerIdAsync("transactions", item.LocalId);
            if (existingServerId is not null)
            {
                var delete = await api.DeleteAsync($"transactions/{existingServerId}");
                if (!delete.Success && !delete.Offline && delete.StatusCode != 404)
                {
                    return MapFailure(delete);
                }
            }

            return PushResult.Success;
        }

        var payload = await BuildPayloadAsync(item.Payload);
        var result = await api.PostAsync("transactions", payload);
        if (!result.Success)
        {
            return MapFailure(result);
        }

        var serverId = Json.Long(result.Data, "id");
        await database.UpdateAsync("transactions", item.LocalId, new Dictionary<string, object?>
        {
            ["server_id"] = serverId,
            ["invoice_number"] = Json.Str(result.Data, "invoice_number"),
            ["subtotal"] = Json.Dec(result.Data, "subtotal"),
            ["discount"] = Json.Dec(result.Data, "discount"),
            ["tax_amount"] = Json.Dec(result.Data, "tax_amount"),
            ["total"] = Json.Dec(result.Data, "total"),
            ["status"] = Json.Str(result.Data, "status") ?? "completed",
        });

        var items = (await database.QueryAsync<TransactionItem>(
            "SELECT * FROM transaction_items WHERE transaction_id=$id ORDER BY id",
            new { id = item.LocalId })).ToList();

        var serverItems = Json.Array(result.Data, "items");
        for (var index = 0; index < Math.Min(items.Count, serverItems.Count); index++)
        {
            var serverItemId = Json.Long(serverItems[index], "id");
            if (serverItemId is not null)
            {
                await database.UpdateAsync("transaction_items", items[index].Id, new Dictionary<string, object?>
                {
                    ["server_id"] = serverItemId,
                });
            }
        }

        return PushResult.Success;
    }

    private async Task<PushResult> PushParkedAsync(SyncQueueItem item)
    {
        var serverId = await database.ResolveServerIdAsync("parked_transactions", item.LocalId);
        if (item.Operation == "delete")
        {
            if (serverId is not null)
            {
                var delete = await api.DeleteAsync($"parked-transactions/{serverId}");
                if (!delete.Success && !delete.Offline && delete.StatusCode != 404)
                {
                    return MapFailure(delete);
                }
            }

            return PushResult.Success;
        }

        var payload = await BuildPayloadAsync(item.Payload);
        var result = await api.PostAsync("parked-transactions", payload);
        if (!result.Success)
        {
            return MapFailure(result);
        }

        await database.UpdateAsync("parked_transactions", item.LocalId, new Dictionary<string, object?>
        {
            ["server_id"] = Json.Long(result.Data, "id"),
            ["invoice_number"] = Json.Str(result.Data, "invoice_number"),
        });

        return PushResult.Success;
    }

    private async Task<PushResult> PushPurchaseOrderAsync(SyncQueueItem item)
    {
        var serverId = await database.ResolveServerIdAsync("purchase_orders", item.LocalId);

        if (item.Operation == "receive")
        {
            if (serverId is null)
            {
                return PushResult.Failed("Purchase order belum tersinkron. Coba lagi setelah sinkronisasi.");
            }

            var detail = await api.GetAsync($"purchase-orders/{serverId}");
            if (!detail.Success)
            {
                return MapFailure(detail);
            }

            var serverItems = Json.Array(detail.Data, "items");
            var payload = await ParseObjectAsync(item.Payload);
            var requested = payload.TryGetValue("items", out var itemsValue) && itemsValue is List<object?> list ? list : [];
            var serverPayload = new List<object?>();

            foreach (var entry in requested.OfType<Dictionary<string, object?>>())
            {
                var localItemId = entry.TryGetValue("purchase_order_item_id", out var value) ? value?.ToString() : null;
                var productId = entry.TryGetValue("product_id", out var productValue) ? ToLong(productValue) : null;
                long? mapped = null;

                if (!string.IsNullOrWhiteSpace(localItemId) && long.TryParse(localItemId, out var parsedItemId))
                {
                    mapped = await database.ResolveServerIdAsync("purchase_order_items", parsedItemId);
                }

                if (mapped is null && productId is not null)
                {
                    var localProductServerId = await database.ResolveServerIdAsync("products", productId);
                    var match = serverItems.FirstOrDefault(serverItem =>
                        Json.Long(serverItem, "id") is not null &&
                        Json.NestedLong(serverItem, "product") == localProductServerId);
                    mapped = Json.Long(match, "id");
                }

                if (mapped is null)
                {
                    return PushResult.Failed("Item purchase order tidak ditemukan di server.");
                }

                serverPayload.Add(new Dictionary<string, object?>
                {
                    ["purchase_order_item_id"] = mapped,
                    ["quantity"] = entry.TryGetValue("quantity", out var quantity) ? ToLong(quantity) ?? 0 : 0,
                });
            }

            var receive = await api.PostAsync($"purchase-orders/{serverId}/receive", new { items = serverPayload });
            if (!receive.Success)
            {
                return MapFailure(receive);
            }

            await database.UpdateAsync("purchase_orders", item.LocalId, new Dictionary<string, object?>
            {
                ["status"] = Json.Str(receive.Data, "status") ?? "received",
            });
            return PushResult.Success;
        }

        if (item.Operation == "delete")
        {
            if (serverId is not null)
            {
                var delete = await api.DeleteAsync($"purchase-orders/{serverId}");
                if (!delete.Success && !delete.Offline && delete.StatusCode != 404)
                {
                    return MapFailure(delete);
                }
            }

            return PushResult.Success;
        }

        var payloadObject = await BuildPayloadAsync(item.Payload);
        var result = await api.PostAsync("purchase-orders", payloadObject);
        if (!result.Success)
        {
            return MapFailure(result);
        }

        await database.UpdateAsync("purchase_orders", item.LocalId, new Dictionary<string, object?>
        {
            ["server_id"] = Json.Long(result.Data, "id"),
            ["po_number"] = Json.Str(result.Data, "po_number"),
            ["status"] = Json.Str(result.Data, "status") ?? "draft",
            ["subtotal"] = Json.Dec(result.Data, "subtotal"),
            ["total"] = Json.Dec(result.Data, "total"),
        });

        var localItems = (await database.QueryAsync<PurchaseOrderItem>(
            "SELECT * FROM purchase_order_items WHERE purchase_order_id=$id ORDER BY id",
            new { id = item.LocalId })).ToList();
        var responseItems = Json.Array(result.Data, "items");

        foreach (var responseItem in responseItems)
        {
            var productServerId = Json.NestedLong(responseItem, "product");
            var localProductId = productServerId is null
                ? null
                : await database.ScalarAsync<long?>("SELECT id FROM products WHERE server_id=$sid", new { sid = productServerId });
            var localItem = localItems.FirstOrDefault(candidate => candidate.ProductId == localProductId);
            if (localItem is not null && Json.Long(responseItem, "id") is long serverItemId)
            {
                await database.UpdateAsync("purchase_order_items", localItem.Id, new Dictionary<string, object?>
                {
                    ["server_id"] = serverItemId,
                });
            }
        }

        return PushResult.Success;
    }

    private async Task<PushResult> PushStockCountAsync(SyncQueueItem item)
    {
        var serverId = await database.ResolveServerIdAsync("stock_counts", item.LocalId);

        if (item.Operation == "create")
        {
            var payload = await BuildPayloadAsync(item.Payload);
            var result = await api.PostAsync("stock-counts", payload);
            if (!result.Success)
            {
                return MapFailure(result);
            }

            var newServerId = Json.Long(result.Data, "id");
            await database.UpdateAsync("stock_counts", item.LocalId, new Dictionary<string, object?>
            {
                ["server_id"] = newServerId,
                ["count_number"] = Json.Str(result.Data, "count_number"),
                ["status"] = Json.Str(result.Data, "status") ?? "draft",
            });

            var localItems = (await database.QueryAsync<StockCountItem>(
                "SELECT * FROM stock_count_items WHERE stock_count_id=$id ORDER BY id",
                new { id = item.LocalId })).ToList();

            foreach (var responseItem in Json.Array(result.Data, "items"))
            {
                var productServerId = Json.NestedLong(responseItem, "product");
                var localProductId = productServerId is null
                    ? null
                    : await database.ScalarAsync<long?>("SELECT id FROM products WHERE server_id=$sid", new { sid = productServerId });
                var localItem = localItems.FirstOrDefault(candidate => candidate.ProductId == localProductId);
                if (localItem is not null && Json.Long(responseItem, "id") is long serverItemId)
                {
                    await database.UpdateAsync("stock_count_items", localItem.Id, new Dictionary<string, object?>
                    {
                        ["server_id"] = serverItemId,
                    });
                }
            }

            return PushResult.Success;
        }

        if (serverId is null)
        {
            return PushResult.Failed("Stock opname belum tersinkron. Coba lagi setelah sinkronisasi.");
        }

        if (item.Operation == "record")
        {
            var detail = await api.GetAsync($"stock-counts/{serverId}");
            if (!detail.Success)
            {
                return MapFailure(detail);
            }

            var requestItems = new List<object?>();
            foreach (var localItem in await database.QueryAsync<StockCountItem>(
                         "SELECT * FROM stock_count_items WHERE stock_count_id=$id AND counted_quantity IS NOT NULL",
                         new { id = item.LocalId }))
            {
                var itemServerId = localItem.ServerId
                    ?? Json.Long(Json.Array(detail.Data, "items")
                        .FirstOrDefault(serverItem => Json.NestedLong(serverItem, "product") is long productServer &&
                            productServer == localItem.ProductId), "id");

                if (itemServerId is null)
                {
                    continue;
                }

                requestItems.Add(new Dictionary<string, object?>
                {
                    ["stock_count_item_id"] = itemServerId,
                    ["counted_quantity"] = (int)(localItem.CountedQuantity ?? 0),
                    ["notes"] = localItem.Notes,
                });
            }

            var record = await api.PostAsync($"stock-counts/{serverId}/record", new { items = requestItems });
            if (!record.Success)
            {
                return MapFailure(record);
            }

            await database.UpdateAsync("stock_counts", item.LocalId, new Dictionary<string, object?>
            {
                ["status"] = Json.Str(record.Data, "status") ?? "counting",
            });
            return PushResult.Success;
        }

        var action = item.Operation switch
        {
            "start" => "start",
            "approve" => "approve",
            "post" => "post",
            _ => null,
        };

        if (action is null)
        {
            return PushResult.Failed($"Operasi stock opname {item.Operation} tidak didukung.");
        }

        var actionResult = await api.PostAsync($"stock-counts/{serverId}/{action}", new { });
        if (!actionResult.Success)
        {
            return MapFailure(actionResult);
        }

        await database.UpdateAsync("stock_counts", item.LocalId, new Dictionary<string, object?>
        {
            ["status"] = Json.Str(actionResult.Data, "status") ?? action,
        });

        return PushResult.Success;
    }

    private async Task<PushResult> PushRegisterSessionAsync(SyncQueueItem item)
    {
        if (item.Operation == "open")
        {
            var payload = await BuildPayloadAsync(item.Payload);
            var result = await api.PostAsync("register-sessions/open", payload);
            if (!result.Success)
            {
                return MapFailure(result);
            }

            await database.UpdateAsync("register_sessions", item.LocalId, new Dictionary<string, object?>
            {
                ["server_id"] = Json.Long(result.Data, "id"),
                ["status"] = "open",
                ["opened_at"] = Json.Date(result.Data, "opened_at"),
            });
            return PushResult.Success;
        }

        var serverId = await database.ResolveServerIdAsync("register_sessions", item.LocalId);
        if (serverId is null)
        {
            return PushResult.Failed("Sesi kas belum tersinkron.");
        }

        var payloadClose = await ParseObjectAsync(item.Payload);
        payloadClose.Remove("server_id");
        var close = await api.PostAsync($"register-sessions/{serverId}/close", payloadClose);
        if (!close.Success)
        {
            return MapFailure(close);
        }

        await database.UpdateAsync("register_sessions", item.LocalId, new Dictionary<string, object?>
        {
            ["status"] = "closed",
            ["expected_cash"] = Json.Dec(close.Data, "expected_cash"),
            ["over_short"] = Json.Dec(close.Data, "over_short"),
            ["closed_at"] = Json.Date(close.Data, "closed_at"),
        });
        return PushResult.Success;
    }

    private async Task<PushResult> PushInventoryAsync(SyncQueueItem item)
    {
        var payload = await BuildPayloadAsync(item.Payload);
        var result = await api.PostAsync("inventory-histories", payload);
        return result.Success ? PushResult.Success : MapFailure(result);
    }

    private async Task<PushResult> PushSettingAsync(SyncQueueItem item)
    {
        var payload = await BuildPayloadAsync(item.Payload);
        var result = await api.PostAsync("settings", payload);
        return result.Success ? PushResult.Success : MapFailure(result);
    }

    private async Task<object?> BuildPayloadAsync(string json) =>
        await ResolveElementAsync("", JsonDocument.Parse(json).RootElement);

    private async Task<Dictionary<string, object?>> ParseObjectAsync(string json)
    {
        var resolved = await BuildPayloadAsync(json);
        return resolved as Dictionary<string, object?> ?? [];
    }

    private async Task<object?> ResolveElementAsync(string key, JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
            {
                var dictionary = new Dictionary<string, object?>();
                foreach (var property in element.EnumerateObject())
                {
                    dictionary[property.Name] = await ResolveElementAsync(property.Name, property.Value);
                }

                return dictionary;
            }
            case JsonValueKind.Array:
            {
                var list = new List<object?>();
                foreach (var item in element.EnumerateArray())
                {
                    list.Add(await ResolveElementAsync(key == "items" ? "" : key, item));
                }

                return list;
            }
            case JsonValueKind.Number:
            {
                var numeric = element.TryGetInt64(out var integer) ? integer : (object)element.GetDecimal();
                if (key == "product_ids" && numeric is long productLocalId)
                {
                    var productServerId = await database.ResolveServerIdAsync("products", productLocalId);
                    return productServerId ?? throw new InvalidOperationException("Produk belum tersinkron ke server.");
                }

                if (key != "server_id" && IdTables.TryGetValue(key, out var table))
                {
                    if (numeric is long localId)
                    {
                        if (localId == 0)
                        {
                            return null;
                        }

                        var serverId = await database.ResolveServerIdAsync(table, localId);
                        return serverId ?? throw new InvalidOperationException($"Data terkait ({key}) belum tersinkron ke server.");
                    }
                }

                return numeric;
            }
            case JsonValueKind.String:
                return element.GetString();
            case JsonValueKind.True:
                return true;
            case JsonValueKind.False:
                return false;
            default:
                return null;
        }
    }

    private static PushResult MapFailure(ApiResult result) =>
        result.Offline ? PushResult.OfflineResult : PushResult.Failed(result.Message);

    private static void CopyIfPresent(JsonElement data, Dictionary<string, object?> target, string property)
    {
        var value = Json.Str(data, property);
        if (!string.IsNullOrWhiteSpace(value))
        {
            target[property] = value;
        }
    }

    private static long? ToLong(object? value) => value switch
    {
        null => null,
        long number => number,
        int number => number,
        decimal number => (long)number,
        JsonElement element => Json.Long(element, "id"),
        _ => long.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed) ? parsed : null,
    };

    // ── Pull ──────────────────────────────────────────────────────────────────────────────

    private async Task PullAsync(bool full)
    {
        await PullSimpleAsync("categories", "categories", "category", row => Task.FromResult<Dictionary<string, object?>>(new()
        {
            ["server_id"] = Json.Long(row, "id"),
            ["name"] = Json.Str(row, "name") ?? "",
            ["slug"] = Json.Str(row, "slug"),
            ["description"] = Json.Str(row, "description"),
            ["is_active"] = Json.Bool(row, "is_active", true),
            ["updated_at"] = Json.Date(row, "updated_at"),
        }));

        await PullSimpleAsync("unit-quantities", "unit_quantities", "unit", row => Task.FromResult<Dictionary<string, object?>>(new()
        {
            ["server_id"] = Json.Long(row, "id"),
            ["name"] = Json.Str(row, "name") ?? "",
            ["symbol"] = Json.Str(row, "symbol"),
            ["description"] = Json.Str(row, "description"),
        }));

        await PullSimpleAsync("taxes", "taxes", "tax", row => Task.FromResult<Dictionary<string, object?>>(new()
        {
            ["server_id"] = Json.Long(row, "id"),
            ["name"] = Json.Str(row, "name") ?? "",
            ["rate"] = Json.Dec(row, "rate"),
            ["is_active"] = Json.Bool(row, "is_active", true),
        }));

        await PullSimpleAsync("suppliers", "suppliers", "supplier", row => Task.FromResult<Dictionary<string, object?>>(new()
        {
            ["server_id"] = Json.Long(row, "id"),
            ["code"] = Json.Str(row, "code"),
            ["name"] = Json.Str(row, "name") ?? "",
            ["email"] = Json.Str(row, "email"),
            ["phone"] = Json.Str(row, "phone"),
            ["address"] = Json.Str(row, "address"),
            ["contact_person"] = Json.Str(row, "contact_person"),
            ["is_active"] = Json.Bool(row, "is_active", true),
        }));

        await PullSimpleAsync("customers", "customers", "customer", row => Task.FromResult<Dictionary<string, object?>>(new()
        {
            ["server_id"] = Json.Long(row, "id"),
            ["name"] = Json.Str(row, "name") ?? "",
            ["email"] = Json.Str(row, "email"),
            ["phone"] = Json.Str(row, "phone"),
            ["address"] = Json.Str(row, "address"),
            ["credit_limit"] = Json.Dec(row, "credit_limit"),
            ["is_active"] = Json.Bool(row, "is_active", true),
        }));

        await PullSimpleAsync("branches", "branches", "branch", row => Task.FromResult<Dictionary<string, object?>>(new()
        {
            ["server_id"] = Json.Long(row, "id"),
            ["code"] = Json.Str(row, "code") ?? "",
            ["name"] = Json.Str(row, "name") ?? "",
            ["address"] = Json.Str(row, "address"),
            ["phone"] = Json.Str(row, "phone"),
            ["active"] = Json.Bool(row, "active", true),
        }));

        await PullSimpleAsync("warehouses", "warehouses", "warehouse", async row => new Dictionary<string, object?>
        {
            ["server_id"] = Json.Long(row, "id"),
            ["branch_id"] = await LocalRefAsync("branches", Json.NestedLong(row, "branch")),
            ["code"] = Json.Str(row, "code") ?? "",
            ["name"] = Json.Str(row, "name") ?? "",
            ["phone"] = Json.Str(row, "phone"),
            ["address"] = Json.Str(row, "address"),
            ["active"] = Json.Bool(row, "active", true),
        });

        await PullSimpleAsync("users", "users", "user", row => Task.FromResult<Dictionary<string, object?>>(new()
        {
            ["server_id"] = Json.Long(row, "id"),
            ["name"] = Json.Str(row, "name") ?? "",
            ["email"] = Json.Str(row, "email"),
            ["role"] = Json.Str(row, "role"),
            ["phone"] = Json.Str(row, "phone"),
            ["is_active"] = Json.Bool(row, "is_active", true),
        }));

        await PullSimpleAsync("registers", "registers", "register", row => Task.FromResult<Dictionary<string, object?>>(new()
        {
            ["server_id"] = Json.Long(row, "id"),
            ["name"] = Json.Str(row, "name") ?? "",
            ["code"] = Json.Str(row, "code") ?? "",
            ["description"] = Json.Str(row, "description"),
            ["is_active"] = Json.Bool(row, "is_active", true),
        }));

        await PullSimpleAsync("products", "products", "product", async row => new Dictionary<string, object?>
        {
            ["server_id"] = Json.Long(row, "id"),
            ["name"] = Json.Str(row, "name") ?? "",
            ["sku"] = Json.Str(row, "sku") ?? "",
            ["barcode"] = Json.Str(row, "barcode"),
            ["category_id"] = await LocalRefAsync("categories", Json.NestedLong(row, "category")),
            ["category_text"] = Json.Str(row, "category_text"),
            ["unit_quantity_id"] = await LocalRefAsync("unit_quantities", Json.NestedLong(row, "unit_quantity")),
            ["tax_id"] = await LocalRefAsync("taxes", Json.NestedLong(row, "tax")),
            ["supplier_id"] = await LocalRefAsync("suppliers", Json.NestedLong(row, "supplier")),
            ["type"] = Json.Str(row, "type") ?? "finished_goods",
            ["cost_price"] = Json.Dec(row, "cost_price") ?? Json.Dec(row, "cost") ?? 0,
            ["selling_price"] = Json.Dec(row, "selling_price") ?? Json.Dec(row, "price") ?? 0,
            ["price"] = Json.Dec(row, "price") ?? 0,
            ["stock"] = Json.Dec(row, "stock") ?? 0,
            ["min_stock"] = Json.Dec(row, "min_stock") ?? 5,
            ["is_active"] = Json.Bool(row, "is_active", true),
            ["description"] = Json.Str(row, "description"),
            ["image"] = Json.Str(row, "image") ?? Json.Str(row, "photo"),
            ["updated_at"] = Json.Date(row, "updated_at"),
        }, maxPages: full ? 50 : 20);

        await PullSimpleAsync("register-sessions", "register_sessions", "register_session", async row => new Dictionary<string, object?>
        {
            ["server_id"] = Json.Long(row, "id"),
            ["register_id"] = await LocalRefAsync("registers", Json.NestedLong(row, "register")),
            ["user_id"] = await LocalRefAsync("users", Json.NestedLong(row, "user")),
            ["opening_float"] = Json.Dec(row, "opening_float"),
            ["expected_cash"] = Json.Dec(row, "expected_cash"),
            ["actual_cash"] = Json.Dec(row, "actual_cash"),
            ["over_short"] = Json.Dec(row, "over_short"),
            ["status"] = Json.Str(row, "status") ?? "open",
            ["opened_at"] = Json.Date(row, "opened_at"),
            ["closed_at"] = Json.Date(row, "closed_at"),
            ["notes"] = Json.Str(row, "notes"),
        }, maxPages: 3);

        await PullTransactionsAsync(full);
        await PullParkedAsync();
        await PullPurchaseOrdersAsync(full);
        await PullStockCountsAsync(full);
        await PullSimpleAsync("supplier-invoices", "supplier_invoices", "supplier_invoice", async row => new Dictionary<string, object?>
        {
            ["server_id"] = Json.Long(row, "id"),
            ["supplier_id"] = await LocalRefAsync("suppliers", Json.NestedLong(row, "supplier")),
            ["purchase_order_id"] = null,
            ["invoice_number"] = Json.Str(row, "invoice_number") ?? "",
            ["invoice_date"] = Json.Date(row, "invoice_date"),
            ["due_date"] = Json.Date(row, "due_date"),
            ["amount"] = Json.Dec(row, "amount"),
            ["status"] = Json.Str(row, "status") ?? "pending",
            ["notes"] = Json.Str(row, "notes"),
        }, maxPages: 5);

        await PullSimpleAsync("inventory-histories", "inventory_histories", "", async row => new Dictionary<string, object?>
        {
            ["server_id"] = Json.Long(row, "id"),
            ["product_id"] = await LocalRefAsync("products", Json.NestedLong(row, "product")),
            ["user_id"] = await LocalRefAsync("users", Json.NestedLong(row, "user")),
            ["type"] = Json.Str(row, "type") ?? "in",
            ["quantity"] = Json.Dec(row, "quantity"),
            ["stock_before"] = Json.Dec(row, "stock_before"),
            ["stock_after"] = Json.Dec(row, "stock_after"),
            ["reason"] = Json.Str(row, "reason"),
            ["created_at"] = Json.Date(row, "created_at"),
        }, maxPages: 5);

        await PullSimpleAsync("activity-logs", "activity_logs", "", async row => new Dictionary<string, object?>
        {
            ["server_id"] = Json.Long(row, "id"),
            ["user_id"] = await LocalRefAsync("users", Json.NestedLong(row, "user")),
            ["event"] = Json.Str(row, "event") ?? "",
            ["description"] = Json.Str(row, "description"),
            ["subject_type"] = Json.Str(row, "subject_type"),
            ["subject_id"] = Json.Long(row, "subject_id"),
            ["created_at"] = Json.Date(row, "created_at"),
        }, maxPages: 3);

        await PullSettingsAsync();
    }

    private async Task PullSimpleAsync(
        string path,
        string table,
        string entity,
        Func<JsonElement, Task<Dictionary<string, object?>>> mapper,
        int maxPages = 30)
    {
        var rows = await api.GetAllPagesAsync(path, maxPages);
        foreach (var row in rows)
        {
            var values = await mapper(row);
            if (values.Count == 0 || values["server_id"] is null)
            {
                continue;
            }

            if (entity.Length > 0 && await HasPendingAsync(entity, table, values["server_id"]))
            {
                continue;
            }

            await database.UpsertByServerIdAsync(table, values);
        }
    }

    private async Task PullTransactionsAsync(bool full)
    {
        var rows = await api.GetAllPagesAsync("transactions", full ? 30 : 8);
        var cutoff = DateTime.Now.AddDays(-180);

        foreach (var row in rows)
        {
            var createdAt = Json.Date(row, "created_at");
            if (createdAt is not null && createdAt < cutoff)
            {
                continue;
            }

            if (await HasPendingAsync("transaction", "transactions", Json.Long(row, "id")))
            {
                continue;
            }

            var payments = Json.Array(row, "payments");
            var paid = payments.Count > 0 ? payments.Sum(payment => Json.Dec(payment, "amount") ?? 0) : (decimal?)null;
            var method = payments.Count > 0 ? Json.Str(payments[0], "method")?.ToUpperInvariant() : null;

            var values = new Dictionary<string, object?>
            {
                ["server_id"] = Json.Long(row, "id"),
                ["invoice_number"] = Json.Str(row, "invoice_number") ?? "",
                ["type"] = Json.Str(row, "type") ?? "sell",
                ["customer_id"] = await LocalRefAsync("customers", Json.NestedLong(row, "customer")),
                ["supplier_id"] = await LocalRefAsync("suppliers", Json.NestedLong(row, "supplier")),
                ["user_id"] = await LocalRefAsync("users", Json.NestedLong(row, "user")),
                ["subtotal"] = Json.Dec(row, "subtotal"),
                ["discount"] = Json.Dec(row, "discount"),
                ["tax_amount"] = Json.Dec(row, "tax_amount"),
                ["total"] = Json.Dec(row, "total"),
                ["status"] = Json.Str(row, "status") ?? "completed",
                ["notes"] = Json.Str(row, "notes"),
                ["created_at"] = createdAt,
                ["updated_at"] = Json.Date(row, "updated_at"),
            };

            if (paid is not null)
            {
                values["paid_amount"] = paid;
                values["change_amount"] = Math.Max(0, paid.Value - (Json.Dec(row, "total") ?? 0));
            }

            var localId = await database.UpsertByServerIdAsync(
                "transactions",
                values,
                ["paid_amount", "change_amount"]);

            if (!string.IsNullOrWhiteSpace(method))
            {
                await database.ExecuteAsync(
                    "UPDATE transactions SET payment_method=COALESCE(payment_method,$method) WHERE id=$id",
                    new { method, id = localId });
            }

            foreach (var item in Json.Array(row, "items"))
            {
                var itemValues = new Dictionary<string, object?>
                {
                    ["server_id"] = Json.Long(item, "id"),
                    ["transaction_id"] = localId,
                    ["product_id"] = await LocalRefAsync("products", Json.NestedLong(item, "product")),
                    ["product_name"] = Json.NestedStr(item, "product", "name"),
                    ["sku"] = Json.NestedStr(item, "product", "sku"),
                    ["quantity"] = Json.Dec(item, "quantity"),
                    ["unit_price"] = Json.Dec(item, "unit_price"),
                    ["discount"] = Json.Dec(item, "discount"),
                    ["subtotal"] = Json.Dec(item, "subtotal"),
                };

                if (itemValues["server_id"] is not null)
                {
                    await database.UpsertByServerIdAsync("transaction_items", itemValues);
                }
            }
        }
    }

    private async Task PullParkedAsync()
    {
        var rows = await api.GetAllPagesAsync("parked-transactions", 5);
        foreach (var row in rows)
        {
            var items = new List<Dictionary<string, object?>>();
            foreach (var item in Json.Array(row, "items"))
            {
                items.Add(new Dictionary<string, object?>
                {
                    ["product_id"] = await LocalRefAsync("products", Json.Long(item, "product_id")),
                    ["name"] = Json.Str(item, "name") ?? Json.Str(item, "product_name"),
                    ["sku"] = Json.Str(item, "sku"),
                    ["quantity"] = Json.Dec(item, "quantity") ?? Json.Dec(item, "qty") ?? 0,
                    ["unit_price"] = Json.Dec(item, "unit_price") ?? Json.Dec(item, "price") ?? 0,
                    ["discount"] = Json.Dec(item, "discount") ?? 0,
                    ["subtotal"] = Json.Dec(item, "subtotal") ?? 0,
                });
            }

            await database.UpsertByServerIdAsync("parked_transactions", new Dictionary<string, object?>
            {
                ["server_id"] = Json.Long(row, "id"),
                ["invoice_number"] = Json.Str(row, "invoice_number"),
                ["customer_id"] = await LocalRefAsync("customers", Json.NestedLong(row, "customer")),
                ["items_json"] = JsonSerializer.Serialize(items, PayloadJson),
                ["subtotal"] = Json.Dec(row, "subtotal"),
                ["discount"] = Json.Dec(row, "discount"),
                ["tax_amount"] = Json.Dec(row, "tax_amount"),
                ["total"] = Json.Dec(row, "total"),
                ["notes"] = Json.Str(row, "notes"),
                ["created_at"] = Json.Date(row, "created_at"),
            });
        }
    }

    private async Task PullPurchaseOrdersAsync(bool full)
    {
        var rows = await api.GetAllPagesAsync("purchase-orders", full ? 5 : 2);
        foreach (var row in rows)
        {
            var serverId = Json.Long(row, "id");
            if (serverId is null)
            {
                continue;
            }

            if (await HasPendingAsync("purchase_order", "purchase_orders", serverId))
            {
                continue;
            }

            var localId = await database.UpsertByServerIdAsync("purchase_orders", new Dictionary<string, object?>
            {
                ["server_id"] = serverId,
                ["po_number"] = Json.Str(row, "po_number") ?? "",
                ["supplier_id"] = await LocalRefAsync("suppliers", Json.NestedLong(row, "supplier")),
                ["status"] = Json.Str(row, "status") ?? "draft",
                ["expected_date"] = Json.Date(row, "expected_date"),
                ["subtotal"] = Json.Dec(row, "subtotal"),
                ["discount"] = Json.Dec(row, "discount"),
                ["tax_amount"] = Json.Dec(row, "tax_amount"),
                ["total"] = Json.Dec(row, "total"),
                ["notes"] = Json.Str(row, "notes"),
                ["created_at"] = Json.Date(row, "created_at"),
            });

            var detail = await api.GetAsync($"purchase-orders/{serverId}");
            if (!detail.Success)
            {
                continue;
            }

            foreach (var item in Json.Array(detail.Data, "items"))
            {
                if (Json.Long(item, "id") is not long itemServerId)
                {
                    continue;
                }

                await database.UpsertByServerIdAsync("purchase_order_items", new Dictionary<string, object?>
                {
                    ["server_id"] = itemServerId,
                    ["purchase_order_id"] = localId,
                    ["product_id"] = await LocalRefAsync("products", Json.NestedLong(item, "product")),
                    ["quantity"] = Json.Dec(item, "quantity"),
                    ["received_quantity"] = Json.Dec(item, "received_quantity"),
                    ["unit_cost"] = Json.Dec(item, "unit_cost"),
                    ["discount"] = Json.Dec(item, "discount"),
                    ["subtotal"] = Json.Dec(item, "subtotal"),
                });
            }
        }
    }

    private async Task PullStockCountsAsync(bool full)
    {
        var rows = await api.GetAllPagesAsync("stock-counts", full ? 5 : 2);
        foreach (var row in rows)
        {
            var serverId = Json.Long(row, "id");
            if (serverId is null || await HasPendingAsync("stock_count", "stock_counts", serverId))
            {
                continue;
            }

            var localId = await database.UpsertByServerIdAsync("stock_counts", new Dictionary<string, object?>
            {
                ["server_id"] = serverId,
                ["count_number"] = Json.Str(row, "count_number") ?? "",
                ["user_id"] = await LocalRefAsync("users", Json.NestedLong(row, "user")),
                ["status"] = Json.Str(row, "status") ?? "draft",
                ["is_blind"] = Json.Bool(row, "is_blind"),
                ["counted_at"] = Json.Date(row, "counted_at"),
                ["approved_at"] = Json.Date(row, "approved_at"),
                ["posted_at"] = Json.Date(row, "posted_at"),
                ["notes"] = Json.Str(row, "notes"),
                ["created_at"] = Json.Date(row, "created_at"),
            });

            var detail = await api.GetAsync($"stock-counts/{serverId}");
            if (!detail.Success)
            {
                continue;
            }

            foreach (var item in Json.Array(detail.Data, "items"))
            {
                if (Json.Long(item, "id") is not long itemServerId)
                {
                    continue;
                }

                await database.UpsertByServerIdAsync("stock_count_items", new Dictionary<string, object?>
                {
                    ["server_id"] = itemServerId,
                    ["stock_count_id"] = localId,
                    ["product_id"] = await LocalRefAsync("products", Json.NestedLong(item, "product")),
                    ["system_quantity"] = Json.Dec(item, "system_quantity"),
                    ["counted_quantity"] = Json.Dec(item, "counted_quantity"),
                    ["variance"] = Json.Dec(item, "variance"),
                    ["notes"] = Json.Str(item, "notes"),
                });
            }
        }
    }

    private async Task PullSettingsAsync()
    {
        var pendingKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var queued in await database.GetQueueAsync())
        {
            if (queued.Entity != "setting")
            {
                continue;
            }

            try
            {
                var payload = JsonDocument.Parse(queued.Payload).RootElement;
                if (Json.Str(payload, "key") is { } key)
                {
                    pendingKeys.Add(key);
                }
            }
            catch (JsonException)
            {
                // Ignore malformed queued payloads.
            }
        }

        foreach (var row in await api.GetAllPagesAsync("settings", 4))
        {
            var key = Json.Str(row, "key");
            if (string.IsNullOrWhiteSpace(key) || pendingKeys.Contains(key))
            {
                continue;
            }

            await database.SetSettingAsync(new SettingItem
            {
                Key = key,
                Group = Json.Str(row, "group") ?? "general",
                Value = Json.Str(row, "value"),
                Type = Json.Str(row, "type") ?? "string",
                Label = Json.Str(row, "label"),
                IsPublic = Json.Bool(row, "is_public"),
            });
        }
    }

    private async Task<long?> LocalRefAsync(string table, long? serverId)
    {
        if (serverId is null)
        {
            return null;
        }

        return await database.ScalarAsync<long?>($"SELECT id FROM {table} WHERE server_id=$serverId", new { serverId });
    }

    private async Task<bool> HasPendingAsync(string entity, string table, object? serverId)
    {
        if (serverId is null)
        {
            return false;
        }

        var localId = await database.ScalarAsync<long?>($"SELECT id FROM {table} WHERE server_id=$sid", new { sid = serverId });
        if (localId is null)
        {
            return false;
        }

        var count = await database.ScalarAsync<int>(
            "SELECT COUNT(*) FROM sync_queue WHERE entity=$entity AND local_id=$localId",
            new { entity, localId });
        return count > 0;
    }
}

/// <summary>Small JSON helpers shared by the sync engine.</summary>
internal static class Json
{
    public static JsonElement? Prop(JsonElement element, string name) =>
        element.ValueKind == JsonValueKind.Object && element.TryGetProperty(name, out var value) ? value : null;

    public static string? Str(JsonElement element, string name) => Prop(element, name) switch
    {
        { ValueKind: JsonValueKind.String } value => value.GetString(),
        { ValueKind: JsonValueKind.Number } value => value.GetRawText(),
        { ValueKind: JsonValueKind.True } => "true",
        { ValueKind: JsonValueKind.False } => "false",
        _ => null,
    };

    public static long? Long(JsonElement element, string name)
    {
        var value = Prop(element, name);
        if (value is null)
        {
            return null;
        }

        return value.Value.ValueKind switch
        {
            JsonValueKind.Number when value.Value.TryGetInt64(out var number) => number,
            JsonValueKind.String when long.TryParse(value.Value.GetString(), out var parsed) => parsed,
            _ => null,
        };
    }

    public static decimal? Dec(JsonElement element, string name)
    {
        var value = Prop(element, name);
        if (value is null)
        {
            return null;
        }

        return value.Value.ValueKind switch
        {
            JsonValueKind.Number when value.Value.TryGetDecimal(out var number) => number,
            JsonValueKind.String when decimal.TryParse(value.Value.GetString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed) => parsed,
            _ => null,
        };
    }

    public static bool Bool(JsonElement element, string name, bool fallback = false)
    {
        var value = Prop(element, name);
        return value?.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            JsonValueKind.Number => value.Value.GetInt64() != 0,
            _ => fallback,
        };
    }

    public static DateTime? Date(JsonElement element, string name)
    {
        var text = Str(element, name);
        return DateTime.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var parsed)
            ? parsed
            : null;
    }

    public static List<JsonElement> Array(JsonElement element, string name)
    {
        var value = Prop(element, name);
        return value is { ValueKind: JsonValueKind.Array }
            ? value.Value.EnumerateArray().Select(item => item.Clone()).ToList()
            : [];
    }

    public static long? NestedLong(JsonElement element, string objectName)
    {
        var nested = Prop(element, objectName);
        return nested is null ? null : Long(nested.Value, "id");
    }

    public static string? NestedStr(JsonElement element, string objectName, string property)
    {
        var nested = Prop(element, objectName);
        return nested is null ? null : Str(nested.Value, property);
    }
}
