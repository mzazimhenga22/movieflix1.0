import 'package:flutter/material.dart';

class MovieRecommendationsScreen extends StatefulWidget {
  const MovieRecommendationsScreen({Key? key}) : super(key: key);

  @override
  _MovieRecommendationsScreenState createState() =>
      _MovieRecommendationsScreenState();
}

class _MovieRecommendationsScreenState
    extends State<MovieRecommendationsScreen> {
  bool _enabled = false;
  final List<String> _categories = [
    "Trending",
    "Top Rated",
    "Action",
    "Comedy",
    "Drama",
  ];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categories.first;
  }

  void _applySettings() {
    Navigator.pop(context, {
      'enabled': _enabled,
      'category': _enabled ? _selectedCategory : 'None',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Movie Recommendations Settings"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text("Enable Recommendations Overlay"),
              value: _enabled,
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
            ),
            if (_enabled) ...[
              const SizedBox(height: 12),
              const Text(
                "Select Recommendation Category:",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return RadioListTile<String>(
                      title: Text(category),
                      value: category,
                      groupValue: _selectedCategory,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            ElevatedButton(
              onPressed: _applySettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
              ),
              child: const Text("Apply Recommendations Settings"),
            ),
          ],
        ),
      ),
    );
  }
}
