// lib/watch_history_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movie_app/movie_detail_screen.dart';

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({Key? key}) : super(key: key); // Explicit Key parameter

  @override
  _WatchHistoryScreenState createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  Future<List<Map<String, dynamic>>> _fetchWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonList = prefs.getStringList('watchHistory') ?? [];
    // Decode each JSON string into a map.
    return jsonList
        .map((jsonStr) => json.decode(jsonStr) as Map<String, dynamic>)
        .toList();
  }

  Future<void> _removeFromWatchHistory(String movieId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonList = prefs.getStringList('watchHistory') ?? [];
    jsonList.removeWhere((jsonStr) {
      final map = json.decode(jsonStr);
      return map['id'].toString() == movieId;
    });
    await prefs.setStringList('watchHistory', jsonList);
    setState(() {}); // Refresh the screen.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Watch History"),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchWatchHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final history = snapshot.data!;
          if (history.isEmpty) {
            return const Center(child: Text("No watched movies found."));
          }
          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final movie = history[index];
              final posterPath = movie['poster_path'];
              final posterUrl = posterPath != null
                  ? 'https://image.tmdb.org/t/p/w500$posterPath'
                  : '';
              final title = movie['title'] ?? movie['name'] ?? 'No Title';
              final finished = movie['finished'] == true;
              return ListTile(
                leading: posterUrl.isNotEmpty
                    ? Image.network(
                        posterUrl,
                        width: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.movie),
                title: Text(title),
                subtitle: Text(finished ? "Finished" : "Not finished"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () =>
                      _removeFromWatchHistory(movie['id'].toString()),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MovieDetailScreen(movie: movie),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}