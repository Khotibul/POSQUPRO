class Customer {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final double creditLimit;
  final bool isActive;

  Customer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.creditLimit = 0,
    this.isActive = true,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      address: json['address'],
      creditLimit: double.tryParse(json['credit_limit']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }
}
