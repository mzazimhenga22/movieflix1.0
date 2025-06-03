import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:movie_app/tmdb_api.dart' as tmdb;
import 'package:shimmer/shimmer.dart';
import '../story_player_screen.dart';

class StoriesSection extends StatefulWidget {
  const StoriesSection({super.key});

  @override
  State<StoriesSection> createState() => _StoriesSectionState();
}

class _StoriesSectionState extends State<StoriesSection>
    with AutomaticKeepAliveClientMixin {
  static List<Map<String, dynamic>> _cachedStories = [];
  List<Map<String, dynamic>> _stories = [];
  int _currentIndex = 0;
  late PageController _pageController;
  Timer? _timer;
  static const int _itemsPerPage = 4;

  // Cache the loading widget as a shimmer placeholder
  static final _loadingWidget = Shimmer.fromColors(
    baseColor: Colors.grey[800]!,
    highlightColor: Colors.grey[600]!,
    child: SizedBox(
      height: 150,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 70,
                  height: 16,
                  color: Colors.grey[800],
                ),
              ],
            );
          }),
        ),
      ),
    ),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (_cachedStories.isNotEmpty) {
      _stories = _cachedStories;
      _startTimer();
    } else {
      _fetchStories();
    }
  }

  Future<void> _fetchStories({bool forceRefresh = false}) async {
    if (_cachedStories.isNotEmpty && !forceRefresh) {
      if (_stories != _cachedStories) {
        setState(() {
          _stories = _cachedStories;
        });
      }
      _startTimer();
      return;
    }

    try {
      final List<dynamic> movies = await tmdb.TMDBApi.fetchTrendingMovies();
      final List<dynamic> tvShows = await tmdb.TMDBApi.fetchTrendingTVShows();
      List<Map<String, dynamic>> storyList = [];

      for (var movie in movies) {
        if (movie['media_type'] != 'movie') continue;
        final int movieId = int.parse(movie['id'].toString());
        List<dynamic> videos = [];
        try {
          final videoResponse = await tmdb.TMDBApi.fetchTrailers(movieId);
          videos = videoResponse;
        } catch (e) {
          debugPrint("Failed to load video for movie id $movieId: $e");
        }

        String videoUrl = '';
        if (videos.isNotEmpty) {
          final selectedVideo = videos.firstWhere(
            (v) =>
                v['type'] == 'Trailer' ||
                v['type'] == 'Teaser' ||
                v['type'] == 'Clip' ||
                v['type'] == 'Featurette',
            orElse: () => videos[0],
          );
          if (selectedVideo['key'] != null) {
            videoUrl =
                'https://www.youtube.com/watch?v=${selectedVideo['key']}';
          }
        }
        if (videoUrl.isEmpty) {
          videoUrl =
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
        }

        String imageUrl = movie['poster_path'] != null
            ? 'https://image.tmdb.org/t/p/w200${movie['poster_path']}'
            : 'https://source.unsplash.com/random/100x100/?movie';

        String movieTitle = (movie['title']?.toString().trim() ?? '');
        if (movieTitle.isEmpty) {
          movieTitle = (movie['original_title']?.toString().trim() ?? '');
        }
        if (movieTitle.isEmpty) {
          movieTitle = 'Untitled';
        }

        storyList.add({
          'name': movieTitle,
          'imageUrl': imageUrl,
          'videoUrl': videoUrl,
          'title': movieTitle,
          'description': movie['overview'] ?? 'Watch this trailer',
          'type': 'movie',
        });
      }

      for (var tvShow in tvShows) {
        final int tvShowId = int.parse(tvShow['id'].toString());
        List<dynamic> videos = [];
        try {
          final videoResponse =
              await tmdb.TMDBApi.fetchTrailers(tvShowId, isTVShow: true);
          videos = videoResponse;
        } catch (e) {
          debugPrint("Failed to load video for TV show id $tvShowId: $e");
        }

        String videoUrl = '';
        if (videos.isNotEmpty) {
          final selectedVideo = videos.firstWhere(
            (v) =>
                v['type'] == 'Trailer' ||
                v['type'] == 'Teaser' ||
                v['type'] == 'Clip' ||
                v['type'] == 'Featurette',
            orElse: () => videos[0],
          );
          if (selectedVideo['key'] != null) {
            videoUrl =
                'https://www.youtube.com/watch?v=${selectedVideo['key']}';
          }
        }
        if (videoUrl.isEmpty) {
          videoUrl =
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
        }

        String imageUrl = tvShow['poster_path'] != null
            ? 'https://image.tmdb.org/t/p/w200${tvShow['poster_path']}'
            : 'https://source.unsplash.com/random/100x100/?tvshow';

        String tvShowTitle =
            tvShow['name'] ?? tvShow['original_name'] ?? 'TV Show';

        storyList.add({
          'name': tvShowTitle,
          'imageUrl': imageUrl,
          'videoUrl': videoUrl,
          'title': tvShowTitle,
          'description': tvShow['overview'] ?? 'Watch this trailer',
          'type': 'tvshow',
        });
      }

      setState(() {
        _stories = storyList;
        _cachedStories = storyList;
      });
      _startTimer();
    } catch (e) {
      debugPrint("Error fetching stories: $e");
      setState(() {
        _stories = List.generate(5, (index) {
          return {
            'name': 'Movie ${index + 1}',
            'imageUrl':
                'https://source.unsplash.com/random/100x100/?movie,${index + 1}',
            'videoUrl':
                'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
            'title': 'Movie ${index + 1}',
            'description': 'Watch this trailer',
            'type': 'movie',
          };
        });
        _cachedStories = _stories;
      });
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients && _stories.isNotEmpty) {
        final int pageCount = (_stories.length / _itemsPerPage).ceil();
        _currentIndex = (_currentIndex + 1) % pageCount;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _openStory(Map<String, dynamic> story) {
    final int currentIndex = _stories.indexOf(story);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryPlayerScreen(
          videoUrl: story['videoUrl'] as String? ?? '',
          storyTitle: story['title'] as String? ?? '',
          storyDescription: story['description'] as String? ?? '',
          durationSeconds: 30,
          stories: _stories,
          currentIndex: currentIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (_stories.isEmpty) {
      return _loadingWidget;
    }
    final int pageCount = (_stories.length / _itemsPerPage).ceil();
    return SizedBox(
      height: 150,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: pageCount,
        itemBuilder: (context, pageIndex) {
          final int startIndex = pageIndex * _itemsPerPage;
          final int endIndex = min(startIndex + _itemsPerPage, _stories.length);
          final pageStories = _stories.sublist(startIndex, endIndex);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: pageStories.map((story) {
                return GestureDetector(
                  key: ValueKey(story['imageUrl']), // Ensure widget reuse
                  onTap: () => _openStory(story),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.pinkAccent, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 35,
                          backgroundImage:
                              NetworkImage(story['imageUrl'] as String),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 70,
                        child: Text(
                          story['name'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
