import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movie_app/main_videoplayer.dart';
import 'package:movie_app/streaming_service.dart';

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({Key? key}) : super(key: key);

  @override
  _WatchHistoryScreenState createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  Future<List<Map<String, dynamic>>> _fetchWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonList = prefs.getStringList('watchHistory') ?? [];
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
    setState(() {});
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Future<void> _resumePlayback(Map<String, dynamic> movie) async {
    final tmdbId = movie['id'].toString();
    final title = movie['title'] ?? movie['name'] ?? 'Untitled';
    final releaseYear = movie['releaseYear'] ?? 1970;
    final isTvShow = movie['media_type']?.toString().toLowerCase() == 'tv';
    final season = movie['season'] ?? 1;
    final episode = movie['episode'] ?? 1;
    final savedPosition = Duration(seconds: movie['position'] ?? 0);
    final resolution = movie['resolution'] ?? '720p';
    final subtitles = movie['subtitles'] ?? false;

    try {
      final streamingInfo = await StreamingService.getStreamingLink(
        tmdbId: tmdbId,
        title: title,
        releaseYear: releaseYear,
        season: isTvShow ? season : null,
        episode: isTvShow ? episode : null,
        resolution: resolution,
        enableSubtitles: subtitles,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MainVideoPlayer(
            videoPath: streamingInfo['url'] ?? '',
            title: streamingInfo['title'] ?? title,
            releaseYear: releaseYear,
            isHls: streamingInfo['type'] == 'm3u8',
            subtitleUrl: streamingInfo['subtitleUrl'],
            isFullSeason: isTvShow,
            episodeFiles: isTvShow ? movie['episodeFiles'] ?? [] : [],
            similarMovies: movie['similarMovies'] ?? [],
            initialPosition: savedPosition, // Pass saved position
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resume: $e')),
        );
      }
    }
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
              final isTvShow =
                  movie['media_type']?.toString().toLowerCase() == 'tv';
              final position = Duration(seconds: movie['position'] ?? 0);
              final duration = Duration(seconds: movie['duration'] ?? 1);
              final progress = duration.inSeconds > 0
                  ? (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0)
                  : 0.0;
              final remaining = duration - position;

              return ListTile(
                leading: posterUrl.isNotEmpty
                    ? Image.network(
                        posterUrl,
                        width: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.movie),
                      )
                    : const Icon(Icons.movie),
                title: Text(isTvShow
                    ? '$title (S${movie['season'] ?? 1}E${movie['episode'] ?? 1})'
                    : title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress: ${_formatDuration(position)} / ${_formatDuration(duration)} (${_formatDuration(remaining)} left)',
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[700],
                      valueColor: const AlwaysStoppedAnimation(Colors.red),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () =>
                      _removeFromWatchHistory(movie['id'].toString()),
                ),
                onTap: () => _resumePlayback(movie),
              );
            },
          );
        },
      ),
    );
  }
}
