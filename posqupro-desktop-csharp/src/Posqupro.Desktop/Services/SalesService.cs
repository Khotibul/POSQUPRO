using System.Globalization;
using System.Text.Json;
using Posqupro.Desktop.Data;
using Posqupro.Desktop.Models;

namespace Posqupro.Desktop.Services;

public sealed class SaleLineInput
{
    public long ProductId { get; set; }
    public string ProductName { get; set; } = "";
    public string? Sku { get; set; }
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal Discount { get; set; }
}

public sealed class SaleRequest
{
    public List<SaleLineInput> Lines { get; set; } = [];
    public string Type { get; set; } = "sell";
    public long? CustomerId { get; set; }
    public decimal Discount { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal PaidAmount { get; set; }
    public string PaymentMethod { get; set; } = "cash";
    public string? Notes { get; set; }
}

public sealed class SaleResult
{
    public long TransactionId { get; init; }
    public string InvoiceNumber { get; init; } = "";
    public decimal Subtotal { get; init; }
    public decimal Discount { get; init; }
    public decimal Tax { get; init; }
    public decimal Total { get; init; }
    public decimal Paid { get; init; }
    public decimal Change { get; init; }
    public string PaymentMethod { get; init; } = "CASH";
    public string? CustomerName { get; init; }
    public DateTime CreatedAt { get; init; }
    public List<SaleLineInput> Lines { get; init; } = [];
}

/// <summary>Offline-first sales, parking, stock adjustment and register operations.</summary>
public sealed class SalesService(LocalDatabase database, AppSettingsStore settings)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    public async Task<(bool Success, string Message, SaleResult? Result)> CheckoutAsync(SaleRequest request)
    {
        if (request.Lines.Count == 0)
        {
            return (false, "Keranjang masih kosong.", null);
        }

        var subtotal = request.Lines.Sum(line => line.Quantity * line.UnitPrice - line.Discount);
        var discount = Math.Min(Math.Max(0, request.Discount), subtotal);
        var tax = Math.Max(0, request.TaxAmount);
        var total = subtotal - discount + tax;
        var paid = request.PaidAmount < total ? total : request.PaidAmount;
        var change = Math.Max(0, paid - total);
        var method = request.PaymentMethod.ToUpperInvariant();

        foreach (var line in request.Lines)
        {
            var product = await database.QuerySingleAsync<Product>(
                "SELECT id, name, stock, type FROM products WHERE id=$id",
                new { id = line.ProductId });

            if (product is null)
            {
                return (false, $"Produk {line.ProductName} tidak ditemukan.", null);
            }

            if (request.Type == "sell" &&
                !string.Equals(product.Type, "service", StringComparison.OrdinalIgnoreCase) &&
                product.Stock < line.Quantity)
            {
                return (false, $"Stok {product.Name} tidak cukup. Tersedia: {product.Stock:0.##}.", null);
            }
        }

        var invoiceNumber = await database.NextInvoiceNumberAsync();
        var createdAt = DateTime.Now;
        var customerName = request.CustomerId is null
            ? null
            : await database.ScalarAsync<string>("SELECT name FROM customers WHERE id=$id", new { id = request.CustomerId });

        var transactionId = await database.InsertAsync("transactions", new Dictionary<string, object?>
        {
            ["invoice_number"] = invoiceNumber,
            ["type"] = request.Type,
            ["customer_id"] = request.CustomerId,
            ["user_id"] = settings.Value.UserId,
            ["subtotal"] = subtotal,
            ["discount"] = discount,
            ["tax_amount"] = tax,
            ["total"] = total,
            ["paid_amount"] = paid,
            ["change_amount"] = change,
            ["status"] = "completed",
            ["notes"] = request.Notes,
            ["payment_method"] = method,
            ["created_at"] = createdAt,
            ["updated_at"] = createdAt,
        });

        foreach (var line in request.Lines)
        {
            var lineSubtotal = line.Quantity * line.UnitPrice - line.Discount;
            await database.InsertAsync("transaction_items", new Dictionary<string, object?>
            {
                ["transaction_id"] = transactionId,
                ["product_id"] = line.ProductId,
                ["product_name"] = line.ProductName,
                ["sku"] = line.Sku,
                ["quantity"] = line.Quantity,
                ["unit_price"] = line.UnitPrice,
                ["discount"] = line.Discount,
                ["subtotal"] = lineSubtotal,
            });

            if (request.Type == "sell")
            {
                await database.ExecuteAsync(
                    "UPDATE products SET stock = stock - $qty WHERE id=$id",
                    new { qty = line.Quantity, id = line.ProductId });
            }
            else if (request.Type == "buy")
            {
                await database.ExecuteAsync(
                    "UPDATE products SET stock = stock + $qty WHERE id=$id",
                    new { qty = line.Quantity, id = line.ProductId });
            }
        }

