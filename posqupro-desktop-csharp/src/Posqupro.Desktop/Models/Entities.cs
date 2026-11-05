using System.Text.Json.Serialization;

namespace Posqupro.Desktop.Models;

public class PagedResponse<T>
{
    public List<T> Data { get; set; } = [];
    public int CurrentPage { get; set; }
    public int LastPage { get; set; }
    public int Total { get; set; }
    public int PerPage { get; set; }
}

public class Category
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string Name { get; set; } = "";
    public string? Slug { get; set; }
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? UpdatedAt { get; set; }
    public override string ToString() => Name;
}

public class UnitQuantity
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string Name { get; set; } = "";
    public string? Symbol { get; set; }
    public string? Description { get; set; }
    public override string ToString() => string.IsNullOrWhiteSpace(Symbol) ? Name : $"{Name} ({Symbol})";
}

public class Tax
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string Name { get; set; } = "";
    public decimal Rate { get; set; }
    public bool IsActive { get; set; } = true;
    public override string ToString() => $"{Name} ({Rate:0.##}%)";
}

public class Supplier
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string? Code { get; set; }
    public string Name { get; set; } = "";
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? ContactPerson { get; set; }
    public bool IsActive { get; set; } = true;
    public override string ToString() => Name;
}

public class Customer
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string Name { get; set; } = "";
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public decimal CreditLimit { get; set; }
    public bool IsActive { get; set; } = true;
    public override string ToString() => Name;
}

public class Branch
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Address { get; set; }
    public string? Phone { get; set; }
    public bool Active { get; set; } = true;
    public override string ToString() => Name;
}

public class Warehouse
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public long? BranchId { get; set; }
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public bool Active { get; set; } = true;
    public Branch? Branch { get; set; }
    public override string ToString() => Name;
}

public class UserInfo
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string Name { get; set; } = "";
    public string Email { get; set; } = "";
    public string? Role { get; set; }
    public string? Phone { get; set; }
    public bool IsActive { get; set; } = true;
    public override string ToString() => Name;
}

public class Register
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string Name { get; set; } = "";
    public string Code { get; set; } = "";
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public int SessionsCount { get; set; }
    public RegisterSession? OpenSession { get; set; }
    public override string ToString() => $"{Name} ({Code})";
}

public class RegisterSession
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public long? RegisterId { get; set; }
    public long? UserId { get; set; }
    public decimal OpeningFloat { get; set; }
    public decimal? ExpectedCash { get; set; }
    public decimal? ActualCash { get; set; }
    public decimal? OverShort { get; set; }
    public string Status { get; set; } = "open";
    public DateTime? OpenedAt { get; set; }
    public DateTime? ClosedAt { get; set; }
    public string? Notes { get; set; }
    public Register? Register { get; set; }
    public UserInfo? User { get; set; }
}

public class Product
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string Name { get; set; } = "";
    public string Sku { get; set; } = "";
    public string? Barcode { get; set; }
    public long? CategoryId { get; set; }
    public string? CategoryText { get; set; }
    public Category? Category { get; set; }
    public long? UnitQuantityId { get; set; }
    public UnitQuantity? UnitQuantity { get; set; }
    public long? TaxId { get; set; }
    public Tax? Tax { get; set; }
    public long? SupplierId { get; set; }
    public Supplier? Supplier { get; set; }
    public string Type { get; set; } = "finished_goods";
    public decimal CostPrice { get; set; }
    public decimal SellingPrice { get; set; }
    public decimal Price { get; set; }
    public decimal Stock { get; set; }
    public decimal MinStock { get; set; } = 5;
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }
    public string? Image { get; set; }
    public bool IsLowStock { get; set; }
    public DateTime? UpdatedAt { get; set; }

    [JsonIgnore]
    public bool IsService => Type == "service";

    [JsonIgnore]
    public decimal EffectivePrice => SellingPrice > 0 ? SellingPrice : Price;

    public string CategoryName { get; set; } = "";
    public string UnitName { get; set; } = "";
    public decimal TaxRate { get; set; }
}

public class Transaction
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string InvoiceNumber { get; set; } = "";
    public string Type { get; set; } = "sell";
    public long? CustomerId { get; set; }
    public long? SupplierId { get; set; }
    public long? UserId { get; set; }
    public decimal Subtotal { get; set; }
    public decimal Discount { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal Total { get; set; }
    public decimal PaidAmount { get; set; }
    public decimal ChangeAmount { get; set; }
    public string Status { get; set; } = "completed";
    public string? Notes { get; set; }
    public string? PaymentMethod { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Customer? Customer { get; set; }
    public Supplier? Supplier { get; set; }
    public UserInfo? User { get; set; }
    public List<TransactionItem> Items { get; set; } = [];
    public List<Payment> Payments { get; set; } = [];
    public string? CustomerName { get; set; }
    public string? CashierName { get; set; }
    public int ItemCount { get; set; }
}

public class TransactionItem
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public long TransactionId { get; set; }
    public long? ProductId { get; set; }
    public string? ProductName { get; set; }
    public string? Sku { get; set; }
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal Discount { get; set; }
    public decimal Subtotal { get; set; }
    public Product? Product { get; set; }
}

public class Payment
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public long? SaleId { get; set; }
    public long? TransactionId { get; set; }
    public string Method { get; set; } = "CASH";
    public decimal Amount { get; set; }
    public string? ReferenceNo { get; set; }
    public DateTime? CreatedAt { get; set; }
}

