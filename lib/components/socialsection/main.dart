import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movie_app/components/socialsection/social_reactions_screen.dart';
import 'package:movie_app/components/socialsection/social_account_setup_screen.dart';

void main() {
  runApp(const SocialApp());
}

class SocialApp extends StatelessWidget {
  const SocialApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social Section',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const SocialRouter(),
    );
  }
}

/// This widget checks if a social account exists. If not, it loads the setup screen.
class SocialRouter extends StatefulWidget {
  const SocialRouter({Key? key}) : super(key: key);

  @override
  _SocialRouterState createState() => _SocialRouterState();
}

class _SocialRouterState extends State<SocialRouter> {
  bool? _hasSocialAccount;

  @override
  void initState() {
    super.initState();
    _checkSocialAccount();
  }

  Future<void> _checkSocialAccount() async {
    final prefs = await SharedPreferences.getInstance();
    // Check if a social account exists (e.g., a key "socialAccount" was saved)
    bool exists = prefs.containsKey('socialAccount');
    setState(() {
      _hasSocialAccount = exists;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator until the check completes.
    if (_hasSocialAccount == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // If a social account exists, go to the SocialReactionsScreen.
    if (_hasSocialAccount == true) {
      return SocialReactionsScreen(
          accentColor: Colors.deepPurple); // Pass accentColor
    }
    // Otherwise, show the SocialAccountSetupScreen.
    return const SocialAccountSetupScreen();
  }
}
