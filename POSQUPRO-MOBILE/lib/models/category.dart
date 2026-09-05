class Category {
  final int id;
  final String name;
  final String? slug;
  final String? description;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
    );
  }
}
