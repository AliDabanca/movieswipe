import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';

/// Premium username selection page shown after registration
class UsernamePage extends StatefulWidget {
  const UsernamePage({super.key});

  @override
  State<UsernamePage> createState() => _UsernamePageState();
}

class _UsernamePageState extends State<UsernamePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  Timer? _debounceTimer;
  bool _isChecking = false;
  bool? _isAvailable;

  late AnimationController _avatarAnimController;
  late Animation<double> _avatarScaleAnimation;

  @override
  void initState() {
    super.initState();
    _avatarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _avatarScaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _avatarAnimController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _debounceTimer?.cancel();
    _avatarAnimController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();

    // Trigger avatar animation on first char
    if (value.isNotEmpty) {
      _avatarAnimController.forward(from: 0);
      _avatarScaleAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 1),
      ]).animate(CurvedAnimation(
        parent: _avatarAnimController,
        curve: Curves.easeInOut,
      ));
    }

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
              top: -50,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE94560).withValues(alpha: 0.12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(),
                ),
              ),
            ),
            Positioned(
              bottom: 150,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4361EE).withValues(alpha: 0.08),
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
                          // Animated avatar preview
                          AnimatedBuilder(
                            animation: _avatarScaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _avatarScaleAnimation.value,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _isAvailable == true
                                      ? [
                                          const Color(0xFF27AE60),
                                          const Color(0xFF2ECC71),
                                        ]
                                      : [
                                          const Color(0xFFE94560),
                                          const Color(0xFFEC4899),
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isAvailable == true
                                            ? const Color(0xFF27AE60)
                                            : const Color(0xFFE94560))
                                        .withValues(alpha: 0.3),
                                    blurRadius: 25,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  transitionBuilder:
                                      (child, animation) {
                                    return ScaleTransition(
                                        scale: animation, child: child);
                                  },
                                  child: Text(
                                    _usernameController.text.isNotEmpty
                                        ? _usernameController.text[0]
                                            .toUpperCase()
                                        : '?',
                                    key: ValueKey(
                                        _usernameController.text.isEmpty
                                            ? '?'
                                            : _usernameController
                                                .text[0]),
                                    style: const TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),
                          const Text(
                            'Kullanıcı Adını Seç',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Diğer kullanıcılar seni bu isimle görecek',
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 40),

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
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('no-error')),
                          ),

                          // Glass Form Card
                          ClipRRect(
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
                                            _usernameController,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18),
                                        textAlign: TextAlign.center,
                                        onChanged:
                                            _onUsernameChanged,
                                        decoration: InputDecoration(
                                          hintText: 'kullaniciadi',
                                          hintStyle: TextStyle(
                                              color: Colors.white
                                                  .withValues(
                                                      alpha: 0.25)),
                                          prefixIcon: Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    left: 16),
                                            child: Text(
                                              '@',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.white
                                                    .withValues(
                                                        alpha: 0.4),
                                              ),
                                            ),
                                          ),
                                          prefixIconConstraints:
                                              const BoxConstraints(
                                                  minWidth: 32),
                                          suffixIcon:
                                              _buildSuffixIcon(),
                                          filled: true,
                                          fillColor: Colors.white
                                              .withValues(
                                                  alpha: 0.06),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    16),
                                            borderSide:
                                                BorderSide.none,
                                          ),
                                          focusedBorder:
                                              OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    16),
                                            borderSide: BorderSide(
                                              color: _isAvailable ==
                                                      true
                                                  ? const Color(
                                                      0xFF27AE60)
                                                  : _isAvailable ==
                                                          false
                                                      ? const Color(
                                                          0xFFE74C3C)
                                                      : const Color(
                                                          0xFFE94560),
                                              width: 1.5,
                                            ),
                                          ),
                                          errorBorder:
                                              OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    16),
                                            borderSide:
                                                const BorderSide(
                                                    color:
                                                        Colors.red),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    16),
                                            borderSide:
                                                const BorderSide(
                                                    color: Colors.red,
                                                    width: 1.5),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.isEmpty) {
                                            return 'Kullanıcı adı gerekli';
                                          }
                                          if (value.length < 3) {
                                            return 'En az 3 karakter olmalı';
                                          }
                                          if (value.length > 20) {
                                            return 'En fazla 20 karakter olabilir';
                                          }
                                          if (!RegExp(
                                                  r'^[a-zA-Z0-9]+$')
                                              .hasMatch(value)) {
                                            return 'Sadece harf ve rakam kullanılabilir';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),

                                      // Availability indicator text — animated
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                            milliseconds: 250),
                                        transitionBuilder:
                                            (child, animation) {
                                          return FadeTransition(
                                              opacity: animation,
                                              child: child);
                                        },
                                        child: _isAvailable != null
                                            ? Container(
                                                key: ValueKey(
                                                    _isAvailable),
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal:
                                                            16,
                                                        vertical: 10),
                                                decoration:
                                                    BoxDecoration(
                                                  color: (_isAvailable!
                                                          ? const Color(
                                                              0xFF27AE60)
                                                          : const Color(
                                                              0xFFE74C3C))
                                                      .withValues(
                                                          alpha:
                                                              0.1),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              12),
                                                  border: Border.all(
                                                    color: (_isAvailable!
                                                            ? const Color(
                                                                0xFF27AE60)
                                                            : const Color(
                                                                0xFFE74C3C))
                                                        .withValues(
                                                            alpha:
                                                                0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize
                                                          .min,
                                                  children: [
                                                    Icon(
                                                      _isAvailable!
                                                          ? Icons
                                                              .check_circle_rounded
                                                          : Icons
                                                              .cancel_rounded,
                                                      size: 18,
                                                      color: _isAvailable!
                                                          ? const Color(
                                                              0xFF27AE60)
                                                          : const Color(
                                                              0xFFE74C3C),
                                                    ),
                                                    const SizedBox(
                                                        width: 8),
                                                    Text(
                                                      _isAvailable!
                                                          ? 'Bu isim müsait! 🎉'
                                                          : 'Bu isim zaten alınmış',
                                                      style:
                                                          TextStyle(
                                                        color: _isAvailable!
                                                            ? const Color(
                                                                0xFF27AE60)
                                                            : const Color(
                                                                0xFFE74C3C),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight
                                                                .w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : const SizedBox.shrink(
                                                key: ValueKey(
                                                    'no-status')),
                                      ),

                                      const SizedBox(height: 28),

                                      // Submit button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 56,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 300),
                                          child: ElevatedButton(
                                            onPressed: auth.isLoading ||
                                                    _isAvailable !=
                                                        true
                                                ? null
                                                : _handleSubmit,
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
                                                              0.25),
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
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      const Text(
                                                        'Devam Et',
                                                        style:
                                                            TextStyle(
                                                          fontSize:
                                                              17,
                                                          fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                          letterSpacing:
                                                              0.5,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          width: 8),
                                                      Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 20,
                                                        color: _isAvailable ==
                                                                true
                                                            ? Colors
                                                                .white
                                                            : Colors
                                                                .white
                                                                .withValues(
                                                                    alpha:
                                                                        0.3),
                                                      ),
                                                    ],
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

                          const SizedBox(height: 20),

                          // Tip text
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.tips_and_updates_rounded,
                                    size: 18,
                                    color: Colors.amber
                                        .withValues(alpha: 0.6)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Sadece harf ve rakam, 3-20 karakter arası',
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.4),
                                      fontSize: 12,
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
          ],
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
      return const Icon(Icons.check_circle_rounded,
          color: Color(0xFF27AE60));
    }
    if (_isAvailable == false) {
      return const Icon(Icons.cancel_rounded, color: Color(0xFFE74C3C));
    }
    return null;
  }
}
