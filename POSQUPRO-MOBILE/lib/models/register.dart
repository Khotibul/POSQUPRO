class Register {
  final int id;
  final String name;
  final String? description;
  final bool isActive;

  Register({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
  });

  factory Register.fromJson(Map<String, dynamic> json) {
    return Register(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      isActive: json['is_active'] ?? true,
    );
  }
}

class RegisterSession {
  final int id;
  final int registerId;
  final String? registerName;
  final int userId;
  final String? userName;
  final double openingBalance;
  final double? closingBalance;
  final String status;
  final DateTime? openedAt;
  final DateTime? closedAt;

  RegisterSession({
    required this.id,
    required this.registerId,
    this.registerName,
    required this.userId,
    this.userName,
    this.openingBalance = 0,
    this.closingBalance,
    this.status = 'open',
    this.openedAt,
    this.closedAt,
  });

  factory RegisterSession.fromJson(Map<String, dynamic> json) {
    return RegisterSession(
      id: json['id'] ?? 0,
      registerId: json['register_id'] ?? 0,
      registerName: json['register']?['name'],
      userId: json['user_id'] ?? 0,
      userName: json['user']?['name'],
      openingBalance: double.tryParse(json['opening_balance']?.toString() ?? '0') ?? 0,
      closingBalance: double.tryParse(json['closing_balance']?.toString() ?? '0'),
      status: json['status'] ?? 'open',
      openedAt: json['opened_at'] != null ? DateTime.tryParse(json['opened_at']) : null,
      closedAt: json['closed_at'] != null ? DateTime.tryParse(json['closed_at']) : null,
    );
  }
}