public class Expense
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public long? BranchId { get; set; }
    public long? ShiftId { get; set; }
    public long? UserId { get; set; }
    public string Category { get; set; } = "";
    public string? Description { get; set; }
    public decimal Amount { get; set; }
    public DateTime? CreatedAt { get; set; }
    public string? BranchName { get; set; }
    public string? UserName { get; set; }
}

public class CartLineDto
{
    public long ProductId { get; set; }
    public string? ProductName { get; set; }
    public string? Sku { get; set; }
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal Discount { get; set; }
    public decimal Subtotal { get; set; }
}

public class ParkedTransaction
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string InvoiceNumber { get; set; } = "";
    public long? CustomerId { get; set; }
    public string ItemsJson { get; set; } = "[]";
    public List<CartLineDto> Items { get; set; } = [];
    public decimal Subtotal { get; set; }
    public decimal Discount { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal Total { get; set; }
    public string? Notes { get; set; }
    public long? UserId { get; set; }
    public Customer? Customer { get; set; }
    public DateTime? CreatedAt { get; set; }
    public string CustomerName => Customer?.Name ?? "Umum";
    public int ItemCount => Items.Count;
}

public class PurchaseOrder
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string PoNumber { get; set; } = "";
    public long? SupplierId { get; set; }
    public long? UserId { get; set; }
    public string Status { get; set; } = "draft";
    public DateTime? ExpectedDate { get; set; }
    public decimal Subtotal { get; set; }
    public decimal Discount { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal Total { get; set; }
    public string? Notes { get; set; }
    public DateTime? CreatedAt { get; set; }
    public Supplier? Supplier { get; set; }
    public List<PurchaseOrderItem> Items { get; set; } = [];
    public string SupplierName => Supplier?.Name ?? "";
}

public class PurchaseOrderItem
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public long PurchaseOrderId { get; set; }
    public long? ProductId { get; set; }
    public decimal Quantity { get; set; }
    public decimal ReceivedQuantity { get; set; }
    public decimal UnitCost { get; set; }
    public decimal Discount { get; set; }
    public decimal Subtotal { get; set; }
    public Product? Product { get; set; }
    public string ProductName => Product?.Name ?? "";
}

public class StockCount
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string CountNumber { get; set; } = "";
    public long? UserId { get; set; }
    public string Status { get; set; } = "draft";
    public bool IsBlind { get; set; }
    public DateTime? CountedAt { get; set; }
    public DateTime? ApprovedAt { get; set; }
    public DateTime? PostedAt { get; set; }
    public string? Notes { get; set; }
    public DateTime? CreatedAt { get; set; }
    public List<StockCountItem> Items { get; set; } = [];
    public string CreatorName { get; set; } = "";
}

public class StockCountItem
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public long StockCountId { get; set; }
    public long? ProductId { get; set; }
    public decimal SystemQuantity { get; set; }
    public decimal? CountedQuantity { get; set; }
    public decimal? Variance { get; set; }
    public string? Notes { get; set; }
    public Product? Product { get; set; }
    public string ProductName => Product?.Name ?? "";
}

public class InventoryHistory
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public long? ProductId { get; set; }
    public long? UserId { get; set; }
    public string Type { get; set; } = "in";
    public decimal Quantity { get; set; }
    public decimal? StockBefore { get; set; }
    public decimal? StockAfter { get; set; }
    public string? Reason { get; set; }
    public DateTime? CreatedAt { get; set; }
    public string ProductName { get; set; } = "";
    public string UserName { get; set; } = "";
}

public class ActivityLog
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public long? UserId { get; set; }
    public string Event { get; set; } = "";
    public string? Description { get; set; }
    public string? SubjectType { get; set; }
    public long? SubjectId { get; set; }
    public DateTime? CreatedAt { get; set; }
    public UserInfo? User { get; set; }
    public string UserName => User?.Name ?? "";
}

public class SupplierInvoice
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public long? SupplierId { get; set; }
    public long? PurchaseOrderId { get; set; }
    public string InvoiceNumber { get; set; } = "";
    public DateTime? InvoiceDate { get; set; }
    public DateTime? DueDate { get; set; }
    public decimal Amount { get; set; }
    public string Status { get; set; } = "pending";
    public string? Notes { get; set; }
    public Supplier? Supplier { get; set; }
}

public class PaymentMethod
{
    public long Id { get; set; }
    public long? ServerId { get; set; }
    public string Name { get; set; } = "";
    public string? Label { get; set; }
    public bool Active { get; set; } = true;
}

public class SettingItem
{
    public long Id { get; set; }
    public string Key { get; set; } = "";
    public string Group { get; set; } = "general";
    public string? Value { get; set; }
    public string Type { get; set; } = "string";
    public string? Label { get; set; }
    public bool IsPublic { get; set; }
}

public class PlanInfo
{
    public long Id { get; set; }
    public string Name { get; set; } = "";
}

public class TenantInfo
{
    public long Id { get; set; }
    public string Name { get; set; } = "";
    public string? Slug { get; set; }
    public string? Status { get; set; }
    public string? LicenseCode { get; set; }
    public PlanInfo? Plan { get; set; }
}

public class AuthResponse
{
    public string Token { get; set; } = "";
    public UserInfo User { get; set; } = new();
    public TenantInfo? Tenant { get; set; }
}

public class SyncQueueItem
{
    public long Id { get; set; }
    public string Entity { get; set; } = "";
    public string Operation { get; set; } = "";
    public long LocalId { get; set; }
    public string Payload { get; set; } = "{}";
    public int Attempts { get; set; }
    public string? LastError { get; set; }
    public DateTime CreatedAt { get; set; }
    public string Summary => $"{Entity} · {Operation}";
}
