import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:movie_app/settings_provider.dart';
import 'package:movie_app/home_screen_main.dart';
import 'package:movie_app/categories_screen.dart';
import 'package:movie_app/downloads_screen.dart';
import 'components/feature_card.dart';
import 'components/storage_settings_screen.dart';
import 'components/watch_party_screen.dart';
import 'components/in_playback_trivia_screen.dart';
import 'components/ar_mode_screen.dart';
import 'components/recommendations_screen.dart';
import 'components/behind_the_scenes_screen.dart';
import 'components/theme_settings_screen.dart';
import 'components/voice_command_screen.dart';
import '../components/socialsection/social_reactions_screen.dart'
    hide WatchPartyScreen;

class InteractiveFeaturesScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  const InteractiveFeaturesScreen({
    Key? key,
    required this.isDarkMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  _InteractiveFeaturesScreenState createState() =>
      _InteractiveFeaturesScreenState();
}

class _InteractiveFeaturesScreenState extends State<InteractiveFeaturesScreen> {
  bool _isLoading = true;
  int selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    _allocateStorage();
  }

  Future<void> _allocateStorage() async {
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/allocated_storage.bin';
      final file = File(filePath);

      final dir = Directory(directory.path);
      final stats = await dir.stat();
      if (stats.size < 1024 * 1024 * 1024) {
        debugPrint("Insufficient storage for 1GB allocation. Skipping...");
        return;
      }

      if (!await file.exists()) {
        int sizeInBytes = 1024 * 1024; // 1MB for testing
        debugPrint("Allocating storage: $sizeInBytes bytes");
        RandomAccessFile raf = await file.open(mode: FileMode.write);
        await raf.setPosition(sizeInBytes - 1);
        await raf.writeByte(0);
        await raf.close();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('allocatedStorage', sizeInBytes);
        debugPrint("Storage allocation successful");
      } else {
        debugPrint("Storage file already exists");
      }
    } catch (e, stackTrace) {
      debugPrint("Error during storage allocation: $e\n$stackTrace");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void onItemTapped(int index) {
    setState(() => selectedIndex = index);
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreenMain()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CategoriesScreen()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DownloadsScreen()),
      );
    }
  }

  Widget _buildShimmerPlaceholder() {
    final settings = Provider.of<SettingsProvider>(context);
    return Shimmer.fromColors(
      baseColor: const Color.fromARGB(255, 40, 40, 40),
      highlightColor: const Color.fromARGB(255, 60, 60, 60),
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  settings.accentColor.withOpacity(0.2),
                  settings.accentColor.withOpacity(0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: settings.accentColor.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: settings.accentColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        settings.accentColor.withOpacity(0.3),
                        settings.accentColor.withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 150,
                        height: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 200,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: settings.accentColor.withOpacity(0.1),
        elevation: 0,
        title: Text(
          "Interactive Features",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: settings.accentColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: settings.accentColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StorageSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.06, -0.34),
                  radius: 1.0,
                  colors: [
                    settings.accentColor.withOpacity(0.5),
                    const Color.fromARGB(255, 0, 0, 0),
                  ],
                  stops: const [0.0, 0.59],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.64, 0.3),
                  radius: 1.0,
                  colors: [
                    settings.accentColor.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [
                      settings.accentColor.withOpacity(0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: settings.accentColor.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(160, 17, 19, 40),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.125)),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: screenHeight),
                        child: _isLoading
                            ? _buildShimmerPlaceholder()
                            : ListView(
                                padding: const EdgeInsets.all(16.0),
                                children: [
                                  FeatureCard(
                                    icon: Icons.group,
                                    iconColor: Colors.blue,
                                    title: "Watch Party",
                                    subtitle:
                                        "Host live watch parties with synchronized playback and in-app chat.",
                                    backgroundGradient: LinearGradient(
                                      colors: [
                                        settings.accentColor.withOpacity(0.2),
                                        settings.accentColor.withOpacity(0.4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderColor:
                                        settings.accentColor.withOpacity(0.5),
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    subtitleStyle: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const WatchPartyScreen()),
                                      );
                                    },
                                  ),
                                  FeatureCard(
                                    icon: Icons.quiz,
                                    iconColor: Colors.green,
                                    title: "In-Playback Trivia",
                                    subtitle:
                                        "Engage with trivia and challenges during key moments.",
                                    backgroundGradient: LinearGradient(
                                      colors: [
                                        settings.accentColor.withOpacity(0.2),
                                        settings.accentColor.withOpacity(0.4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderColor:
                                        settings.accentColor.withOpacity(0.5),
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    subtitleStyle: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const InPlaybackTriviaScreen()),
                                      );
                                    },
                                  ),
                                  FeatureCard(
                                    icon: Icons.view_in_ar,
                                    iconColor: Colors.orange,
                                    title: "Augmented Reality Mode",
                                    subtitle:
                                        "Experience AR with movie posters and interactive virtual objects.",
                                    backgroundGradient: LinearGradient(
                                      colors: [
                                        settings.accentColor.withOpacity(0.2),
                                        settings.accentColor.withOpacity(0.4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderColor:
                                        settings.accentColor.withOpacity(0.5),
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    subtitleStyle: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const ARModeScreen()),
                                      );
                                    },
                                  ),
                                  FeatureCard(
                                    icon: Icons.playlist_add_check,
                                    iconColor: Colors.purple,
                                    title:
                                        "Personalized Watchlists & AI Recommendations",
                                    subtitle:
                                        "Get personalized movie journeys based on your viewing history.",
                                    backgroundGradient: LinearGradient(
                                      colors: [
                                        settings.accentColor.withOpacity(0.2),
                                        settings.accentColor.withOpacity(0.4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderColor:
                                        settings.accentColor.withOpacity(0.5),
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    subtitleStyle: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const RecommendationsScreen()),
                                      );
                                    },
                                  ),
                                  FeatureCard(
                                    icon: Icons.movie_filter,
                                    iconColor: Colors.red,
                                    title: "Behind-the-Scenes & Easter Eggs",
                                    subtitle:
                                        "Discover exclusive content and interactive Easter egg hunts.",
                                    backgroundGradient: LinearGradient(
                                      colors: [
                                        settings.accentColor.withOpacity(0.2),
                                        settings.accentColor.withOpacity(0.4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderColor:
                                        settings.accentColor.withOpacity(0.5),
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    subtitleStyle: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const BehindTheScenesScreen()),
                                      );
                                    },
                                  ),
                                  FeatureCard(
                                    icon: Icons.color_lens,
                                    iconColor: Colors.teal,
                                    title: "Customizable UI Themes",
                                    subtitle:
                                        "Switch between dark mode, cinema mode, and more.",
                                    backgroundGradient: LinearGradient(
                                      colors: [
                                        settings.accentColor.withOpacity(0.2),
                                        settings.accentColor.withOpacity(0.4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderColor:
                                        settings.accentColor.withOpacity(0.5),
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    subtitleStyle: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ThemeSettingsScreen(
                                            currentTheme: widget.isDarkMode
                                                ? "Dark"
                                                : "Light",
                                            onThemeChanged: (newTheme) {
                                              widget.onThemeChanged(
                                                  newTheme == "Dark");
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  FeatureCard(
                                    icon: Icons.mic,
                                    iconColor: Colors.indigo,
                                    title: "Voice Command Integration",
                                    subtitle:
                                        "Control the app hands-free with voice commands.",
                                    backgroundGradient: LinearGradient(
                                      colors: [
                                        settings.accentColor.withOpacity(0.2),
                                        settings.accentColor.withOpacity(0.4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderColor:
                                        settings.accentColor.withOpacity(0.5),
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    subtitleStyle: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const VoiceCommandScreen()),
                                      );
                                    },
                                  ),
                                  FeatureCard(
                                    icon: Icons.emoji_emotions,
                                    iconColor: Colors.pink,
                                    title: "Real-Time Social Reactions",
                                    subtitle:
                                        "Share live reactions during movies with your community.",
                                    backgroundGradient: LinearGradient(
                                      colors: [
                                        settings.accentColor.withOpacity(0.2),
                                        settings.accentColor.withOpacity(0.4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderColor:
                                        settings.accentColor.withOpacity(0.5),
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    subtitleStyle: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(1, 1),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SocialReactionsScreen(
                                              accentColor:
                                                  settings.accentColor),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black54,
        selectedItemColor: const Color(0xffffeb00),
        unselectedItemColor: settings.accentColor.withOpacity(0.6),
        currentIndex: selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.category), label: 'Categories'),
          BottomNavigationBarItem(
              icon: Icon(Icons.download), label: 'Downloads'),
          BottomNavigationBarItem(
              icon: Icon(Icons.live_tv), label: 'Interactive'),
        ],
        onTap: onItemTapped,
      ),
    );
  }
}

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.redAccent, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
