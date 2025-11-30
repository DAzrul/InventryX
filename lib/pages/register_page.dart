import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers untuk medan input
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneNoController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool showPassword = false;
  bool loading = false;

  // --- Fungsi Mesej Popup yang Diperbaiki untuk menerima 'details' ---
  void showPopupMessage(String title, {String? details}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: details != null ? Text(details) : null,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        );
      },
    );
  }

  Future<void> registerUser() async {
    String name = nameController.text.trim();
    String phoneNo = phoneNoController.text.trim();
    String username = usernameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    // 1. Basic Validation
    if (name.isEmpty || phoneNo.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      showPopupMessage("Validation Error", details: "Please fill all fields.");
      return;
    }

    if (password != confirmPassword) {
      showPopupMessage("Validation Error", details: "Passwords do not match.");
      return;
    }

    if (password.length < 6) {
      showPopupMessage("Validation Error", details: "Password must be at least 6 characters.");
      return;
    }

    if (!email.contains("@") || !email.contains(".")) {
      showPopupMessage("Validation Error", details: "Please enter a valid email address.");
      return;
    }

    setState(() => loading = true);

    try {
      // 2. Check if Username already exists in Firestore
      QuerySnapshot userSnap = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: username)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        showPopupMessage("Registration Failed", details: "Username already taken.");
        setState(() => loading = false);
        return;
      }

      // 3. Register User ke Firebase Authentication
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? newUser = userCredential.user;

      if (newUser == null) {
        showPopupMessage("Registration Failed", details: "User creation failed.");
        setState(() => loading = false);
        return;
      }

      final String userUid = newUser.uid;

      // 4. Simpan Butiran Tambahan ke Firestore menggunakan UID sebagai ID Dokumen
      await FirebaseFirestore.instance.collection("users").doc(userUid).set({
        "name": name,
        "phoneNo": phoneNo,
        "username": username,
        "email": email,
        "role": "staff",
        "status": "Active",
        "createdAt": Timestamp.now(),
        // Anda boleh tambah medan profilePictureUrl: '' jika perlu
      });

      // [PENTING] Semak jika context masih sah sebelum guna
      if (!mounted) return;

      showPopupMessage("Registration Successful!", details: "You can now sign in.");

      // 5. Navigate back to Login Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = "Email is already registered. Please sign in.";
      } else if (e.code == 'weak-password') {
        errorMessage = "The password provided is too weak (min 6 characters).";
      } else {
        errorMessage = "Authentication Error: ${e.message}";
      }
      showPopupMessage("Registration Failed", details: errorMessage);
    } catch (e) {
      showPopupMessage("Registration Error", details: "System error: ${e.toString()}");
    } finally {
      if(mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isPortrait = constraints.maxHeight > constraints.maxWidth;
          double horizontalPadding = constraints.maxWidth * 0.08;

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  SizedBox(
                    height: isPortrait
                        ? constraints.maxHeight * 0.15
                        : constraints.maxHeight * 0.25,
                    child: Image.asset("assets/logo.png", fit: BoxFit.contain),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.02),

                  const Text(
                    "Create Account",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.03),

                  // NAMA field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: const Icon(Icons.badge_outlined),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.02),

                  // PHONE NO field
                  TextField(
                    controller: phoneNoController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "Phone Number",
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.02),

                  // Username field
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: "Username",
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.02),

                  // Email field
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.02),

                  // Password field
                  TextField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: "Password (Min 6 characters)",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(showPassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.02),

                  // Confirm Password field
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.03),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    height: constraints.maxHeight * 0.07,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF233E99),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: loading ? null : registerUser,
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        "SIGN UP",
                        style: TextStyle(
                          fontSize: isPortrait
                              ? constraints.maxWidth * 0.05
                              : constraints.maxHeight * 0.04,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.01),

                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text("Already have an account? Sign In"),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}