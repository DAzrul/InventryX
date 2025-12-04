// Lokasi Baru: lib/services/user_data_service.dart (atau serupa)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

Future<Map<String, dynamic>?> fetchLoggedInUserData(String username) async {
  try {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("users")
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data() as Map<String, dynamic>;
    }
    return null;
  } catch (e) {
    debugPrint("Error fetching logged in user data: $e");
    return null;
  }
}