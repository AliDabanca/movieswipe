import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';

/// Premium register page with password strength meter and animated feedback
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Password strength tracking
  double _passwordStrength = 0.0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = Colors.transparent;
  bool _passwordsMatch = true;
  bool _showEmailConfirmation = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    _passwordController.addListener(_evaluatePasswordStrength);
    _confirmPasswordController.addListener(_checkPasswordsMatch);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _evaluatePasswordStrength() {
    final password = _passwordController.text;
    double strength = 0;

    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthLabel = '';
        _passwordStrengthColor = Colors.transparent;
      });
      return;
    }

    // Length score
    if (password.length >= 6) strength += 0.2;
    if (password.length >= 8) strength += 0.1;
    if (password.length >= 12) strength += 0.1;

    // Complexity checks
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.1;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.2;

    strength = strength.clamp(0.0, 1.0);

    String label;
    Color color;

    if (strength < 0.3) {
      label = 'Çok Zayıf';
      color = const Color(0xFFE74C3C);
    } else if (strength < 0.5) {
      label = 'Zayıf';
      color = const Color(0xFFE67E22);
    } else if (strength < 0.7) {
      label = 'Orta';
      color = const Color(0xFFF39C12);
    } else if (strength < 0.9) {
      label = 'Güçlü';
      color = const Color(0xFF27AE60);
    } else {
      label = 'Çok Güçlü';
      color = const Color(0xFF2ECC71);
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = label;
      _passwordStrengthColor = color;
    });

    // Also re-check password match
    _checkPasswordsMatch();
  }

  void _checkPasswordsMatch() {
    if (_confirmPasswordController.text.isEmpty) {
      setState(() => _passwordsMatch = true);
      return;
    }
    setState(() {
      _passwordsMatch =
          _passwordController.text == _confirmPasswordController.text;
    });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    final success = await authProvider.signUp(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success && authProvider.needsEmailConfirmation) {
      // Show the email confirmation screen
      setState(() => _showEmailConfirmation = true);
    } else if (!success) {
      _shakeController.forward(from: 0);
    }
    // If success and NOT needsEmailConfirmation (email confirm disabled in Supabase),
    // navigation is handled by main.dart Consumer<AuthProvider>
  }

  @override
  Widget build(BuildContext context) {
    // Show email confirmation screen
    if (_showEmailConfirmation) {
      return _buildEmailConfirmationScreen();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF0F0F1E),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative blur spheres
            Positioned(
              top: -60,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4361EE).withValues(alpha: 0.12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(),
                ),
              ),
            ),
            Positioned(
              bottom: 50,
              right: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE94560).withValues(alpha: 0.1),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Header
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutBack,
                            builder: (context, value, child) {
                              return Transform.scale(
                                  scale: value, child: child);
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4361EE),
                                    Color(0xFFE94560),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4361EE)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 25,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_add_rounded,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Hesap Oluştur',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Film keşfine başla! 🍿',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Error message — animated
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, -0.3),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: FadeTransition(
                                    opacity: animation, child: child),
                              );
                            },
                            child: auth.errorMessage != null
                                ? Container(
                                    key: ValueKey(auth.errorMessage),
                                    padding: const EdgeInsets.all(14),
                                    margin:
                                        const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE94560)
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE94560)
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color:
                                                const Color(0xFFE94560)
                                                    .withValues(
                                                        alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons
                                                  .error_outline_rounded,
                                              color:
                                                  Color(0xFFE94560),
                                              size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            auth.errorMessage!,
                                            style: const TextStyle(
                                              color:
                                                  Color(0xFFE94560),
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () =>
                                              auth.clearError(),
                                          child: Icon(
                                            Icons.close_rounded,
                                            color:
                                                const Color(0xFFE94560)
                                                    .withValues(
                                                        alpha: 0.6),
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('no-error')),
                          ),

                          // Glass Form Card
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset:
                                    Offset(_shakeAnimation.value, 0),
                                child: child,
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.05),
                                    borderRadius:
                                        BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        // Email
                                        TextFormField(
                                          controller:
                                              _emailController,
                                          keyboardType: TextInputType
                                              .emailAddress,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration:
                                              _inputDecoration(
                                            label: 'E-posta',
                                            icon:
                                                Icons.email_outlined,
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'E-posta gerekli';
                                            }
                                            final emailRegex =
                                                RegExp(
                                                    r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');
                                            if (!emailRegex.hasMatch(
                                                value.trim())) {
                                              return 'Geçerli bir e-posta adresi girin';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),

                                        // Password
                                        TextFormField(
                                          controller:
                                              _passwordController,
                                          obscureText:
                                              _obscurePassword,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration:
                                              _inputDecoration(
                                            label: 'Şifre',
                                            icon:
                                                Icons.lock_outlined,
                                            suffix: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons
                                                        .visibility_off_rounded
                                                    : Icons
                                                        .visibility_rounded,
                                                color:
                                                    Colors.white54,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword =
                                                      !_obscurePassword;
                                                });
                                              },
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Şifre gerekli';
                                            }
                                            if (value.length < 6) {
                                              return 'Şifre en az 6 karakter olmalı';
                                            }
                                            return null;
                                          },
                                        ),

                                        // Password Strength Indicator
                                        if (_passwordController
                                            .text.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          _buildPasswordStrengthBar(),
                                          const SizedBox(height: 4),
                                          _buildPasswordRequirements(),
                                        ],

                                        const SizedBox(height: 16),

                                        // Confirm password
                                        TextFormField(
                                          controller:
                                              _confirmPasswordController,
                                          obscureText:
                                              _obscureConfirmPassword,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration:
                                              _inputDecoration(
                                            label: 'Şifre Tekrar',
                                            icon:
                                                Icons.lock_outlined,
                                            suffix: Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                // Match indicator
                                                if (_confirmPasswordController
                                                    .text.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets
                                                            .only(
                                                            right: 4),
                                                    child: Icon(
                                                      _passwordsMatch
                                                          ? Icons
                                                              .check_circle_rounded
                                                          : Icons
                                                              .cancel_rounded,
                                                      color: _passwordsMatch
                                                          ? const Color(
                                                              0xFF27AE60)
                                                          : const Color(
                                                              0xFFE74C3C),
                                                      size: 20,
                                                    ),
                                                  ),
                                                IconButton(
                                                  icon: Icon(
                                                    _obscureConfirmPassword
                                                        ? Icons
                                                            .visibility_off_rounded
                                                        : Icons
                                                            .visibility_rounded,
                                                    color:
                                                        Colors.white54,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _obscureConfirmPassword =
                                                          !_obscureConfirmPassword;
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value !=
                                                _passwordController
                                                    .text) {
                                              return 'Şifreler eşleşmiyor';
                                            }
                                            return null;
                                          },
                                        ),

                                        // Match hint
                                        if (_confirmPasswordController
                                                .text.isNotEmpty &&
                                            !_passwordsMatch)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    top: 8),
                                            child: Row(
                                              children: [
                                                Icon(
                                                    Icons
                                                        .info_outline_rounded,
                                                    size: 14,
                                                    color: const Color(
                                                            0xFFE74C3C)
                                                        .withValues(
                                                            alpha:
                                                                0.8)),
                                                const SizedBox(
                                                    width: 6),
                                                Text(
                                                  'Şifreler eşleşmiyor',
                                                  style: TextStyle(
                                                    color: const Color(
                                                            0xFFE74C3C)
                                                        .withValues(
                                                            alpha:
                                                                0.8),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        const SizedBox(height: 28),

                                        // Register button
                                        SizedBox(
                                          width: double.infinity,
                                          height: 56,
                                          child: ElevatedButton(
                                            onPressed: auth.isLoading
                                                ? null
                                                : _handleRegister,
                                            style: ElevatedButton
                                                .styleFrom(
                                              backgroundColor:
                                                  const Color(
                                                      0xFFE94560),
                                              foregroundColor:
                                                  Colors.white,
                                              disabledBackgroundColor:
                                                  const Color(
                                                          0xFFE94560)
                                                      .withValues(
                                                          alpha:
                                                              0.4),
                                              shape:
                                                  RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                            16),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: auth.isLoading
                                                ? const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: Colors
                                                          .white,
                                                      strokeWidth:
                                                          2.5,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Kayıt Ol',
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight
                                                              .bold,
                                                      letterSpacing:
                                                          0.5,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Back to login
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                'Zaten hesabın var mı? ',
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  auth.clearError();
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'Giriş Yap',
                                  style: TextStyle(
                                    color: Color(0xFFE94560),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Şifre Gücü',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _passwordStrengthLabel,
                key: ValueKey(_passwordStrengthLabel),
                style: TextStyle(
                  color: _passwordStrengthColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 4,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _passwordStrength),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor:
                      Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      _passwordStrengthColor),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    final password = _passwordController.text;
    final requirements = [
      _PasswordReq('En az 6 karakter', password.length >= 6),
      _PasswordReq('Büyük harf (A-Z)', RegExp(r'[A-Z]').hasMatch(password)),
      _PasswordReq('Rakam (0-9)', RegExp(r'[0-9]').hasMatch(password)),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: requirements.map((req) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                req.met
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 14,
                color: req.met
                    ? const Color(0xFF27AE60)
                    : Colors.white.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 4),
              Text(
                req.label,
                style: TextStyle(
                  fontSize: 11,
                  color: req.met
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      prefixIcon:
          Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            const BorderSide(color: Color(0xFFE94560), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: Colors.red.withValues(alpha: 0.6)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 12),
    );
  }

  /// Full-screen "check your email" overlay shown after successful registration
  Widget _buildEmailConfirmationScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF0F0F1E),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative blur sphere
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated mail icon
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                              scale: value, child: child);
                        },
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF27AE60),
                                Color(0xFF2ECC71),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF27AE60)
                                    .withValues(alpha: 0.4),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mark_email_read_rounded,
                            size: 52,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Kayıt Başarılı! 🎉',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'E-posta adresine bir doğrulama bağlantısı gönderdik.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Email display chip
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.email_outlined,
                                    color: Colors.white
                                        .withValues(alpha: 0.5),
                                    size: 20),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _emailController.text.trim(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Steps
                      _buildStepItem(
                        number: '1',
                        text: 'E-posta kutunu kontrol et',
                        isDone: true,
                      ),
                      _buildStepItem(
                        number: '2',
                        text: 'Doğrulama bağlantısına tıkla',
                        isDone: false,
                      ),
                      _buildStepItem(
                        number: '3',
                        text: 'Uygulamaya geri dön ve giriş yap',
                        isDone: false,
                      ),

                      const SizedBox(height: 40),

                      // Go to login button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final auth = Provider.of<AuthProvider>(context,
                                listen: false);
                            auth.dismissEmailConfirmation();
                            // Pop all the way back to login
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          },
                          icon: const Icon(Icons.login_rounded, size: 20),
                          label: const Text(
                            'Giriş Sayfasına Dön',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE94560),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Spam note
                      Text(
                        'E-posta gelmedi mi? Spam klasörünü kontrol et.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required String number,
    required String text,
    required bool isDone,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? const Color(0xFF27AE60).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: isDone
                    ? const Color(0xFF27AE60).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Color(0xFF27AE60))
                  : Text(
                      number,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDone
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordReq {
  final String label;
  final bool met;
  const _PasswordReq(this.label, this.met);
}
