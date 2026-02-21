import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';

/// Username selection page shown after registration
class UsernamePage extends StatefulWidget {
  const UsernamePage({super.key});

  @override
  State<UsernamePage> createState() => _UsernamePageState();
}

class _UsernamePageState extends State<UsernamePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  Timer? _debounceTimer;
  bool _isChecking = false;
  bool? _isAvailable;

  @override
  void dispose() {
    _usernameController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();

    if (value.length < 3) {
      setState(() {
        _isAvailable = null;
        _isChecking = false;
      });
      return;
    }

    // Validate format locally first
    final isValidFormat = RegExp(r'^[a-zA-Z0-9]{3,20}$').hasMatch(value);
    if (!isValidFormat) {
      setState(() {
        _isAvailable = null;
        _isChecking = false;
      });
      return;
    }

    setState(() => _isChecking = true);

    // Debounce: wait 500ms before checking
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final available = await auth.isUsernameAvailable(value);
      if (mounted && _usernameController.text == value) {
        setState(() {
          _isAvailable = available;
          _isChecking = false;
        });
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isAvailable != true) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.setUsername(_usernameController.text.trim());
    // Navigation is handled by main.dart's Consumer<AuthProvider>
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar preview
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: const Color(0xFFe94560),
                        child: Text(
                          _usernameController.text.isNotEmpty
                              ? _usernameController.text[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Kullanıcı Adını Seç',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Diğer kullanıcılar seni bu isimle görecek',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Error message
                      if (auth.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  auth.errorMessage!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _usernameController,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18),
                              textAlign: TextAlign.center,
                              onChanged: _onUsernameChanged,
                              decoration: InputDecoration(
                                hintText: 'kullaniciadi',
                                hintStyle: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.3)),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Text(
                                    '@',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                prefixIconConstraints:
                                    const BoxConstraints(minWidth: 32),
                                suffixIcon: _buildSuffixIcon(),
                                filled: true,
                                fillColor:
                                    Colors.white.withValues(alpha: 0.08),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: _isAvailable == true
                                        ? Colors.green
                                        : _isAvailable == false
                                            ? Colors.red
                                            : const Color(0xFFe94560),
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      const BorderSide(color: Colors.red),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: Colors.red, width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Kullanıcı adı gerekli';
                                }
                                if (value.length < 3) {
                                  return 'En az 3 karakter olmalı';
                                }
                                if (value.length > 20) {
                                  return 'En fazla 20 karakter olabilir';
                                }
                                if (!RegExp(r'^[a-zA-Z0-9]+$')
                                    .hasMatch(value)) {
                                  return 'Sadece harf ve rakam kullanılabilir';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),

                            // Availability indicator text
                            if (_isAvailable != null)
                              Text(
                                _isAvailable!
                                    ? '✅ Bu kullanıcı adı müsait!'
                                    : '❌ Bu kullanıcı adı alınmış',
                                style: TextStyle(
                                  color: _isAvailable!
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 13,
                                ),
                              ),

                            const SizedBox(height: 32),

                            // Submit button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: auth.isLoading ||
                                        _isAvailable != true
                                    ? null
                                    : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFe94560),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFFe94560)
                                      .withValues(alpha: 0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Devam Et',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isChecking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }
    if (_isAvailable == true) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (_isAvailable == false) {
      return const Icon(Icons.cancel, color: Colors.red);
    }
    return null;
  }
}
