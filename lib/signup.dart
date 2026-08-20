import 'package:alertu_flutter/wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'email_sending.dart';

// Global loading tracker for the registration flow
final signUpLoadingProvider = StateProvider<bool>((ref) => false);

class SignUp extends ConsumerStatefulWidget {
  const SignUp({super.key});

  @override
  ConsumerState<SignUp> createState() => _SignUpState();
}

class _SignUpState extends ConsumerState<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController name = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController address = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();

  String completePhoneNumber = "";
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isPhoneValid = false;
  bool _isDpaAccepted = false;

  // Real-time strength trackers
  String _strengthText = "Weak";
  Color _strengthColor = Colors.red;
  double _strengthProgress = 0.33;

  @override
  void initState() {
    super.initState();
    password.addListener(_evaluatePasswordStrength);
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    address.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  void _evaluatePasswordStrength() {
    final text = password.text;
    final uppercaseCount = text.replaceAll(RegExp(r'[^A-Z]'), '').length;
    final specialCharCount = text.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '').length;

    if (text.length < 12) {
      setState(() {
        _strengthText = "Weak";
        _strengthColor = Colors.red;
        _strengthProgress = 0.33;
      });
    } else if (text.length >= 15 && uppercaseCount == 1 && specialCharCount == 1) {
      setState(() {
        _strengthText = "Strong";
        _strengthColor = Colors.green;
        _strengthProgress = 1.0;
      });
    } else {
      setState(() {
        _strengthText = "Moderate";
        _strengthColor = Colors.amber;
        _strengthProgress = 0.66;
      });
    }
  }

  void _showSnackBar(String title, String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor ?? const Color(0xff0d47a1),
        behavior: SnackBarBehavior.floating,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text(message, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  /// Atomically fetches and increments the next citizen ID from counters/citizens
  Future<String> _getNextCitizenID() async {
    final counterRef = FirebaseFirestore.instance.collection('counters').doc('citizens');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final counterDoc = await transaction.get(counterRef);

      int currentCount = 0;
      if (counterDoc.exists && counterDoc.data() != null) {
        final data = counterDoc.data()!;
        if (data.containsKey('currentCount')) {
          currentCount = (data['currentCount'] as num).toInt();
        } else if (data.containsKey('count')) {
          currentCount = (data['count'] as num).toInt();
        }
      }

      final nextCount = currentCount + 1;
      final formattedID = 'CID${nextCount.toString().padLeft(8, '0')}';

      if (counterDoc.exists) {
        transaction.update(counterRef, {
          'currentCount': nextCount,
          'count': nextCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(counterRef, {
          'currentCount': nextCount,
          'count': nextCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return formattedID;
    });
  }

  Future<void> signUp() async {
    if (!_formKey.currentState!.validate() || !_isPhoneValid || completePhoneNumber.isEmpty) {
      _showSnackBar("Registration Blocked", "Please resolve form errors before submitting.");
      return;
    }

    if (!_isDpaAccepted) {
      _showSnackBar(
        "Consent Required",
        "Please accept the data privacy terms to register.",
        backgroundColor: Colors.amber.shade800,
      );
      return;
    }

    // Trigger loader
    ref.read(signUpLoadingProvider.notifier).state = true;
    UserCredential? userCredential;

    try {
      userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );

      String? uid = userCredential.user?.uid;

      if (uid != null) {
        // 1. Generate sequential citizen ID atomically
        String citizenID = await _getNextCitizenID();

        String customProfileData = "${name.text.trim()}||$completePhoneNumber||${address.text.trim()}";
        await userCredential.user?.updateDisplayName(customProfileData);

        // 2. Save document with citizenID included
        await FirebaseFirestore.instance.collection('citizens').doc(uid).set({
          'citizenID': citizenID,
          'id': uid,
          'authUid': uid,
          'fullName': name.text.trim(),
          'email': email.text.trim(),
          'phoneNumber': completePhoneNumber,
          'zone': address.text.trim(),
          'status': 'Active',
          'dpaAccepted': true,
          'dpaAcceptedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const EmailSendingScreen()),
                (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showSnackBar("Sign Up Error", e.message ?? "Error encountered.");
      }
    } catch (e) {
      // Rollback Auth creation if database write fails
      if (userCredential?.user != null) {
        try {
          await userCredential!.user!.delete();
        } catch (_) {}
      }
      if (mounted) {
        _showSnackBar("Database Error", "Auth succeeded but failed to save profile data.");
      }
      debugPrint("Firestore Sync Failure: $e");
    } finally {
      if (mounted) {
        ref.read(signUpLoadingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(signUpLoadingProvider);

    return Theme(
      data: ThemeData.light().copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xff0d47a1),
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          labelStyle: const TextStyle(color: Colors.black87),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff0d47a1), width: 1.5),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xff0d47a1)),
        ),
        body: SafeArea(
          child: isLoading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0d47a1)),
            ),
          )
              : LayoutBuilder(
            builder: (context, constraints) {
              double horizontalPadding = constraints.maxWidth > 600 ? 40.0 : 24.0;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Create Account',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xff0d47a1)),
                          ),
                          const SizedBox(height: 24),

                          // 1. Name
                          TextFormField(
                            controller: name,
                            style: const TextStyle(color: Colors.black87),
                            decoration: const InputDecoration(hintText: 'Full Name'),
                            validator: (v) => (v == null || v.trim().length < 2) ? 'Provide a valid name' : null,
                          ),
                          const SizedBox(height: 14),

                          // 2. Email
                          TextFormField(
                            controller: email,
                            style: const TextStyle(color: Colors.black87),
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Email Address',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Image.asset('images/emailicon.png', height: 20, width: 20),
                              ),
                            ),
                            validator: (v) => (v == null || !v.contains('@')) ? 'Provide a valid email address' : null,
                          ),
                          const SizedBox(height: 14),

                          // 3. International Phone Field
                          IntlPhoneField(
                            style: const TextStyle(color: Colors.black87),
                            dropdownTextStyle: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'Phone Number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            initialCountryCode: 'PH',
                            onChanged: (phone) {
                              completePhoneNumber = phone.completeNumber;
                              try {
                                _isPhoneValid = phone.isValidNumber();
                              } catch (_) {
                                _isPhoneValid = false;
                              }
                            },
                          ),
                          const SizedBox(height: 14),

                          // 4. Home Address
                          TextFormField(
                            controller: address,
                            style: const TextStyle(color: Colors.black87),
                            decoration: const InputDecoration(hintText: 'Home Address'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Home address is required' : null,
                          ),
                          const SizedBox(height: 14),

                          // 5. Password
                          TextFormField(
                            controller: password,
                            style: const TextStyle(color: Colors.black87),
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Image.asset('images/passwordicon.png', height: 20, width: 20),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xff0d47a1)),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Password cannot be empty';
                              if (v.length < 15) return 'Password must be at least 15 characters total';

                              final uppercaseCount = v.replaceAll(RegExp(r'[^A-Z]'), '').length;
                              if (uppercaseCount != 1) return 'Must contain exactly 1 uppercase letter';

                              final specialCharCount = v.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '').length;
                              if (specialCharCount != 1) return 'Must contain exactly 1 special character';

                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Password Strength Gauge
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Password Strength:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(
                                    _strengthText,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _strengthColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: _strengthProgress,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                                minHeight: 5,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 6. Confirm Password
                          TextFormField(
                            controller: confirmPassword,
                            style: const TextStyle(color: Colors.black87),
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              hintText: 'Confirm Password',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Image.asset('images/passwordicon.png', height: 20, width: 20),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xff0d47a1)),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Please confirm your password';
                              if (v != password.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // 7. Data Privacy Consent Checkbox
                          FormField<bool>(
                            initialValue: _isDpaAccepted,
                            validator: (value) => _isDpaAccepted ? null : 'Required field',
                            builder: (formFieldState) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: _isDpaAccepted,
                                          activeColor: const Color(0xff0d47a1),
                                          onChanged: (val) {
                                            setState(() {
                                              _isDpaAccepted = val ?? false;
                                              formFieldState.didChange(_isDpaAccepted);
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          "I agree to the collection and processing of my personal data for emergency reporting.",
                                          style: TextStyle(color: Colors.black87, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (formFieldState.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 36.0, top: 4.0),
                                      child: Text(
                                        formFieldState.errorText ?? '',
                                        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // 8. Submit Button
                          ElevatedButton(
                            onPressed: signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff0d47a1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Register Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}