import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:movie_app/session_manager.dart';
import 'package:movie_app/profile_selection_screen.dart';
import 'package:movie_app/signin_screen.dart';
import 'package:movie_app/user_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), _checkAuthStatus);
  }

  Future<void> _storeSession(String userId, String token) async {
    try {
      final expirationDate = DateTime.now().add(const Duration(days: 5));
      await _firestore.collection('sessions').doc(userId).set({
        'userId': userId,
        'token': token,
        'expiresAt': Timestamp.fromDate(expirationDate),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_user_id', userId);
      await prefs.setString('session_token', token);
      await prefs.setInt(
          'session_expires_at', expirationDate.millisecondsSinceEpoch);
      debugPrint('✅ Session saved for user: $userId');
    } catch (e) {
      debugPrint('❌ Error storing session: $e');
      throw e;
    }
  }

  Future<void> _saveUserOffline(
      String userId, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_$userId', userData.toString());
      debugPrint('✅ User data saved offline for user: $userId');
    } catch (e) {
      debugPrint('❌ Error saving user offline: $e');
      throw e;
    }
  }

  Future<void> _checkAuthStatus() async {
    debugPrint('🔍 [_checkAuthStatus] started');

    bool isLoggedIn = false;
    User? user;

    try {
      user = _auth.currentUser;
      if (user == null) {
        debugPrint('ℹ️ No user signed in');
        await SessionManager.clearAuthToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('session_user_id');
        await prefs.remove('session_token');
        await prefs.remove('session_expires_at');
        debugPrint('✅ Cleared stale local session data');
      } else {
        debugPrint('🔍 Checking session for user: ${user.uid}');

        try {
          DocumentSnapshot sessionDoc =
              await _firestore.collection('sessions').doc(user.uid).get();
          if (sessionDoc.exists) {
            Map<String, dynamic> sessionData =
                sessionDoc.data() as Map<String, dynamic>;
            Timestamp? expiresAt = sessionData['expiresAt'] as Timestamp?;

            if (expiresAt != null &&
                DateTime.now().isBefore(expiresAt.toDate())) {
              isLoggedIn = true;
              debugPrint('✅ Valid Firestore session found');
            } else {
              debugPrint('❌ Firestore session expired or invalid');
              await _firestore.collection('sessions').doc(user.uid).delete();
            }
          }

          if (!isLoggedIn) {
            final token = await user.getIdToken();
            if (token != null) {
              await _storeSession(user.uid, token);
              await SessionManager.saveAuthToken(token);
              isLoggedIn = true;
              debugPrint('✅ Created new session for user: ${user.uid}');
            } else {
              debugPrint('❌ Failed to obtain auth token');
            }
          }
        } catch (e) {
          debugPrint('❌ Error checking Firestore session (likely offline): $e');
          final prefs = await SharedPreferences.getInstance();
          String? localUserId = prefs.getString('session_user_id');
          String? token = prefs.getString('session_token');
          int? tokenTimestamp = prefs.getInt('session_expires_at');

          if (localUserId == user.uid &&
              token != null &&
              tokenTimestamp != null) {
            final expiry = DateTime.fromMillisecondsSinceEpoch(tokenTimestamp);
            isLoggedIn = DateTime.now().isBefore(expiry);
            debugPrint(
                '⏱ Local session expires at: $expiry, loggedIn: $isLoggedIn');
          } else {
            final token = await user.getIdToken();
            if (token != null) {
              await _storeSession(user.uid, token);
              await SessionManager.saveAuthToken(token);
              isLoggedIn = true;
              debugPrint('✅ Created new local session for user: ${user.uid}');
            } else {
              debugPrint('❌ Failed to obtain auth token');
            }
          }
        }

        if (isLoggedIn) {
          final userDoc =
              await _firestore.collection('users').doc(user.uid).get();
          final userData = userDoc.exists
              ? userDoc.data() as Map<String, dynamic>
              : {
                  'id': user.uid,
                  'username': user.displayName ?? 'User',
                  'email': user.email ?? '',
                  'status': 'Online',
                  'auth_provider': 'firebase',
                  'created_at': FieldValue.serverTimestamp(),
                  'updated_at': FieldValue.serverTimestamp(),
                };
          if (!userDoc.exists) {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .set(userData, SetOptions(merge: true));
          }
          UserManager.instance.updateUser(userData);
          await _saveUserOffline(user.uid, userData);
          debugPrint('✅ UserManager updated with user: ${user.uid}');
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Unexpected error in _checkAuthStatus: $e');
      debugPrint(stack.toString());
    }

    if (!mounted) return;

    debugPrint(
        '🚀 Navigating to ${isLoggedIn ? "ProfileSelectionScreen" : "SignInScreen"}');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            isLoggedIn ? const ProfileSelectionScreen() : const SignInScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome to MovieFlix',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Yours by Mzazimhenga',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

