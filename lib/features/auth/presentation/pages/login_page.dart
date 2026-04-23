import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'package:movieswipe/features/auth/presentation/pages/register_page.dart';

/// Premium login page with glassmorphism, animated feedback, and forgot password
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _showSuccess = false;

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
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    final success = await authProvider.signIn(
      _identifierController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _showSuccess = true);
      // Brief success animation before navigation takes over
      await Future.delayed(const Duration(milliseconds: 800));
    } else {
      // Shake the form on error
      _shakeController.forward(from: 0);
    }
  }

  void _showForgotPasswordSheet() {
    final emailController = TextEditingController();
    bool isSent = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a2e).withValues(alpha: 0.92),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28)),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle bar
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Icon(
                          isSent
                              ? Icons.mark_email_read_rounded
                              : Icons.lock_reset_rounded,
                          size: 48,
                          color: isSent
                              ? const Color(0xFF27AE60)
                              : const Color(0xFFE94560),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isSent
                              ? 'E-posta Gönderildi!'
                              : 'Şifreni Sıfırla',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isSent
                              ? 'Şifre sıfırlama bağlantısı e-posta adresine gönderildi. Gelen kutunu kontrol et.'
                              : 'Kayıtlı e-posta adresini gir, sana şifre sıfırlama bağlantısı gönderelim.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!isSent) ...[
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'E-posta adresin',
                              hintStyle: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.3)),
                              prefixIcon: Icon(Icons.email_outlined,
                                  color:
                                      Colors.white.withValues(alpha: 0.5)),
                              filled: true,
                              fillColor:
                                  Colors.white.withValues(alpha: 0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE94560), width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (emailController.text.trim().isEmpty) {
                                  return;
                                }
                                final auth = Provider.of<AuthProvider>(
                                    context,
                                    listen: false);
                                final success = await auth.resetPassword(
                                    emailController.text.trim());
                                if (success) {
                                  setSheetState(() => isSent = true);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE94560),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Sıfırlama Bağlantısı Gönder',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                    color: Colors.white
                                        .withValues(alpha: 0.3)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Tamam',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
              top: -80,
              right: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE94560).withValues(alpha: 0.15),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
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
                          // Animated Logo
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutBack,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE94560),
                                    Color(0xFFEC4899),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE94560)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.movie_filter_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'MovieSwipe',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Swipe. Discover. Enjoy.',
                            style: TextStyle(
                              fontSize: 15,
                              color:
                                  Colors.white.withValues(alpha: 0.5),
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 44),

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
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE94560)
                                                .withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons
                                                  .error_outline_rounded,
                                              color: Color(0xFFE94560),
                                              size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            auth.errorMessage!,
                                            style: const TextStyle(
                                              color: Color(0xFFE94560),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => auth.clearError(),
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: const Color(0xFFE94560)
                                                .withValues(alpha: 0.6),
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
                                        TextFormField(
                                          controller:
                                              _identifierController,
                                          keyboardType: TextInputType
                                              .emailAddress,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: _inputDecoration(
                                            label:
                                                'E-posta veya Kullanıcı Adı',
                                            icon: Icons.person_outline,
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'E-posta veya kullanıcı adı gerekli';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller:
                                              _passwordController,
                                          obscureText:
                                              _obscurePassword,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: _inputDecoration(
                                            label: 'Şifre',
                                            icon: Icons.lock_outlined,
                                            suffix: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons
                                                        .visibility_off_rounded
                                                    : Icons
                                                        .visibility_rounded,
                                                color: Colors.white54,
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
                                            return null;
                                          },
                                          onFieldSubmitted: (_) =>
                                              _handleLogin(),
                                        ),

                                        // Forgot password link
                                        Align(
                                          alignment:
                                              Alignment.centerRight,
                                          child: TextButton(
                                            onPressed:
                                                _showForgotPasswordSheet,
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.only(
                                                      top: 12),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Text(
                                              'Şifremi Unuttum',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(
                                                        alpha: 0.5),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 24),

                                        // Login button
                                        SizedBox(
                                          width: double.infinity,
                                          height: 56,
                                          child: ElevatedButton(
                                            onPressed: auth.isLoading
                                                ? null
                                                : _handleLogin,
                                            style:
                                                ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(
                                                      0xFFE94560),
                                              foregroundColor:
                                                  Colors.white,
                                              disabledBackgroundColor:
                                                  const Color(
                                                          0xFFE94560)
                                                      .withValues(
                                                          alpha: 0.4),
                                              shape:
                                                  RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(16),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: auth.isLoading
                                                ? const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child:
                                                        CircularProgressIndicator(
                                                      color:
                                                          Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Giriş Yap',
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight
                                                              .bold,
                                                      letterSpacing: 0.5,
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

                          // Register link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Hesabın yok mu? ',
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  auth.clearError();
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      pageBuilder: (context2, a1, a2) =>
                                          const RegisterPage(),
                                      transitionsBuilder:
                                          (context3, animation, a3, child) {
                                        return SlideTransition(
                                          position: Tween<Offset>(
                                            begin:
                                                const Offset(1.0, 0),
                                            end: Offset.zero,
                                          ).animate(CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutCubic,
                                          )),
                                          child: child,
                                        );
                                      },
                                      transitionDuration:
                                          const Duration(
                                              milliseconds: 400),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Kayıt Ol',
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

            // Success overlay
            if (_showSuccess)
              AnimatedOpacity(
                opacity: _showSuccess ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: const Color(0xFF0F0F1E).withValues(alpha: 0.9),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                            scale: value, child: child);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF27AE60)
                                  .withValues(alpha: 0.2),
                              border: Border.all(
                                  color: const Color(0xFF27AE60),
                                  width: 3),
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Color(0xFF27AE60), size: 48),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Hoş Geldin! 🎬',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
}
