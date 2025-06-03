import 'package:flutter/material.dart';

class BehindTheScenesScreen extends StatefulWidget {
  const BehindTheScenesScreen({Key? key}) : super(key: key);
  @override
  _BehindTheScenesScreenState createState() => _BehindTheScenesScreenState();
}

class _BehindTheScenesScreenState extends State<BehindTheScenesScreen> {
  bool _showEasterEgg = false;
  void _toggleEasterEgg() {
    setState(() {
      _showEasterEgg = !_showEasterEgg;
    });
  }

  void _playVideo(String description) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Playing: $description")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Behind-the-Scenes & Easter Eggs")),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Director's Commentary"),
            onTap: () => _playVideo("Director's Commentary"),
          ),
          ListTile(
            title: const Text("Exclusive BTS Clips"),
            onTap: () => _playVideo("Exclusive BTS Clips"),
          ),
          ListTile(
            title: const Text("Easter Egg Hunt"),
            onTap: _toggleEasterEgg,
          ),
          if (_showEasterEgg)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("You found an Easter egg! Congratulations."),
            )
        ],
      ),
    );
  }
}
