import 'package:alertu_flutter/wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'email_sending.dart';
import 'emergency_contacts.dart';

final completeProfileLoadingProvider = StateProvider<bool>((ref) => false);

class CompleteProfile extends ConsumerStatefulWidget {
  final User user;
  const CompleteProfile({super.key, required this.user});

  @override
  ConsumerState<CompleteProfile> createState() => _CompleteProfileState();
}

class _CompleteProfileState extends ConsumerState<CompleteProfile> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController name;
  final TextEditingController address = TextEditingController();
  String completePhoneNumber = "";
  bool _isPhoneValid = false;
  bool _isDpaAccepted = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.user.displayName);
  }

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    super.dispose();
  }

  void _showSnackBar(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xff0d47a1),
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

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate() || !_isPhoneValid || completePhoneNumber.isEmpty) {
      _showSnackBar("Incomplete Form", "Please fix the errors in the form before submitting.");
      return;
    }

    if (!_isDpaAccepted) {
      _showSnackBar("Consent Required", "Please check the consent box to complete your registration.");
      return;
    }

    ref.read(completeProfileLoadingProvider.notifier).state = true;

    try {
      String customProfileData = "${name.text.trim()}||$completePhoneNumber||${address.text.trim()}";
      await widget.user.updateDisplayName(customProfileData);
      await widget.user.reload();

      await FirebaseFirestore.instance.collection('citizens').doc(widget.user.uid).set({
        'id': widget.user.uid,
        'fullName': name.text.trim(),
        'email': widget.user.email?.trim() ?? '',
        'phoneNumber': completePhoneNumber,
        'zone': address.text.trim(),
        'status': 'Active',
        'dpaAccepted': true,
        'dpaAcceptedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Error", "Could not save your profile. Please try again.");
      }
    } finally {
      if (mounted) {
        ref.read(completeProfileLoadingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(completeProfileLoadingProvider);

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
        body: SafeArea(
          child: isLoading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0d47a1)),
            ),
          )
              : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Complete Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff0d47a1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please enter your remaining details to finish setting up your account.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: name,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(hintText: 'Full Name'),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Please enter your full name'
                            : null,
                      ),
                      const SizedBox(height: 14),
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
                      TextFormField(
                        controller: address,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(hintText: 'Address'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter your address'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      FormField<bool>(
                        initialValue: _isDpaAccepted,
                        validator: (value) => _isDpaAccepted ? null : 'Required',
                        builder: (formFieldState) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      "I agree to allow AlertU to store and process my personal details (Name, Contact Number, and Address) solely for emergency response and identity verification.",
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 13,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (formFieldState.hasError)
                                Padding(
                                  padding: const EdgeInsets.only(left: 36.0, top: 4.0),
                                  child: Text(
                                    formFieldState.errorText ?? '',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      ElevatedButton(
                        onPressed: saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff0d47a1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Finish Setup",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}