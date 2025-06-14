import 'package:flutter/material.dart';

class GroupSettingsScreen extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final List<Map<String, dynamic>> participants;

  const GroupSettingsScreen({
    Key? key,
    required this.conversation,
    required this.participants,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Settings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Group Name: ${conversation['group_name']}',
                style: const TextStyle(fontSize: 18)),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final participant = participants[index];
                return ListTile(
                  title: Text(participant['username'] ?? 'Unknown'),
                );
              },
            ),
          ),
          // Placeholder for group icon upload (to be implemented later)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextButton(
              onPressed: () {
                // Future implementation for adding group icon
              },
              child: const Text('Add Group Icon (Coming Soon)'),
            ),
          ),
        ],
      ),
    );
  }
}
