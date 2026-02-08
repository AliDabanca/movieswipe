import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple user state provider for multi-user testing
class UserProvider extends ChangeNotifier {
  String? _currentUserId;
  
  String? get currentUserId => _currentUserId;
  
  UserProvider() {
    _loadUserId();
  }
  
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('current_user_id');
    notifyListeners();
  }
  
  Future<void> setUserId(String userId) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', userId);
    notifyListeners();
  }
  
  Future<void> clearUser() async {
    _currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    notifyListeners();
  }
}
