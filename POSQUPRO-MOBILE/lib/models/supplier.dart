class Supplier {
  final int id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;

  Supplier({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.isActive = true,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      contactPerson: json['contact_person'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'is_active': isActive,
    };
  }
}
