import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TwoFactorAuthPage extends StatefulWidget {
  final String userId;
  final bool initialStatus;

  const TwoFactorAuthPage({
    super.key,
    required this.userId,
    required this.initialStatus,
  });

  @override
  State<TwoFactorAuthPage> createState() => _TwoFactorAuthPageState();
}

class _TwoFactorAuthPageState extends State<TwoFactorAuthPage> {
  late bool is2FAEnabled;
  bool isLoading = false;
  final Color primaryColor = const Color(0xFF233E99);

  @override
  void initState() {
    super.initState();
    is2FAEnabled = widget.initialStatus;
  }

  // --- LOGIC: TOGGLE 2FA ---
  Future<void> _toggle2FA(bool value) async {
    setState(() => isLoading = true);

    try {
      // 1. Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'is2FAEnabled': value,
      });

      // 2. Log Activity
      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.userId)
          .collection("activities")
          .add({
        'description': value ? 'Enabled Two-Factor Authentication' : 'Disabled Two-Factor Authentication',
        'iconCode': Icons.security.codePoint,
        'timestamp': FieldValue.serverTimestamp(),
        'action': 'Security Update',
      });

      setState(() {
        is2FAEnabled = value;
        isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? "2FA Enabled Successfully" : "2FA Disabled"),
          backgroundColor: value ? Colors.green : Colors.grey,
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update 2FA: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("Two-Factor Authentication", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image or Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.security_rounded, size: 80, color: primaryColor),
              ),
            ),
            const SizedBox(height: 30),

            const Text(
              "Protect your account",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              "Two-factor authentication adds an extra layer of security to your account. When enabled, you'll need to verify your identity via email when logging in from a new device.",
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 30),

            // Toggle Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Enable 2FA", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(is2FAEnabled ? "Currently Active" : "Currently Inactive",
                          style: TextStyle(fontSize: 12, color: is2FAEnabled ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                  isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Switch(
                    value: is2FAEnabled,
                    activeColor: primaryColor,
                    onChanged: _toggle2FA,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            if (is2FAEnabled)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3))
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        "Your account is now more secure. Ensure you have access to your registered email.",
                        style: TextStyle(fontSize: 12, color: Colors.blue[900], fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}