// lib/services/user_data_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Guna 'foundation.dart' untuk debugPrint

/// Mengambil data pengguna tunggal dari Firestore berdasarkan 'username'.
///
/// Mengembalikan Map<String, dynamic> data pengguna jika ditemui,
/// atau null jika tidak ditemui atau terdapat ralat.
Future<Map<String, dynamic>?> fetchLoggedInUserData(String username) async {
  if (username.isEmpty) {
    debugPrint("Username cannot be empty.");
    return null;
  }

  try {
    // Akses koleksi "users" dan cari dokumen di mana 'username' sepadan.
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("users")
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    // Semak sama ada sebarang dokumen telah dikembalikan
    if (snapshot.docs.isNotEmpty) {
      // Dapatkan data dari dokumen pertama
      return snapshot.docs.first.data() as Map<String, dynamic>;
    }

    // Jika tiada dokumen ditemui
    return null;
  } catch (e) {
    debugPrint("Error fetching logged in user data for $username: $e");
    return null;
  }
}