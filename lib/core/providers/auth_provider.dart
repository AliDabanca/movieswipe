import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication provider using Supabase Auth
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = true;
  String? _errorMessage;
  String? _username;
  String? _displayName;
  String? _avatarUrl;
  List<int> _pinnedMovieIds = [];
  bool _hasProfile = false;
  bool _profileChecked = false;

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
  String? get username => _username;
  String? get displayName => _displayName;
  String? get avatarUrl => _avatarUrl;
  List<int> get pinnedMovieIds => _pinnedMovieIds;
  bool get hasProfile => _hasProfile;
  bool get profileChecked => _profileChecked;

  SupabaseClient get _client => Supabase.instance.client;

  void _init() {
    // Check current session
    _user = _client.auth.currentUser;
    _isLoading = false;

    if (_user != null) {
      _checkProfile();
    } else {
      _profileChecked = true;
    }

    notifyListeners();

    // Listen to auth state changes
    _client.auth.onAuthStateChange.listen((data) {
      final previousUser = _user;
      _user = data.session?.user;

      if (_user != null) {
        if (previousUser?.id != _user?.id) {
          _profileChecked = false;
          _checkProfile();
        }
      } else {
        _username = null;
        _hasProfile = false;
        _profileChecked = true;
      }

      notifyListeners();
    });
  }

  /// Check if user has a profile with username
  Future<void> _checkProfile() async {
    try {
      final response = await _client
          .from('profiles')
          .select('username, display_name, avatar_url, pinned_movie_ids')
          .eq('id', _user!.id)
          .maybeSingle();

      if (response != null) {
        _username = response['username'] as String?;
        _displayName = response['display_name'] as String?;
        _avatarUrl = response['avatar_url'] as String?;
        _pinnedMovieIds = List<int>.from(response['pinned_movie_ids'] ?? []);
        _hasProfile = _username != null;
      } else {
        _hasProfile = false;
        _username = null;
        _displayName = null;
        _avatarUrl = null;
        _pinnedMovieIds = [];
      }
    } catch (e) {
      debugPrint('Profile check error: $e');
      _hasProfile = false;
      _username = null;
    }
    _profileChecked = true;
    notifyListeners();
  }

  /// Check if username is available (for real-time validation)
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _client.rpc(
        'check_username_available',
        params: {'p_username': username},
      );
      return response as bool? ?? false;
    } catch (e) {
      debugPrint('Username check error: $e');
      return false;
    }
  }

  /// Set username for current user (creates profile)
  Future<bool> setUsername(String username) async {
    if (_user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.from('profiles').insert({
        'id': _user!.id,
        'username': username,
      });

      _username = username;
      _hasProfile = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        _errorMessage = 'Bu kullanıcı adı zaten alınmış';
      } else if (e.code == '23514') {
        _errorMessage = 'Kullanıcı adı sadece harf ve rakam içerebilir (3-20 karakter)';
      } else {
        _errorMessage = 'Profil oluşturulamadı: ${e.message}';
      }
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
      _hasProfile = false;
      _profileChecked = true;
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

  /// Sign in with email or username and password
  Future<bool> signIn(String identifier, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String email = identifier.trim();

      // If it's not an email, try to resolve as username
      if (!email.contains('@')) {
        final resolvedEmail = await _client.rpc(
          'get_email_from_username',
          params: {'p_username': email},
        );

        if (resolvedEmail == null) {
          _errorMessage = 'Kullanıcı adı bulunamadı';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        email = resolvedEmail as String;
        // Optimistic update: we know they have a profile since we found the email via username
        _username = identifier.trim();
        _hasProfile = true;
        _profileChecked = true;
      } else {
        // If logging in via email, ensure we re-check profile
        _profileChecked = false;
      }

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      _user = response.user;
      _isLoading = false;
      notifyListeners();

      // Profile check happens via auth state change listener
      return _user != null;
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        _errorMessage = 'Hatalı e-posta/kullanıcı adı veya şifre';
      } else {
        _errorMessage = e.message;
      }
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
    _username = null;
    _hasProfile = false;
    notifyListeners();
  }

  /// Update user profile directly via Supabase
  Future<bool> updateProfile({
    String? username,
    String? displayName,
    String? avatarUrl,
    List<int>? pinnedMovieIds,
  }) async {
    if (_user == null) return false;

    _errorMessage = null;
    notifyListeners();

    try {
      final updateData = <String, dynamic>{};
      if (username != null) updateData['username'] = username;
      if (displayName != null) updateData['display_name'] = displayName;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      if (pinnedMovieIds != null) updateData['pinned_movie_ids'] = pinnedMovieIds;

      if (updateData.isEmpty) return true;

      await _client.from('profiles').update(updateData).eq('id', _user!.id);

      // Update local state
      if (username != null) _username = username;
      if (displayName != null) _displayName = displayName;
      if (avatarUrl != null) _avatarUrl = avatarUrl;
      if (pinnedMovieIds != null) _pinnedMovieIds = pinnedMovieIds;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Profil güncellenemedi: $e';
      notifyListeners();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
