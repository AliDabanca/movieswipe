import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication provider using Supabase Auth
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = true;
  String? _errorMessage;

  AuthProvider() {
    _init();
  }

  // Getters
  User? get user => _user;
  String? get currentUserId => _user?.id;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get userEmail => _user?.email ?? '';

  SupabaseClient get _client => Supabase.instance.client;

  void _init() {
    // Check current session
    _user = _client.auth.currentUser;
    _isLoading = false;
    notifyListeners();

    // Listen to auth state changes
    _client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  /// Sign up with email and password
  Future<bool> signUp(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
    _user = null;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
