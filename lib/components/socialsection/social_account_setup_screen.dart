// lib/components/social_section/social_account_setup_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SocialAccountSetupScreen extends StatefulWidget {
  const SocialAccountSetupScreen({Key? key}) : super(key: key);

  @override
  _SocialAccountSetupScreenState createState() =>
      _SocialAccountSetupScreenState();
}

class _SocialAccountSetupScreenState extends State<SocialAccountSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  // Add other controllers if needed (e.g., for bio, avatar URL, etc.)

  // In a real app, you might pass the movie app account data from a higher-level widget.
  final Map<String, dynamic> _movieAccount = {
    'id': 1,
    'username': 'MovieAppUser',
    'email': 'user@movieapp.com',
    'bio': 'This is my movie app account bio.',
    'avatar': 'https://source.unsplash.com/random/200x200/?face',
  };

  Future<void> _saveSocialAccount(bool useMovieAccount) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> socialAccount;
    if (useMovieAccount) {
      // Use movie account details.
      socialAccount = _movieAccount;
    } else {
      // Use the details from the form.
      socialAccount = {
        'id': _movieAccount['id'], // Or generate a new ID if needed.
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'bio': '', // Add bio or other fields as needed.
        'avatar': 'https://source.unsplash.com/random/200x200/?face',
      };
    }
    await prefs.setString('socialAccount', jsonEncode(socialAccount));
    // Return to previous screen with the social account data.
    Navigator.pop(context, socialAccount);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Up Social Account"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Choose how you'd like to set up your social profile:"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Use movie account details.
                await _saveSocialAccount(true);
              },
              child: const Text("Use Movie Account Details"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Show a dialog to create a new social account.
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Create Social Account"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _usernameController,
                          decoration:
                              const InputDecoration(labelText: "Username"),
                        ),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: "Email"),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await _saveSocialAccount(false);
                        },
                        child: const Text("Save"),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Create New Social Account"),
            ),
          ],
        ),
      ),
    );
  }
}
