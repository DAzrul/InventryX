import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import Home Pages
import 'admin/admin_page.dart';
import 'manager/manager_page.dart';
import 'staff/staff_page.dart';

class Verify2FAPage extends StatefulWidget {
  final String userId;
  final String username;
  final String role;
  final String email;
  final bool rememberMe; // Kita bawa status "Stay Signed In" dari Login Page

  const Verify2FAPage({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    required this.email,
    required this.rememberMe,
  });

  @override
  State<Verify2FAPage> createState() => _Verify2FAPageState();
}

class _Verify2FAPageState extends State<Verify2FAPage> {
  final TextEditingController _codeController = TextEditingController();
  final Color primaryBlue = const Color(0xFF233E99);

  String? _generatedOTP;
  bool _isLoading = false;
  Timer? _timer;
  int _start = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _sendOTP();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _sendOTP() {
    setState(() {
      _generatedOTP = (100000 + Random().nextInt(900000)).toString();
      _start = 60;
      _canResend = false;
    });

    _startTimer();

    // [SIMULASI EMAIL]
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Email sent! Your code is: $_generatedOTP"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'COPY',
              textColor: Colors.white,
              onPressed: () => _codeController.text = _generatedOTP!,
            ),
          ),
        );
      }
    });
  }

  void _startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
          _canResend = true;
        });
      } else {
        setState(() => _start--);
      }
    });
  }

  // --- [UPDATE] LOGIC TRUSTED DEVICE KAT SINI ---
  Future<void> _verifyCode() async {
    String inputCode = _codeController.text.trim();

    if (inputCode.isEmpty) {
      _showSnack("Please enter the 6-digit code.", isError: true);
      return;
    }

    if (inputCode != _generatedOTP) {
      _showSnack("Invalid code! Please try again.", isError: true);
      return;
    }

    // KOD BETUL! PROCEED
    setState(() => _isLoading = true);

    try {
      // 1. [PENTING] INI LANGKAH "COP" TRUSTED DEVICE
      // Kita hanya simpan session kalau kod 2FA dah betul.
      // Kalau user tick "Stay Signed In" kat depan tadi, kita simpan selamanya.
      if (widget.rememberMe) {
        final prefs = await SharedPreferences.getInstance();

        // Simpan "Tiket Masuk"
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('savedUsername', widget.username);
        await prefs.setString('savedRole', widget.role);
        await prefs.setString('savedUserId', widget.userId);

        // [Safety] Kita boleh simpan tarikh last 2FA kalau nak expiredkan lepas sebulan (Optional)
        // await prefs.setInt('last2FADate', DateTime.now().millisecondsSinceEpoch);
      }

      // 2. Rekod Activity
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('activities')
          .add({
        'action': '2FA Login',
        'details': 'Device verified via 2FA (Trusted).',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Masuk Home Page
      if (!mounted) return;
      Widget targetPage;

      if (widget.role == "admin") {
        targetPage = AdminPage(username: widget.username, userId: widget.userId, loggedInUsername: widget.username);
      } else if (widget.role == "manager") {
        targetPage = ManagerPage(username: widget.username, userId: widget.userId, loggedInUsername: widget.username);
      } else {
        targetPage = StaffPage(username: widget.username, userId: widget.userId, loggedInUsername: widget.username);
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => targetPage),
            (route) => false,
      );

    } catch (e) {
      _showSnack("Error: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.verified_user_rounded, size: 60, color: primaryBlue),
            ),
            const SizedBox(height: 30),

            const Text("Device Verification", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(
              "We sent a code to ${widget.email}.\nEnter it below to trust this device.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),

            const SizedBox(height: 40),

            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 5),
              decoration: InputDecoration(
                counterText: "",
                hintText: "000000",
                hintStyle: TextStyle(color: Colors.grey[300], letterSpacing: 5),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryBlue, width: 2)),
                filled: true,
                fillColor: const Color(0xFFF8F9FD),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                onPressed: _isLoading ? null : _verifyCode,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("VERIFY & TRUST DEVICE", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Didn't receive code? ", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                GestureDetector(
                  onTap: _canResend ? _sendOTP : null,
                  child: Text(
                    _canResend ? "Resend Now" : "Resend in ${_start}s",
                    style: TextStyle(color: _canResend ? primaryBlue : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}