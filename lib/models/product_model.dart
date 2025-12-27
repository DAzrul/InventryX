// File: lib/models/product_model.dart
class ProductModel {
  final String id;
  final String name;
  final String category;
  final String subCategory;
  final String imageUrl;
  final double price;

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.subCategory,
    required this.imageUrl,
    required this.price
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      name: map['productName'] ?? 'Unknown',
      category: map['category'] ?? 'General',
      subCategory: map['subCategory'] ?? 'General',
      imageUrl: map['imageUrl'] ?? '',
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : (map['price'] ?? 0.0),
    );
  }
}