        await database.InsertAsync("payments", new Dictionary<string, object?>
        {
            ["transaction_id"] = transactionId,
            ["method"] = method,
            ["amount"] = paid,
            ["reference_no"] = null,
            ["created_at"] = createdAt,
        });

        await database.EnqueueAsync("transaction", "create", transactionId, new
        {
            type = request.Type,
            customer_id = request.CustomerId,
            discount,
            tax_amount = tax,
            notes = request.Notes,
            paid_amount = paid,
            items = request.Lines.Select(line => new
            {
                product_id = line.ProductId,
                quantity = (int)line.Quantity,
                unit_price = line.UnitPrice,
                discount = line.Discount,
            }),
            payment = new { method = request.PaymentMethod.ToLowerInvariant(), amount = paid },
        });

        return (true, "Transaksi berhasil disimpan.", new SaleResult
        {
            TransactionId = transactionId,
            InvoiceNumber = invoiceNumber,
            Subtotal = subtotal,
            Discount = discount,
            Tax = tax,
            Total = total,
            Paid = paid,
            Change = change,
            PaymentMethod = method,
            CustomerName = customerName,
            CreatedAt = createdAt,
            Lines = request.Lines,
        });
    }

    public async Task<(bool Success, string Message)> ParkAsync(SaleRequest request)
    {
        if (request.Lines.Count == 0)
        {
            return (false, "Keranjang masih kosong.");
        }

        var subtotal = request.Lines.Sum(line => line.Quantity * line.UnitPrice - line.Discount);
        var total = subtotal - request.Discount + request.TaxAmount;
        var items = request.Lines.Select(line => new
        {
            product_id = line.ProductId,
            name = line.ProductName,
            sku = line.Sku,
            quantity = line.Quantity,
            unit_price = line.UnitPrice,
            discount = line.Discount,
            subtotal = line.Quantity * line.UnitPrice - line.Discount,
        }).ToList();

        var id = await database.InsertAsync("parked_transactions", new Dictionary<string, object?>
        {
            ["invoice_number"] = $"PARK-{DateTime.Now:yyyyMMddHHmmss}",
            ["customer_id"] = request.CustomerId,
            ["items_json"] = JsonSerializer.Serialize(items, JsonOptions),
            ["subtotal"] = subtotal,
            ["discount"] = request.Discount,
            ["tax_amount"] = request.TaxAmount,
            ["total"] = total,
            ["notes"] = request.Notes,
            ["user_id"] = settings.Value.UserId,
            ["created_at"] = DateTime.Now,
        });

        await database.EnqueueAsync("parked_transaction", "create", id, new
        {
            customer_id = request.CustomerId,
            items = request.Lines.Select(line => new
            {
                product_id = line.ProductId,
                quantity = (int)line.Quantity,
                unit_price = line.UnitPrice,
                discount = line.Discount,
            }),
            discount = request.Discount,
            tax_amount = request.TaxAmount,
            notes = request.Notes,
        });

        return (true, "Transaksi diparkir.");
    }

    public async Task<List<SaleLineInput>> RestoreParkedAsync(long parkedId)
    {
        var parked = await database.QuerySingleAsync<ParkedTransaction>(
            "SELECT * FROM parked_transactions WHERE id=$id",
            new { id = parkedId });

        if (parked is null)
        {
            return [];
        }

        var lines = DeserializeParkedItems(parked.ItemsJson);

        await database.DeleteAsync("parked_transactions", parkedId);
        if (parked.ServerId is not null)
        {
            await database.EnqueueAsync("parked_transaction", "delete", parkedId, new { server_id = parked.ServerId });
        }

        return lines;
    }

    public async Task DeleteParkedAsync(ParkedTransaction parked)
    {
        await database.DeleteAsync("parked_transactions", parked.Id);
        if (parked.ServerId is not null)
        {
            await database.EnqueueAsync("parked_transaction", "delete", parked.Id, new { server_id = parked.ServerId });
        }
    }

