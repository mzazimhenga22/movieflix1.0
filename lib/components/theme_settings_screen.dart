import 'package:flutter/material.dart';

class ThemeSettingsScreen extends StatefulWidget {
  final String currentTheme;
  final Function(String) onThemeChanged;
  const ThemeSettingsScreen({
    Key? key,
    required this.currentTheme,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  _ThemeSettingsScreenState createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  late String _selectedTheme;
  final List<String> _themeOptions = ["Light", "Dark", "Blue", "Green", "Red"];

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Customizable UI Themes")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Select your theme", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedTheme,
              items: _themeOptions.map((theme) {
                return DropdownMenuItem<String>(
                  value: theme,
                  child: Text(theme),
                );
              }).toList(),
              onChanged: (newTheme) {
                if (newTheme != null) {
                  setState(() {
                    _selectedTheme = newTheme;
                  });
                  widget.onThemeChanged(newTheme);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
