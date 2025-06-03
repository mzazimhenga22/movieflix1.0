import 'package:flutter/material.dart';
import 'cinematic_mode_screen.dart';
import 'movie_recommendations_screen.dart';

class ChatSettingsScreen extends StatefulWidget {
  final Color currentColor;
  final String? currentImage;

  const ChatSettingsScreen({
    Key? key,
    required this.currentColor,
    this.currentImage,
  }) : super(key: key);

  @override
  ChatSettingsScreenState createState() => ChatSettingsScreenState();
}

class ChatSettingsScreenState extends State<ChatSettingsScreen> {
  // Preset colors.
  final List<Color> _colors = [
    const Color.fromARGB(255, 250, 250, 250),
    Colors.grey,
    const Color.fromARGB(255, 101, 206, 255),
    const Color.fromARGB(255, 88, 255, 102),
    const Color.fromARGB(255, 255, 92, 147),
    const Color.fromARGB(255, 237, 174, 247),
  ];

  late Color _selectedColor;
  late TextEditingController _imageController;

  // Extra settings from additional screens.
  String? _cinematicTheme; // e.g., "Classic Film", "Modern Blockbuster", etc.
  Map<String, dynamic>? _movieRecommendations; // e.g., {enabled: true, category: 'Trending'}

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
    _imageController = TextEditingController(text: widget.currentImage ?? '');
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  void _applySettings() {
    Navigator.pop(context, {
      'color': _selectedColor,
      'image': _imageController.text.trim(),
      'cinematicTheme': _cinematicTheme,
      'movieRecommendations': _movieRecommendations,
    });
  }

  Future<void> _openCinematicModeSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CinematicModeScreen()),
    );
    if (result != null && result is String) {
      setState(() {
        _cinematicTheme = result;
      });
    }
  }

  Future<void> _openMovieRecommendationsSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MovieRecommendationsScreen()),
    );
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _movieRecommendations = result;
      });
    }
  }

  Widget _buildColorPicker() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select a Background Color",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: _colors.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: _selectedColor == color
                            ? Colors.deepPurple
                            : Colors.transparent,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUrlField() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter an Image URL",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _imageController,
              decoration: const InputDecoration(
                hintText: "https://example.com/background.jpg",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraSettings() {
    return Column(
      children: [
        Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.movie_filter, color: Colors.deepPurple),
            title: Text(_cinematicTheme == null
                ? "Set Cinematic Mode"
                : "Cinematic Mode: $_cinematicTheme"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _openCinematicModeSettings,
          ),
        ),
        Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading:
                const Icon(Icons.recommend, color: Colors.deepPurpleAccent),
            title: Text(_movieRecommendations == null
                ? "Set Movie Recommendations"
                : "Recommendations: ${_movieRecommendations!['category']}"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _openMovieRecommendationsSettings,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Settings"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildColorPicker(),
            _buildImageUrlField(),
            _buildExtraSettings(),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _applySettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Apply Settings",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