    public static List<SaleLineInput> DeserializeParkedItems(string json)
    {
        try
        {
            var rows = JsonSerializer.Deserialize<List<ParkedItemDto>>(json, JsonOptions) ?? [];
            return rows.Select(row => new SaleLineInput
            {
                ProductId = row.ProductId,
                ProductName = row.Name ?? row.ProductName ?? "",
                Sku = row.Sku,
                Quantity = row.Quantity,
                UnitPrice = row.UnitPrice,
                Discount = row.Discount,
            }).ToList();
        }
        catch (JsonException)
        {
            return [];
        }
    }

    public async Task AdjustStockAsync(long productId, string movementType, decimal quantity, string? reason)
    {
            var product = await database.QuerySingleAsync<Product>(
                "SELECT id, stock, type FROM products WHERE id=$id",
                new { id = productId });

        if (product is null)
        {
            return;
        }

        var newStock = movementType switch
        {
            "in" => product.Stock + quantity,
            "out" => product.Stock - quantity,
            _ => quantity,
        };

        await database.ExecuteAsync(
            "UPDATE products SET stock=$stock WHERE id=$id",
            new { stock = newStock, id = productId });

        await database.InsertAsync("inventory_histories", new Dictionary<string, object?>
        {
            ["product_id"] = productId,
            ["user_id"] = settings.Value.UserId,
            ["type"] = movementType,
            ["quantity"] = Math.Abs(quantity),
            ["stock_before"] = product.Stock,
            ["stock_after"] = newStock,
            ["reason"] = reason,
            ["created_at"] = DateTime.Now,
        });

        await database.EnqueueAsync("inventory", "adjust", productId, new
        {
            product_id = productId,
            type = movementType,
            quantity = (int)Math.Abs(quantity),
            reason = reason,
        });
    }

    public async Task<string> VoidTransactionAsync(Transaction transaction)
    {
        await database.ExecuteAsync(
            "DELETE FROM transaction_items WHERE transaction_id=$id",
            new { id = transaction.Id });
        await database.ExecuteAsync(
            "DELETE FROM payments WHERE transaction_id=$id",
            new { id = transaction.Id });
        await database.DeleteAsync("transactions", transaction.Id);

        if (transaction.ServerId is not null)
        {
            await database.EnqueueAsync("transaction", "delete", transaction.Id, new { server_id = transaction.ServerId });
            return "Transaksi dihapus lokal dan akan dihapus di server saat online.";
        }

        return "Transaksi lokal dihapus.";
    }

    public async Task OpenRegisterAsync(long registerId, decimal openingFloat, string? notes)
    {
        var id = await database.InsertAsync("register_sessions", new Dictionary<string, object?>
        {
            ["register_id"] = registerId,
            ["user_id"] = settings.Value.UserId,
            ["opening_float"] = openingFloat,
            ["expected_cash"] = openingFloat,
            ["status"] = "open",
            ["opened_at"] = DateTime.Now,
            ["notes"] = notes,
            ["updated_at"] = DateTime.Now,
        });

        await database.EnqueueAsync("register_session", "open", id, new
        {
            register_id = registerId,
            opening_float = openingFloat,
            notes,
        });
    }

    public async Task CloseRegisterAsync(RegisterSession session, decimal actualCash, string? notes)
    {
        var openedAt = session.OpenedAt ?? DateTime.Today;
        var cashSales = await database.ScalarAsync<decimal>(
            """
            SELECT COALESCE(SUM(p.amount),0) FROM payments p
            JOIN transactions t ON t.id = p.transaction_id
            WHERE p.method='CASH' AND t.type='sell' AND t.status='completed' AND t.created_at >= $opened
            """,
            new { opened = openedAt.ToString("o", CultureInfo.InvariantCulture) });

        var expected = (session.OpeningFloat) + cashSales;

        await database.UpdateAsync("register_sessions", session.Id, new Dictionary<string, object?>
        {
            ["actual_cash"] = actualCash,
            ["expected_cash"] = expected,
            ["over_short"] = actualCash - expected,
            ["status"] = "closed",
            ["closed_at"] = DateTime.Now,
            ["notes"] = notes,
            ["updated_at"] = DateTime.Now,
        });

        if (session.ServerId is not null)
        {
            await database.EnqueueAsync("register_session", "close", session.Id, new
            {
                server_id = session.ServerId,
                actual_cash = actualCash,
                notes,
            });
        }
    }

    private sealed class ParkedItemDto
    {
        public long ProductId { get; set; }
        public string? Name { get; set; }
        public string? ProductName { get; set; }
        public string? Sku { get; set; }
        public decimal Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal Discount { get; set; }
        public decimal Subtotal { get; set; }
    }
}
