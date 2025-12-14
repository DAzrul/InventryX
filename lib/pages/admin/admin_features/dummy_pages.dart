// File: lib/pages/admin/admin_features/dummy_pages.dart
import 'package:flutter/material.dart';

// --- [BARU] Dummy Page generik untuk mengelakkan ralat rujukan ---
class DummyPage extends StatelessWidget {
  final String title;
  const DummyPage({super.key, this.title = "Coming Soon"});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
          child: Text("$title Page", style: TextStyle(fontSize: 18, color: Colors.grey[600]))
      )
  );
}

// --- Dummy Pages untuk Dashboard & Features Grid ---

class SupplierPage extends StatelessWidget {
  const SupplierPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Supplier List")), body: const Center(child: Text("Supplier List Page")));
}

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Supplier List")), body: const Center(child: Text("Supplier List Page")));
}

class RecommendationPage extends StatelessWidget {
  const RecommendationPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Recommendation")), body: const Center(child: Text("Recommendation Page")));
}


// --- Dummy Pages untuk Settings & Navigasi ---
class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Edit Profile")), body: const Center(child: Text("Edit Profile Page")));
}

class MyAccountPage extends StatelessWidget {
  const MyAccountPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("My Account")), body: const Center(child: Text("My Account Page")));
}

class PrivacySecurityPage extends StatelessWidget {
  const PrivacySecurityPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Privacy & Security")), body: const Center(child: Text("Privacy & Security Page")));
}

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Terms of Service")), body: const Center(child: Text("Terms of Service Page")));
}

class InventoryFAQPage extends StatelessWidget {
  const InventoryFAQPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("InventoryX FAQ")), body: const Center(child: Text("InventoryX FAQ Page")));
}