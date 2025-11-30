import 'package:flutter/material.dart';

class AdminSettingsPage extends StatelessWidget {
  final String loggedInUsername;

  AdminSettingsPage({required this.loggedInUsername});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: Center(child: Text("Halaman Settings Admin")),
    );
  }
}