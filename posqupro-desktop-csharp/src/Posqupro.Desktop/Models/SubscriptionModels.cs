using System.Text.Json.Serialization;

namespace Posqupro.Desktop.Models;

public class PlanLimit
{
    public int Current { get; set; }
    public int Max { get; set; }
    public bool Ok { get; set; } = true;
    public bool Unlimited { get; set; }

    public string Display => Unlimited ? $"{Current} / Tak terbatas" : $"{Current} / {Max}";
}

public class SubscriptionSummary
{
    public string? Status { get; set; }

    [JsonPropertyName("is_trial")]
    public bool IsTrial { get; set; }

    [JsonPropertyName("is_expired")]
    public bool IsExpired { get; set; }

    [JsonPropertyName("days_remaining")]
    public int DaysRemaining { get; set; }

    [JsonPropertyName("billing_cycle")]
    public string? BillingCycle { get; set; }

    [JsonPropertyName("ends_at")]
    public DateTime? EndsAt { get; set; }
}

public class BillingPlan
{
    public long Id { get; set; }
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    public decimal Price { get; set; }

    [JsonPropertyName("price_yearly")]
    public decimal PriceYearly { get; set; }

    [JsonPropertyName("max_users")]
    public int MaxUsers { get; set; }

    [JsonPropertyName("max_products")]
    public int MaxProducts { get; set; }

    [JsonPropertyName("max_customers")]
    public int MaxCustomers { get; set; }

    [JsonPropertyName("max_branches")]
    public int MaxBranches { get; set; }

    [JsonPropertyName("max_transactions_per_month")]
    public int MaxTransactionsPerMonth { get; set; }

    public List<string> Features { get; set; } = [];

    public string MonthlyPriceLabel => $"Rp {Price:N0} / bulan";
    public string YearlyPriceLabel => PriceYearly <= 0 ? "" : $"Rp {PriceYearly:N0} / tahun";

    public string LimitsLabel =>
        $"{UsersLabel(MaxUsers)} pengguna · {UsersLabel(MaxProducts)} produk · {UsersLabel(MaxCustomers)} pelanggan · " +
        $"{UsersLabel(MaxBranches)} cabang · {UsersLabel(MaxTransactionsPerMonth)} transaksi/bln";

    public string FeatureSummary => string.Join(", ", Features.Select(feature => FeatureLabel(feature)));

    private static string FeatureLabel(string feature) => feature switch
    {
        "pos" => "POS / Kasir",
        "products" => "Produk & Stok",
        "customers" => "Pelanggan",
        "suppliers" => "Supplier",
        "inventory" => "Inventory",
        "expenses" => "Pengeluaran",
        "users" => "Pengguna & RBAC",
        "reports" => "Laporan & Analitik",
        "purchase_orders" => "Purchase Order",
        "stock_counts" => "Stock Opname",
        "multi_branch" => "Multi Cabang & Gudang",
        "api_access" => "Akses API / Mobile",
        "priority_support" => "Priority Support",
        _ => feature,
    };

    private static string UsersLabel(int value) => value <= 0 ? "∞" : value.ToString();
}

public class BillingInvoice
{
    public long Id { get; set; }

    [JsonPropertyName("invoice_number")]
    public string InvoiceNumber { get; set; } = "";

    [JsonPropertyName("plan_name")]
    public string? PlanName { get; set; }

    public string Status { get; set; } = "pending";

    [JsonPropertyName("billing_cycle")]
    public string? BillingCycle { get; set; }

    public decimal Total { get; set; }

    [JsonPropertyName("issued_at")]
    public DateTime? IssuedAt { get; set; }

    [JsonPropertyName("paid_at")]
    public DateTime? PaidAt { get; set; }

    [JsonPropertyName("payment_url")]
    public string? PaymentUrl { get; set; }

    public string TotalLabel => $"Rp {Total:N0}";
    public string StatusLabel => Status.ToUpperInvariant();
    public bool CanPay => Status == "pending" && !string.IsNullOrWhiteSpace(PaymentUrl);
}

public class LimitsPayload
{
    [JsonPropertyName("has_plan")]
    public bool HasPlan { get; set; }

    [JsonPropertyName("plan_name")]
    public string? PlanName { get; set; }

    public PlanLimit? Users { get; set; }
    public PlanLimit? Products { get; set; }
    public PlanLimit? Customers { get; set; }
    public PlanLimit? Branches { get; set; }

    [JsonPropertyName("transactions_month")]
    public PlanLimit? TransactionsMonth { get; set; }
}

public class SubscriptionOverview
{
    public string? Status { get; set; }
    public PlanInfo? Plan { get; set; }
    public SubscriptionSummary? Subscription { get; set; }
    public LimitsPayload? Limits { get; set; }
    public List<string> Features { get; set; } = [];
    public List<BillingPlan> Plans { get; set; } = [];
    public List<BillingInvoice> Invoices { get; set; } = [];

    [JsonPropertyName("days_remaining")]
    public int DaysRemaining { get; set; }

    [JsonPropertyName("ipaymu_enabled")]
    public bool IpaymuEnabled { get; set; }

    [JsonPropertyName("billing_url")]
    public string? BillingUrl { get; set; }

    public bool HasPlan => Plan is not null || (Limits?.HasPlan ?? false);
}

public class CheckoutResponse
{
    public BillingInvoice? Invoice { get; set; }

    [JsonPropertyName("payment_url")]
    public string? PaymentUrl { get; set; }
}
