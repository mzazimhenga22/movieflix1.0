import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

const String youTubeApiKey = "AIzaSyDHdXyIwqP1G26v4qoRbY77m765gVfHwOs";

/// Fetches movie song videos from YouTube based on a search query.
Future<List<Map<String, String>>> fetchMovieSongs(String query) async {
  // Adjust the query to include "movie soundtrack official" for more accurate results.
  final refinedQuery = "$query movie soundtrack official";
  final url =
      'https://www.googleapis.com/youtube/v3/search?part=snippet&q=${Uri.encodeComponent(refinedQuery)}&type=video&key=$youTubeApiKey';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final List items = data['items'];
    return items.map<Map<String, String>>((item) {
      final snippet = item['snippet'];
      return {
        'title': snippet['title'],
        'imageUrl': snippet['thumbnails']['default']['url'],
        'videoId': item['id']['videoId'],
        // Using the query as a proxy for "movie" info.
        'movie': query,
      };
    }).toList();
  } else {
    throw Exception('Failed to load songs');
  }
}

/// Main screen showing a list of movie songs.
class SongOfMoviesScreen extends StatefulWidget {
  const SongOfMoviesScreen({Key? key}) : super(key: key);

  @override
  _SongOfMoviesScreenState createState() => _SongOfMoviesScreenState();
}

class _SongOfMoviesScreenState extends State<SongOfMoviesScreen> {
  late Future<List<Map<String, String>>> _songsFuture;
  String _searchQuery = "movie soundtrack"; // default query

  @override
  void initState() {
    super.initState();
    _songsFuture = fetchMovieSongs(_searchQuery);
  }

  /// Called when a new search query is submitted.
  void _startSearch(String query) {
    setState(() {
      _searchQuery = query;
      _songsFuture = fetchMovieSongs(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Song of Movies'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SongSearchDelegate(_startSearch),
              );
            },
          )
        ],
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Map<String, String>>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white)));
          }
          final songs = snapshot.data ?? [];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: songs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final song = songs[index];
              return Card(
                color: Colors.white10,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongPlayerScreen(
                          videoId: song['videoId']!,
                          songTitle: song['title']!,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            song['imageUrl']!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song['title']!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                song['movie']!,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 32),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SongPlayerScreen(
                                  videoId: song['videoId']!,
                                  songTitle: song['title']!,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// SearchDelegate that lets users input a query to fetch movie songs.
class SongSearchDelegate extends SearchDelegate {
  final Function(String) onQuerySubmitted;

  SongSearchDelegate(this.onQuerySubmitted);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null); // close search
      },
    );
  }

  @override
Widget buildResults(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    onQuerySubmitted(query);
    close(context, null);
  });
  return const Center(
    child: CircularProgressIndicator(),
  );
}


  @override
  Widget buildSuggestions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text(
        'Enter a movie or soundtrack name...',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}

/// Song player screen that forces landscape mode, hides YouTube controls,
/// and displays a centered play/pause button.
class SongPlayerScreen extends StatefulWidget {
  final String videoId;
  final String songTitle;

  const SongPlayerScreen({
    Key? key,
    required this.videoId,
    required this.songTitle,
  }) : super(key: key);

  @override
  _SongPlayerScreenState createState() => _SongPlayerScreenState();
}

class _SongPlayerScreenState extends State<SongPlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        controlsVisibleAtStart: false,
        hideControls: true,
        disableDragSeek: true,
      ),
    );
  }

  @override
  void dispose() {
    // Revert orientation back to portrait on exit.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: false,
          bottomActions: const [],
        ),
        builder: (context, player) {
          return Stack(
            children: [
              Center(child: player),
              Center(
                child: IconButton(
                  iconSize: 64,
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
