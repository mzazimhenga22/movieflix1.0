import 'package:flutter/material.dart';

class CinematicModeScreen extends StatefulWidget {
  const CinematicModeScreen({Key? key}) : super(key: key);

  @override
  _CinematicModeScreenState createState() => _CinematicModeScreenState();
}

class _CinematicModeScreenState extends State<CinematicModeScreen> {
  // Define a few cinematic themes.
  final List<String> _themes = [
    "Classic Film",
    "Modern Blockbuster",
    "Indie Vibes",
    "Sci-Fi Adventure",
    "Noir",
  ];
  String? _selectedTheme;

  @override
  void initState() {
    super.initState();
    _selectedTheme = _themes.first;
  }

  void _applyTheme() {
    Navigator.pop(context, _selectedTheme);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cinematic Mode Settings"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Choose a cinematic theme:",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _themes.length,
                itemBuilder: (context, index) {
                  final theme = _themes[index];
                  return ListTile(
                    title: Text(theme),
                    trailing: _selectedTheme == theme
                        ? const Icon(Icons.check, color: Colors.deepPurple)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedTheme = theme;
                      });
                    },
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _applyTheme,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
              ),
              child: const Text("Apply Cinematic Theme"),
            ),
          ],
        ),
      ),
    );
  }
}
