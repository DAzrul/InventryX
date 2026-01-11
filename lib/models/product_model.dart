// File: lib/models/product_model.dart
class ProductModel {
  final String id;
  final String name;
  final String category;
  final String subCategory;
  final String imageUrl;
  final double price;
  final int unitsPerCarton;

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.subCategory,
    required this.imageUrl,
    required this.price,
    required this.unitsPerCarton,
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      name: map['productName'] ?? 'Unknown',
      category: map['category'] ?? 'General',
      subCategory: map['subCategory'] ?? 'General',
      imageUrl: map['imageUrl'] ?? '',
      // Safely convert to double
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      // Fix: Changed 'data' to 'map' to match parameter name
      unitsPerCarton: (map['unitsPerCarton'] as num?)?.toInt() ?? 1,
    );
  }
}