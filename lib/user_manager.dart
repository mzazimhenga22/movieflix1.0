import 'package:flutter/foundation.dart';

class UserManager {
  static final UserManager instance = UserManager._();

  ValueNotifier<Map<String, dynamic>?> currentUser = ValueNotifier(null);
  ValueNotifier<Map<String, dynamic>?> currentProfile = ValueNotifier(null);

  UserManager._();

  void updateUser(Map<String, dynamic>? user) {
    if (user != null) {
      // Ensure user has required fields and uses Firebase UID as id
      final updatedUser = {
        'id': user['id']?.toString(), // Ensure String ID
        'username': user['username'] ?? 'User',
        'email': user['email'] ?? '',
        'photoURL': user['photoURL'],
      };
      currentUser.value = updatedUser;
      debugPrint('✅ User updated: ${updatedUser['id']}');
    } else {
      currentUser.value = null;
      debugPrint('✅ User cleared');
    }
  }

  void updateProfile(Map<String, dynamic>? profile) {
    if (profile != null) {
      // Ensure profile has required fields
      final updatedProfile = {
        'id': profile['id']?.toString(), // Ensure String ID
        'user_id': profile['user_id']?.toString(),
        'name': profile['name'] ?? 'Profile',
        'avatar': profile['avatar'] ??
            'https://source.unsplash.com/random/200x200/?face',
        'backgroundImage': profile['backgroundImage'],
        'pin': profile['pin'],
        'locked': profile['locked'] ?? 0,
        'preferences': profile['preferences'] ?? '',
      };
      currentProfile.value = updatedProfile;
      debugPrint('✅ Profile updated: ${updatedProfile['id']}');
    } else {
      currentProfile.value = null;
      debugPrint('✅ Profile cleared');
    }
  }

  void clearUser() {
    currentUser.value = null;
    currentProfile.value = null;
    debugPrint('✅ User and profile cleared');
  }
}
