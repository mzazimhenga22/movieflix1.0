import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({Key? key}) : super(key: key); // Explicitly pass key to super constructor

  // Simulated function to fetch account details.
  Future<Map<String, dynamic>> _fetchAccountDetails() async {
    // Simulate network/database delay.
    await Future.delayed(const Duration(seconds: 2));
    return {
      'username': 'John Doe',
      'email': 'johndoe@example.com',
      'joined': 'January 2022',
      'achievements': [
        'Watched 100 movies',
        'Top Reviewer',
        'Early Adopter',
        'Film Buff',
        'Marathon Watcher'
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Account Details"),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchAccountDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final details = snapshot.data!;
          final achievements = details['achievements'] as List<dynamic>;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Text(
                  "Username: ${details['username']}",
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  "Email: ${details['email']}",
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  "Member Since: ${details['joined']}",
                  style: const TextStyle(fontSize: 18),
                ),
                const Divider(height: 32, thickness: 2),
                const Text(
                  "Achievements:",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...achievements.map(
                  (achievement) => ListTile(
                    leading: const Icon(Icons.emoji_events, color: Colors.amber),
                    title: Text(achievement),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}