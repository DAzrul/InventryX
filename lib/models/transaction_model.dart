// File: lib/models/transaction_model.dart
import 'package:hive/hive.dart';

part 'transaction_model.g.dart'; // Fail ini akan dijana oleh build_runner

// Enum untuk menentukan jenis operasi yang perlu dilakukan
enum OperationType {
  @HiveField(0)
  insert,
  @HiveField(1)
  update,
  @HiveField(2)
  delete,
}

@HiveType(typeId: 100) // typeId MESTI unik dalam projek anda
class TransactionModel extends HiveObject {

  @HiveField(0)
  final OperationType operationType;

  @HiveField(1)
  final String targetCollection; // Cth: 'products', 'suppliers'

  @HiveField(2)
  final Map<String, dynamic> payload; // Data yang akan di INSERT atau UPDATE

  @HiveField(3)
  final String? documentId; // Diperlukan untuk operasi UPDATE dan DELETE

  @HiveField(4)
  final DateTime timestamp; // Masa transaksi berlaku (untuk menyusun queue)

  TransactionModel({
    required this.operationType,
    required this.targetCollection,
    required this.payload,
    this.documentId,
    required this.timestamp,
  });
}