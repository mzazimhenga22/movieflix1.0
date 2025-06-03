import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _authTokenKey = 'session_token';
  static const _authTokenTimestampKey = 'session_expires_at';
  static const _userIdKey = 'session_user_id';

  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
    final expirationDate = DateTime.now().add(const Duration(days: 5));
    await prefs.setInt(
        _authTokenTimestampKey, expirationDate.millisecondsSinceEpoch);
    debugPrint('✅ Auth token saved, expires at: $expirationDate');
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  static Future<int?> getAuthTokenTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_authTokenTimestampKey);
  }

  static Future<String?> getSessionUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<void> saveSessionUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    debugPrint('✅ Session user ID saved: $userId');
  }

  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_authTokenTimestampKey);
    await prefs.remove(_userIdKey);
    debugPrint('✅ Auth token and session data cleared');
  }
}
