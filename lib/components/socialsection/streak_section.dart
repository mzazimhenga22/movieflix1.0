import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakSection extends StatefulWidget {
  final int movieStreak;
  final Function(int) onStreakUpdated;

  const StreakSection({Key? key, required this.movieStreak, required this.onStreakUpdated}) : super(key: key);

  @override
  _StreakSectionState createState() => _StreakSectionState();
}

class _StreakSectionState extends State<StreakSection> {
  late int _movieStreak;

  @override
  void initState() {
    super.initState();
    _movieStreak = widget.movieStreak;
  }

  Future<void> _saveStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('movieStreak', _movieStreak);
    widget.onStreakUpdated(_movieStreak);
  }

  void _incrementStreak() {
    setState(() => _movieStreak++);
    _saveStreak();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Streak incremented!")));
  }

  Widget _buildBadge(String title, int threshold) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Icon(Icons.star, color: _movieStreak >= threshold ? Colors.yellow : Colors.grey, size: 40),
          Text(title, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.deepPurple, Colors.deepPurpleAccent], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.deepPurpleAccent, Colors.deepPurple], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Movie Streak", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  Text("$_movieStreak days", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20)),
                    icon: const Icon(Icons.movie, color: Colors.deepPurple),
                    label: const Text("Mark Today as Watched", style: TextStyle(color: Colors.deepPurple)),
                    onPressed: _incrementStreak,
                  ),
                  const SizedBox(height: 20),
                  const Text("Streak Rewards", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBadge("Bronze", 5),
                      _buildBadge("Silver", 10),
                      _buildBadge("Gold", 20),
                    ],
                  ),
                  if (_movieStreak > 0) const Padding(padding: EdgeInsets.only(top: 12), child: Text("Keep it up!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}