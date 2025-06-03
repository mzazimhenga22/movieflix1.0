// lib/helpers/movie_account_helper.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movie_app/database/auth_database.dart';

class MovieAccountHelper {
  /// Checks if the movie account exists.
  /// It first looks for the stored email in SharedPreferences and then queries the database.
  static Future<bool> doesMovieAccountExist() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('currentUserEmail');
    if (email == null) return false;
    final userData = await AuthDatabase.instance.getUserByEmail(email);
    return userData != null;
  }

  /// Retrieves the movie account data from the database, if available.
  static Future<Map<String, dynamic>?> getMovieAccountData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('currentUserEmail');
    if (email == null) return null;
    final userData = await AuthDatabase.instance.getUserByEmail(email);
    return userData;
  }
}
