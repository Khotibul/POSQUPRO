class SubscriptionSnapshot {
  final String status;
  final String? planName;
  final String? planSlug;
  final bool isTrial;
  final bool isExpired;
  final DateTime? endsAt;
  final int daysRemaining;
  final String? billingCycle;
  final List<String> features;
  final Map<String, dynamic> limits;
  final bool hasPlan;

  const SubscriptionSnapshot({
    required this.status,
    this.planName,
    this.planSlug,
    this.isTrial = false,
    this.isExpired = false,
    this.endsAt,
    this.daysRemaining = 0,
    this.billingCycle,
    this.features = const [],
    this.limits = const {},
    this.hasPlan = false,
  });

  bool get isActive => !isExpired && status != 'suspended' && status != 'inactive';

  static SubscriptionSnapshot fromJson(Map<String, dynamic> json) {
    final subscription = json['subscription'] is Map
        ? Map<String, dynamic>.from(json['subscription'] as Map)
        : <String, dynamic>{};
    final plan = json['plan'] is Map ? Map<String, dynamic>.from(json['plan'] as Map) : null;
    final limits = json['limits'] is Map
        ? Map<String, dynamic>.from(json['limits'] as Map)
        : <String, dynamic>{};
    final features = (json['features'] ?? limits['features']) is List
        ? ((json['features'] ?? limits['features']) as List).map((e) => e.toString()).toList()
        : <String>[];

    return SubscriptionSnapshot(
      status: json['status']?.toString() ?? 'none',
      planName: plan?['name']?.toString() ?? limits['plan_name']?.toString(),
      planSlug: plan?['slug']?.toString() ?? limits['plan_slug']?.toString(),
      isTrial: subscription['is_trial'] == true,
      isExpired: subscription['is_expired'] == true,
      endsAt: DateTime.tryParse(subscription['ends_at']?.toString() ?? ''),
      daysRemaining: (subscription['days_remaining'] as num?)?.toInt() ??
          (json['days_remaining'] as num?)?.toInt() ??
          0,
      billingCycle: subscription['billing_cycle']?.toString(),
      features: features,
      limits: limits,
      hasPlan: limits['has_plan'] == true || plan != null,
    );
  }
}

class BillingPlan {
  final int id;
  final String name;
  final String? description;
  final double price;
  final double priceYearly;
  final int maxUsers;
  final int maxProducts;
  final int maxCustomers;
  final int maxBranches;
  final int maxTransactions;
  final List<String> features;

  const BillingPlan({
    required this.id,
    required this.name,
    this.description,
    this.price = 0,
    this.priceYearly = 0,
    this.maxUsers = 0,
    this.maxProducts = 0,
    this.maxCustomers = 0,
    this.maxBranches = 0,
    this.maxTransactions = 0,
    this.features = const [],
  });

  factory BillingPlan.fromJson(Map<String, dynamic> json) {
    int number(dynamic value) => (value as num?)?.toInt() ?? 0;
    return BillingPlan(
      id: number(json['id']),
      name: json['name']?.toString() ?? 'Paket',
      description: json['description']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      priceYearly: (json['price_yearly'] as num?)?.toDouble() ?? 0,
      maxUsers: number(json['max_users']),
      maxProducts: number(json['max_products']),
      maxCustomers: number(json['max_customers']),
      maxBranches: number(json['max_branches']),
      maxTransactions: number(json['max_transactions_per_month']),
      features: json['features'] is List
          ? (json['features'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class BillingInvoice {
  final String invoiceNumber;
  final String? planName;
  final String status;
  final double total;
  final DateTime? issuedAt;
  final String? paymentUrl;

  const BillingInvoice({
    required this.invoiceNumber,
    this.planName,
    required this.status,
    required this.total,
    this.issuedAt,
    this.paymentUrl,
  });

  factory BillingInvoice.fromJson(Map<String, dynamic> json) => BillingInvoice(
        invoiceNumber: json['invoice_number']?.toString() ?? '-',
        planName: json['plan_name']?.toString(),
        status: json['status']?.toString() ?? 'pending',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        issuedAt: DateTime.tryParse(json['issued_at']?.toString() ?? ''),
        paymentUrl: json['payment_url']?.toString(),
      );
}

class BillingOverview {
  final SubscriptionSnapshot subscription;
  final List<BillingPlan> plans;
  final List<BillingInvoice> invoices;
  final bool ipaymuEnabled;
  final String? billingUrl;

  const BillingOverview({
    required this.subscription,
    this.plans = const [],
    this.invoices = const [],
    this.ipaymuEnabled = false,
    this.billingUrl,
  });

  factory BillingOverview.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((item) => parse(Map<String, dynamic>.from(item)))
          .toList();
    }

    return BillingOverview(
      subscription: SubscriptionSnapshot.fromJson(json),
      plans: list(json['plans'], BillingPlan.fromJson),
      invoices: list(json['invoices'], BillingInvoice.fromJson),
      ipaymuEnabled: json['ipaymu_enabled'] == true,
      billingUrl: json['billing_url']?.toString(),
    );
  }
}
