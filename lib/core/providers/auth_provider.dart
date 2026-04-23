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
  String? _coverPhotoUrl;
  List<int> _pinnedMovieIds = [];
  bool _hasProfile = false;
  bool _profileChecked = false;
  bool _needsEmailConfirmation = false;

  /// Guards against concurrent auth operations
  bool _isAuthOperationInProgress = false;

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
  String? get coverPhotoUrl => _coverPhotoUrl;
  List<int> get pinnedMovieIds => _pinnedMovieIds;
  bool get hasProfile => _hasProfile;
  bool get profileChecked => _profileChecked;
  bool get needsEmailConfirmation => _needsEmailConfirmation;

  SupabaseClient get _client => Supabase.instance.client;

  void _init() {
    _user = _client.auth.currentUser;
    
    if (_user != null) {
      _isLoading = true;
      _checkProfile();
    } else {
      _isLoading = false;
      _profileChecked = true;
      notifyListeners();
    }

    _client.auth.onAuthStateChange.listen((data) {
      final newUser = data.session?.user;
      
      if (newUser == null && _user != null) {
        _user = null;
        _username = null;
        _displayName = null;
        _avatarUrl = null;
        _coverPhotoUrl = null;
        _hasProfile = false;
        _profileChecked = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (newUser != null && (newUser.id != _user?.id || !_profileChecked)) {
        _user = newUser;
        _needsEmailConfirmation = false;
        _profileChecked = false;
        _checkProfile();
      }
    });
  }

  Future<void> _checkProfile() async {
    if (_user == null) {
      _profileChecked = true;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final response = await _client
          .from('profiles')
          .select('username, display_name, avatar_url, cover_photo_url, pinned_movie_ids')
          .eq('id', _user!.id)
          .maybeSingle();

      if (response != null) {
        _username = response['username'] as String?;
        _displayName = response['display_name'] as String?;
        _avatarUrl = response['avatar_url'] as String?;
        _coverPhotoUrl = response['cover_photo_url'] as String?;
        _pinnedMovieIds = List<int>.from(response['pinned_movie_ids'] ?? []);
        _hasProfile = _username != null;
      } else {
        _hasProfile = false;
        _username = null;
      }
    } catch (e) {
      debugPrint('Profile check error: $e');
      _hasProfile = false;
    } finally {
      _profileChecked = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if username is available (RPC call)
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

  Future<bool> signIn(String identifier, String password) async {
    if (_isAuthOperationInProgress) return false;
    _isAuthOperationInProgress = true;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String email = identifier.trim();
      if (!email.contains('@')) {
        final resolvedEmail = await _client.rpc(
          'get_email_from_username',
          params: {'p_username': email},
        );

        if (resolvedEmail == null) {
          _errorMessage = 'Kullanıcı adı bulunamadı';
          _isLoading = false;
          _isAuthOperationInProgress = false;
          notifyListeners();
          return false;
        }
        email = resolvedEmail as String;
      }

      await _client.auth.signInWithPassword(email: email, password: password);
      _needsEmailConfirmation = false;
      _isAuthOperationInProgress = false;
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      _isLoading = false;
      _isAuthOperationInProgress = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _mapGenericError(e);
      _isLoading = false;
      _isAuthOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    if (_isAuthOperationInProgress) return false;
    _isAuthOperationInProgress = true;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.auth.signUp(email: email, password: password);
      if (response.user != null && response.user!.emailConfirmedAt == null) {
        await _client.auth.signOut();
        _needsEmailConfirmation = true;
        _isLoading = false;
        _isAuthOperationInProgress = false;
        notifyListeners();
        return true;
      }
      _isAuthOperationInProgress = false;
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      _isLoading = false;
      _isAuthOperationInProgress = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _mapGenericError(e);
      _isLoading = false;
      _isAuthOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setUsername(String username) async {
    if (_user == null) return false;
    if (_isAuthOperationInProgress) return false;
    _isAuthOperationInProgress = true;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.from('profiles').upsert({'id': _user!.id, 'username': username});
      _username = username;
      _hasProfile = true;
      _isLoading = false;
      _isAuthOperationInProgress = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Hata oluştu. Tekrar deneyin.';
      _isLoading = false;
      _isAuthOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }

  /// RESTORED: Update profile directly via Supabase
  Future<bool> updateProfile({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? coverPhotoUrl,
    List<int>? pinnedMovieIds,
  }) async {
    if (_user == null) return false;
    _errorMessage = null;

    try {
      final updateData = <String, dynamic>{};
      if (username != null) updateData['username'] = username;
      if (displayName != null) updateData['display_name'] = displayName;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      if (coverPhotoUrl != null) updateData['cover_photo_url'] = coverPhotoUrl;
      if (pinnedMovieIds != null) updateData['pinned_movie_ids'] = pinnedMovieIds;

      if (updateData.isEmpty) return true;

      await _client.from('profiles').update(updateData).eq('id', _user!.id);

      // Local State Update
      if (username != null) _username = username;
      if (displayName != null) _displayName = displayName;
      if (avatarUrl != null) _avatarUrl = avatarUrl;
      if (coverPhotoUrl != null) _coverPhotoUrl = coverPhotoUrl;
      if (pinnedMovieIds != null) _pinnedMovieIds = pinnedMovieIds;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Profil güncellenemedi: $e';
      notifyListeners();
      return false;
    }
  }

  void dismissEmailConfirmation() {
    _needsEmailConfirmation = false;
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Hata oluştu';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    _user = null;
    _username = null;
    _displayName = null;
    _avatarUrl = null;
    _coverPhotoUrl = null;
    _hasProfile = false;
    _profileChecked = true;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) return 'E-posta veya şifre hatalı.';
    if (msg.contains('email not confirmed')) return 'E-posta doğrulanmadı.';
    if (msg.contains('already registered')) return 'Bu e-posta zaten kayıtlı.';
    return 'Hata: ${e.message}';
  }

  String _mapGenericError(dynamic e) {
    return 'Bir bağlantı hatası oluştu.';
  }
}
