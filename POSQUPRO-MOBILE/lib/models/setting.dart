class Setting {
  final int id;
  final String key;
  final String? value;
  final String? group;
  final String? description;

  Setting({
    required this.id,
    required this.key,
    this.value,
    this.group,
    this.description,
  });

  factory Setting.fromJson(Map<String, dynamic> json) {
    return Setting(
      id: json['id'] ?? 0,
      key: json['setting_key'] ?? json['key'] ?? '',
      value: json['setting_value'] ?? json['value'],
      group: json['setting_group'] ?? json['group'],
      description: json['description'],
    );
  }
}

class FinanceSummary {
  final double totalRevenue;
  final double totalCost;
  final double totalProfit;
  final int totalTransactions;
  final double todayRevenue;
  final int todayTransactions;

  FinanceSummary({
    this.totalRevenue = 0,
    this.totalCost = 0,
    this.totalProfit = 0,
    this.totalTransactions = 0,
    this.todayRevenue = 0,
    this.todayTransactions = 0,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    return FinanceSummary(
      totalRevenue: double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0,
      totalCost: double.tryParse(json['total_cost']?.toString() ?? '0') ?? 0,
      totalProfit: double.tryParse(json['total_profit']?.toString() ?? '0') ?? 0,
      totalTransactions: json['total_transactions'] ?? 0,
      todayRevenue: double.tryParse(json['today_revenue']?.toString() ?? '0') ?? 0,
      todayTransactions: json['today_transactions'] ?? 0,
    );
  }
}
