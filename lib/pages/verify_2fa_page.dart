import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import Home Pages (Pastikan path import ini betul dalam projek anda)
import 'admin/admin_page.dart';
import 'manager/manager_page.dart';
import 'staff/staff_page.dart';

class Verify2FAPage extends StatefulWidget {
  final String userId;
  final String username;
  final String role;
  final String email;
  final bool rememberMe;

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
  bool _isSendingEmail = false;
  Timer? _timer;
  int _start = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _generateAndSendOTP();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  // --- LOGIC 1: GENERATE KOD & PANGGIL FUNGSI EMAIL ---
  Future<void> _generateAndSendOTP() async {
    setState(() {
      // Generate nombor rawak 6 digit
      _generatedOTP = (100000 + Random().nextInt(900000)).toString();
      _start = 60;
      _canResend = false;
      _isSendingEmail = true;
    });

    // Panggil fungsi hantar ke Firestore
    bool success = await _sendEmailViaFirebaseExtension(
        name: widget.username,
        email: widget.email,
        otp: _generatedOTP!
    );

    if (mounted) {
      setState(() => _isSendingEmail = false);

      if (success) {
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Code sent to ${widget.email}"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to trigger email. Check connection."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _canResend = true); // Benarkan user cuba lagi
      }
    }
  }

  // --- LOGIC 2: FIREBASE EXTENSION (TRIGGER EMAIL) ---
  // Fungsi ini menulis data ke collection 'mail'. Extension akan buat kerja selebihnya.
  Future<bool> _sendEmailViaFirebaseExtension({required String name, required String email, required String otp}) async {
    try {
      await FirebaseFirestore.instance.collection('mail').add({
        'to': [email], // Extension perlukan array/list untuk 'to'
        'message': {
          'subject': 'Your Verification Code (2FA)',
          'html': '''
            <h2>Hello $name,</h2>
            <p>Your verification code is:</p>
            <h1 style="color: #233E99; letter-spacing: 5px;">$otp</h1>
            <p>Please enter this code in the app to complete your login.</p>
            <br>
            <p>If you did not request this, please ignore this email.</p>
          ''',
        },
      });

      // Kalau berjaya save ke Firestore, kita anggap email sedang dihantar
      return true;
    } catch (e) {
      debugPrint("Firebase Email Error: $e");
      return false;
    }
  }

  // --- LOGIC 3: TIMER COUNTDOWN ---
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

  // --- LOGIC 4: SAHKAN KOD INPUT ---
  Future<void> _verifyCode() async {
    String inputCode = _codeController.text.trim();

    if (inputCode.isEmpty) {
      _showSnack("Please enter the 6-digit code.", isError: true);
      return;
    }

    if (inputCode != _generatedOTP) {
      _showSnack("Invalid code! Please check your email.", isError: true);
      return;
    }

    // KOD BETUL! MULA PROSES LOGIN
    setState(() => _isLoading = true);

    try {
      // A. Simpan Status "Trusted Device" jika user tick "Remember Me"
      if (widget.rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('savedUsername', widget.username);
        await prefs.setString('savedRole', widget.role);
        await prefs.setString('savedUserId', widget.userId);
      }

      // B. Rekod Aktiviti Login ke Firestore (Audit Trail)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('activities')
          .add({
        'action': '2FA Login',
        'details': 'Device verified via Firebase Email Extension.',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // C. Navigasi ke Halaman Utama Mengikut Role
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
      _showSnack("Login Error: $e", isError: true);
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
            // Ikon Email
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.mark_email_read_outlined, size: 60, color: primaryBlue),
            ),
            const SizedBox(height: 30),

            const Text("Check Your Email", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(
              "We've sent a code to\n${widget.email}",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
            ),

            const SizedBox(height: 40),

            // Input Field Kod 6 Digit
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 5),
              decoration: InputDecoration(
                counterText: "",
                hintText: "------",
                hintStyle: TextStyle(color: Colors.grey[300], letterSpacing: 5),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryBlue, width: 2)),
                filled: true,
                fillColor: const Color(0xFFF8F9FD),
              ),
            ),

            const SizedBox(height: 30),

            // Butang Verify
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                onPressed: (_isLoading || _isSendingEmail) ? null : _verifyCode,
                child: (_isLoading || _isSendingEmail)
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    const SizedBox(width: 15),
                    Text(_isSendingEmail ? "Sending Email..." : "Verifying...", style: const TextStyle(color: Colors.white))
                  ],
                )
                    : const Text("VERIFY", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 25),

            // Link Resend Code
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Didn't receive code? ", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                GestureDetector(
                  onTap: (_canResend && !_isSendingEmail) ? _generateAndSendOTP : null,
                  child: Text(
                    _canResend ? "Resend Now" : "Resend in ${_start}s",
                    style: TextStyle(
                        color: (_canResend && !_isSendingEmail) ? primaryBlue : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13
                    ),
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