import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:movie_app/main_videoplayer.dart';
import 'package:movie_app/components/trailer_section.dart';
import 'package:movie_app/components/similar_movies_section.dart';
import 'package:movie_app/mylist_screen.dart';
import 'package:movie_app/tmdb_api.dart' as tmdb;
import 'package:movie_app/streaming_service.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:movie_app/settings_provider.dart';

class MovieDetailScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  const MovieDetailScreen({Key? key, required this.movie}) : super(key: key);

  @override
  MovieDetailScreenState createState() => MovieDetailScreenState();
}

class MovieDetailScreenState extends State<MovieDetailScreen> {
  Future<Map<String, dynamic>>? _tvDetailsFuture;
  String _selectedResolution = "720p";
  bool _enableSubtitles = false;
  late final bool _isTvShow;
  List<Map<String, dynamic>> _similarMovies = [];

  @override
  void initState() {
    super.initState();
    debugPrint('MovieDetailScreenState initState called');
    _isTvShow =
        (widget.movie['media_type']?.toString().toLowerCase() == 'tv') ||
            (widget.movie['seasons'] != null &&
                (widget.movie['seasons'] as List).isNotEmpty);
    if (_isTvShow) {
      _tvDetailsFuture = tmdb.TMDBApi.fetchTVShowDetails(widget.movie['id']);
    }
    _fetchSimilarMovies();
  }

  Future<void> _fetchSimilarMovies() async {
    try {
      final similar = await tmdb.TMDBApi.fetchSimilarMovies(widget.movie['id']);
      if (mounted) {
        setState(() {
          _similarMovies = similar.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch similar movies: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('MovieDetailScreenState dispose called');
    super.dispose();
  }

  void _shareMovie(Map<String, dynamic> details) {
    const subject = 'Recommendation';
    final message =
        "Check out ${details['title'] ?? details['name']}!\n\n${details['synopsis'] ?? details['overview'] ?? ''}";
    Share.share(message,
        subject: details['title'] ?? details['name'] ?? subject);
  }

  Future<void> _addToMyList(Map<String, dynamic> details) async {
    final prefs = await SharedPreferences.getInstance();
    final myList = prefs.getStringList('myList') ?? [];
    final movieId = details['id'].toString();

    if (!myList
        .any((jsonStr) => (json.decode(jsonStr))['id'].toString() == movieId)) {
      myList.add(json.encode(details));
      await prefs.setStringList('myList', myList);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${details['title'] ?? details['name']} added to My List.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MyListScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${details['title'] ?? details['name']} is already in My List.')),
      );
    }
  }

  void _showDownloadOptionsModal(Map<String, dynamic> details) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String downloadResolution = _selectedResolution;
        bool downloadSubtitles = _enableSubtitles;
        return _DownloadOptionsModal(
          initialResolution: downloadResolution,
          initialSubtitles: downloadSubtitles,
          onConfirm: (resolution, subtitles) {
            _downloadMovie(details,
                resolution: resolution, subtitles: subtitles);
          },
        );
      },
    );
  }

  Future<void> _downloadMovie(
    Map<String, dynamic> details, {
    required String resolution,
    required bool subtitles,
  }) async {
    final tmdbId = details['id']?.toString() ?? '';
    final title = details['title']?.toString() ??
        details['name']?.toString() ??
        'Untitled';
    Map<String, String> streamingInfo;
    try {
      streamingInfo = await StreamingService.getStreamingLink(
        tmdbId: tmdbId,
        title: title,
        resolution: resolution,
        enableSubtitles: subtitles,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get streaming info: $e")),
      );
      return;
    }

    final downloadUrl = streamingInfo['url'];
    final urlType = streamingInfo['type'] ?? 'unknown';
    debugPrint('Download URL: $downloadUrl, Type: $urlType');

    if (downloadUrl == null || downloadUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Download URL not available")),
      );
      return;
    }

    if (await Permission.storage.request().isGranted) {
      final directory = Platform.isAndroid
          ? (await getExternalStorageDirectory())!
          : await getApplicationDocumentsDirectory();
      final fileName =
          "${details['title'] ?? details['name']}-$resolution.${urlType == 'm3u8' ? 'mp4' : 'mp4'}";
      final taskId = await FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: directory.path,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download started (Task ID: $taskId)")),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Storage permission not granted")),
      );
    }
  }

  void _rateMovie(Map<String, dynamic> details) {
    double rating = 3.0;
    showDialog(
      context: context,
      builder: (context) {
        return _RatingDialog(
          title: details['title'] ?? details['name'] ?? 'Rate Item',
          onRatingChanged: (value) => rating = value,
          onSubmit: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Rating submitted: $rating")),
            );
          },
        );
      },
    );
  }

  void _showPlayOptionsModal(Map<String, dynamic> details, bool isTvShow) {
    debugPrint(
        'Showing play options modal for ${details['title'] ?? details['name']}');
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return _PlayOptionsModal(
          initialResolution: _selectedResolution,
          initialSubtitles: _enableSubtitles,
          onConfirm: (resolution, subtitles) async {
            debugPrint(
                'Play options confirmed: resolution=$resolution, subtitles=$subtitles');
            setState(() {
              _selectedResolution = resolution;
              _enableSubtitles = subtitles;
            });
            await _launchStreamingPlayer(
                details, isTvShow, resolution, subtitles);
          },
        );
      },
    );
  }

  Future<void> _launchStreamingPlayer(
    Map<String, dynamic> details,
    bool isTvShow,
    String resolution,
    bool subtitles,
  ) async {
    debugPrint(
        'Launching streaming player for ${details['title'] ?? details['name']}');
    if (!mounted) return;
    _showLoadingDialog();

    Map<String, String> streamingInfo = {};
    List<String> episodeFiles = [];
    try {
      if (isTvShow) {
        debugPrint('Fetching streaming info for TV show');
        final seasons = details['seasons'] as List<dynamic>?;
        if (seasons != null && seasons.isNotEmpty) {
          final selectedSeason = seasons.firstWhere(
            (season) =>
                season['episodes'] != null &&
                (season['episodes'] as List).isNotEmpty,
            orElse: () => throw Exception('No episodes available'),
          );
          final episodes = selectedSeason['episodes'] as List<dynamic>;
          final firstEpisode = episodes[0];
          final seasonNumber = selectedSeason['season_number']?.toInt() ?? 1;
          final episodeNumber = firstEpisode['episode_number']?.toInt() ?? 1;

          streamingInfo = await StreamingService.getStreamingLink(
            tmdbId: details['id']?.toString() ?? 'Unknown Show',
            title: details['name']?.toString() ??
                details['title']?.toString() ??
                'Unknown Show',
            season: seasonNumber,
            episode: episodeNumber,
            resolution: resolution,
            enableSubtitles: subtitles,
          );
          episodeFiles = episodes.map<String>((e) => '').toList();
        } else {
          throw Exception('No seasons available');
        }
      } else {
        debugPrint('Fetching streaming info for movie');
        streamingInfo = await StreamingService.getStreamingLink(
          tmdbId: details['id']?.toString() ?? 'Unknown Movie',
          title: details['title']?.toString() ??
              details['name']?.toString() ??
              'Unknown Movie',
          resolution: resolution,
          enableSubtitles: subtitles,
        );
      }
    } catch (e) {
      debugPrint('Error fetching streaming info: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("An error occurred: $e")));
      }
      return;
    }

    if (!mounted) {
      debugPrint('Context not mounted, aborting');
      Navigator.pop(context);
      return;
    }

    final streamUrl = streamingInfo['url'] ?? '';
    final urlType = streamingInfo['type'] ?? 'unknown';
    final subtitleUrl = streamingInfo['subtitleUrl'];
    debugPrint(
        'Stream URL: $streamUrl, Type: $urlType, Subtitle: $subtitleUrl');

    if (streamUrl.isEmpty) {
      debugPrint('Stream URL is empty');
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Streaming details not available")),
      );
      return;
    }

    Navigator.pop(context);
    debugPrint('Navigating to MainVideoPlayer');
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MainVideoPlayer(
            videoPath: streamUrl,
            title: streamingInfo['title'] ??
                details['title'] ??
                details['name'] ??
                'Untitled',
            isFullSeason: isTvShow,
            episodeFiles: episodeFiles,
            similarMovies: _similarMovies,
            subtitleUrl: subtitleUrl, // Pass subtitle URL
            isHls: urlType == 'm3u8', // Indicate HLS format
          ),
        ),
      );
    }
  }

  void _showLoadingDialog() {
    debugPrint('Showing loading dialog');
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingDialog(),
    );
  }

  List<Widget> _buildDetailsContent(
      Map<String, dynamic> details, bool isTvShow, bool isLoading) {
    final dateLabel = isTvShow ? 'First Air Date' : 'Release Date';
    final title = isTvShow
        ? (details['name'] ?? details['title'] ?? 'No Title')
        : (details['title'] ?? details['name'] ?? 'No Title');
    final releaseDate = isTvShow
        ? (details['first_air_date'] ?? 'Unknown')
        : (details['release_date'] ?? 'Unknown');

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          '$dateLabel: $releaseDate',
          style: const TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ),
      if (isLoading)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 8,
            children: List.generate(
              3,
              (index) => Shimmer.fromColors(
                baseColor: Colors.grey[800]!,
                highlightColor: Colors.grey[600]!,
                child: Container(
                  width: 80,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        )
      else if (details['tags'] != null && (details['tags'] as List).isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 8,
            children: (details['tags'] as List)
                .map((tag) => Chip(
                      label: Text(tag.toString(),
                          style: const TextStyle(color: Colors.white)),
                      backgroundColor: Colors.grey[800],
                    ))
                .toList(),
          ),
        ),
      if (isLoading)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[800]!,
            highlightColor: Colors.grey[600]!,
            child: Container(
              width: 120,
              height: 20,
              color: Colors.grey[800],
            ),
          ),
        )
      else if (details['rating'] != null &&
          details['rating'].toString().isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Rating: ${details['rating']}/10',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? Shimmer.fromColors(
                baseColor: Colors.grey[800]!,
                highlightColor: Colors.grey[600]!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    3,
                    (index) => Container(
                      width: double.infinity,
                      height: 16,
                      color: Colors.grey[800],
                      margin: const EdgeInsets.only(bottom: 8),
                    ),
                  ),
                ),
              )
            : Text(
                details['synopsis'] ??
                    details['overview'] ??
                    'No overview available.',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
      ),
      if (isLoading)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[800]!,
                highlightColor: Colors.grey[600]!,
                child: Container(
                  width: 100,
                  height: 24,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(
                  4,
                  (index) => Shimmer.fromColors(
                    baseColor: Colors.grey[800]!,
                    highlightColor: Colors.grey[600]!,
                    child: Container(
                      width: 100,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
      else if (details['cast'] != null && (details['cast'] as List).isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cast',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: (details['cast'] as List)
                    .asMap()
                    .entries
                    .map((entry) => Chip(
                          label: Text(entry.value.toString(),
                              style: const TextStyle(color: Colors.white)),
                          backgroundColor: entry.key % 3 == 0
                              ? Colors.red[800]
                              : entry.key % 3 == 1
                                  ? Colors.blue[800]
                                  : Colors.green[800],
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      if (isLoading)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[800]!,
                highlightColor: Colors.grey[600]!,
                child: Container(
                  width: 100,
                  height: 24,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Shimmer.fromColors(
                baseColor: Colors.grey[800]!,
                highlightColor: Colors.grey[600]!,
                child: Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        )
      else if (details['cinemeta'] != null &&
          details['cinemeta']['awards'] != null &&
          details['cinemeta']['awards'].toString().isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Awards',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                details['cinemeta']['awards'].length > 50
                    ? '${details['cinemeta']['awards'].substring(0, 50)}...'
                    : details['cinemeta']['awards'],
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
      if (isTvShow)
        TVShowEpisodesSection(
          key: ValueKey('tv_${details['id']}'),
          tvId: details['id'],
          seasons: details['seasons'] ?? [],
          tvShowName: details['name']?.toString() ??
              details['title']?.toString() ??
              'Unknown Show',
        ),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Trailers',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      TrailerSection(movieId: details['id']),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Related ${isTvShow ? 'TV Shows' : 'Movies'}',
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      VisibilityDetector(
        key: ValueKey('similar_${details['id']}'),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0) {
            // Handled by SimilarMoviesSection
          }
        },
        child: SimilarMoviesSection(
          movieId: details['id'],
        ),
      ),
      const SizedBox(height: 32),
    ];
  }

  Widget _buildDetailScreen(Map<String, dynamic> details) {
    final posterUrl =
        'https://image.tmdb.org/t/p/w500${details['poster'] ?? details['poster_path'] ?? ''}';
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          _BackgroundDecoration(accentColor: settings.accentColor),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                backgroundColor: Colors.black87,
                title: Text(details['title'] ?? details['name'] ?? ''),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[800]!,
                          highlightColor: Colors.grey[600]!,
                          child: Container(color: Colors.grey[800]),
                        ),
                        errorWidget: (context, url, error) =>
                            Container(color: Colors.grey),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withAlpha(230),
                              Colors.black.withAlpha(178),
                              Colors.transparent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            stops: const [0.0, 0.3, 1.0],
                          ),
                        ),
                      ),
                      Center(
                        child: _PlayButton(
                          onPressed: () =>
                              _showPlayOptionsModal(details, _isTvShow),
                          accentColor: settings.accentColor,
                        ),
                      ),
                      _GlassActionBar(
                        onShare: () => _shareMovie(details),
                        onAddToList: () => _addToMyList(details),
                        onDownload: () => _showDownloadOptionsModal(details),
                        onRate: () => _rateMovie(details),
                        accentColor: settings.accentColor,
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                  delegate: SliverChildListDelegate(
                      _buildDetailsContent(details, _isTvShow, false))),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MovieDetailScreenState build called');
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        if (_isTvShow && _tvDetailsFuture != null) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _tvDetailsFuture,
            builder: (context, snapshot) {
              final details =
                  snapshot.connectionState == ConnectionState.waiting
                      ? widget.movie
                      : {...widget.movie, ...snapshot.data!};
              if (snapshot.hasError) {
                return Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white)),
                  ),
                );
              }
              return _buildDetailScreen(details);
            },
          );
        }
        return _buildDetailScreen(widget.movie);
      },
    );
  }
}

class _BackgroundDecoration extends StatelessWidget {
  final Color accentColor;

  const _BackgroundDecoration({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xff0d121d)),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.06, -0.34),
                  radius: 0.8,
                  colors: [accentColor.withOpacity(0.4), Colors.transparent],
                  stops: const [0.0, 0.59],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.64, 0.30),
                  radius: 0.8,
                  colors: [accentColor.withOpacity(0.2), Colors.transparent],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(color: Colors.white.withOpacity(0.0)),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color accentColor;

  const _PlayButton({required this.onPressed, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [accentColor.withAlpha(204), Colors.transparent],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
        Card(
          elevation: 8,
          shadowColor: Colors.black54,
          shape: const CircleBorder(),
          child: SizedBox(
            width: 60,
            height: 60,
            child: IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.black, size: 30),
              onPressed: onPressed,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassActionBar extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onAddToList;
  final VoidCallback onDownload;
  final VoidCallback onRate;
  final Color accentColor;

  const _GlassActionBar({
    required this.onShare,
    required this.onAddToList,
    required this.onDownload,
    required this.onRate,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.125)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: onShare,
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: onAddToList,
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: onDownload,
                ),
                IconButton(
                  icon: const Icon(Icons.star, color: Colors.white),
                  onPressed: onRate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadOptionsModal extends StatefulWidget {
  final String initialResolution;
  final bool initialSubtitles;
  final void Function(String, bool) onConfirm;

  const _DownloadOptionsModal({
    required this.initialResolution,
    required this.initialSubtitles,
    required this.onConfirm,
  });

  @override
  _DownloadOptionsModalState createState() => _DownloadOptionsModalState();
}

class _DownloadOptionsModalState extends State<_DownloadOptionsModal> {
  late String _resolution;
  late bool _subtitles;

  @override
  void initState() {
    super.initState();
    _resolution = widget.initialResolution;
    _subtitles = widget.initialSubtitles;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Container(
      padding: const EdgeInsets.all(16),
      height: 300,
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Download Options",
            style: TextStyle(
                fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text("Select Resolution:",
              style: TextStyle(color: Colors.white)),
          DropdownButton<String>(
            value: _resolution,
            dropdownColor: Colors.black87,
            items: const [
              DropdownMenuItem(
                  value: "480p",
                  child: Text("480p", style: TextStyle(color: Colors.white))),
              DropdownMenuItem(
                  value: "720p",
                  child: Text("720p", style: TextStyle(color: Colors.white))),
              DropdownMenuItem(
                  value: "1080p",
                  child: Text("1080p", style: TextStyle(color: Colors.white))),
            ],
            onChanged: (value) => setState(() => _resolution = value!),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text("Enable Subtitles:",
                  style: TextStyle(color: Colors.white)),
              Switch(
                value: _subtitles,
                activeColor: settings.accentColor,
                onChanged: (value) => setState(() => _subtitles = value),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: settings.accentColor),
              onPressed: () {
                debugPrint(
                    'Download options confirmed: resolution=$_resolution, subtitles=$_subtitles');
                Navigator.pop(context);
                widget.onConfirm(_resolution, _subtitles);
              },
              child: const Text("Start Download",
                  style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayOptionsModal extends StatefulWidget {
  final String initialResolution;
  final bool initialSubtitles;
  final void Function(String, bool) onConfirm;

  const _PlayOptionsModal({
    required this.initialResolution,
    required this.initialSubtitles,
    required this.onConfirm,
  });

  @override
  _PlayOptionsModalState createState() => _PlayOptionsModalState();
}

class _PlayOptionsModalState extends State<_PlayOptionsModal> {
  late String _resolution;
  late bool _subtitles;

  @override
  void initState() {
    super.initState();
    _resolution = widget.initialResolution;
    _subtitles = widget.initialSubtitles;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              "Play Options",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          const Text("Select Resolution:",
              style: TextStyle(fontSize: 16, color: Colors.white)),
          DropdownButton<String>(
            value: _resolution,
            dropdownColor: Colors.black87,
            items: const [
              DropdownMenuItem(
                  value: "480p",
                  child: Text("480p", style: TextStyle(color: Colors.white))),
              DropdownMenuItem(
                  value: "720p",
                  child: Text("720p", style: TextStyle(color: Colors.white))),
              DropdownMenuItem(
                  value: "1080p",
                  child: Text("1080p", style: TextStyle(color: Colors.white))),
            ],
            onChanged: (value) => setState(() => _resolution = value!),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text("Enable Subtitles:",
                  style: TextStyle(fontSize: 16, color: Colors.white)),
              Switch(
                value: _subtitles,
                activeColor: settings.accentColor,
                onChanged: (value) => setState(() => _subtitles = value),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: settings.accentColor),
              onPressed: () {
                debugPrint(
                    'Play Now button pressed: resolution=$_resolution, subtitles=$_subtitles');
                Navigator.pop(context);
                widget.onConfirm(_resolution, _subtitles);
              },
              child:
                  const Text("Play Now", style: TextStyle(color: Colors.black)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RatingDialog extends StatefulWidget {
  final String title;
  final void Function(double) onRatingChanged;
  final VoidCallback onSubmit;

  const _RatingDialog({
    required this.title,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  double _rating = 3.0;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return AlertDialog(
      title: Text('Rate ${widget.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Select rating:"),
          Slider(
            value: _rating,
            min: 1.0,
            max: 5.0,
            divisions: 4,
            label: _rating.toString(),
            activeColor: settings.accentColor,
            onChanged: (value) {
              setState(() => _rating = value);
              widget.onRatingChanged(value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: settings.accentColor),
          onPressed: widget.onSubmit,
          child: const Text("Submit", style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}

class LoadingDialog extends StatefulWidget {
  const LoadingDialog({Key? key}) : super(key: key);

  @override
  _LoadingDialogState createState() => _LoadingDialogState();
}

class _LoadingDialogState extends State<LoadingDialog> {
  bool _showSecondMessage = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _showSecondMessage = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    debugPrint('LoadingDialog disposed, timer canceled');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: settings.accentColor),
            const SizedBox(height: 16),
            const Text(
              "Preparing your content...",
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (_showSecondMessage) ...[
              const SizedBox(height: 12),
              const Text(
                "The app is in its inception stage,\nso some content might not be available yet.",
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TVShowEpisodesSection extends StatefulWidget {
  final int tvId;
  final List<dynamic> seasons;
  final String tvShowName;

  const TVShowEpisodesSection({
    Key? key,
    required this.tvId,
    required this.seasons,
    required this.tvShowName,
  }) : super(key: key);

  @override
  TVShowEpisodesSectionState createState() => TVShowEpisodesSectionState();
}

class TVShowEpisodesSectionState extends State<TVShowEpisodesSection> {
  final Map<int, List<dynamic>> _episodesCache = {};
  late int _selectedSeasonNumber;
  bool _isLoading = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
        'TVShowEpisodesSectionState initState called with tvId: ${widget.tvId}');
    _selectedSeasonNumber = widget.seasons.isNotEmpty
        ? (widget.seasons.first['season_number'] as int? ?? 1)
        : 1;
  }

  @override
  void dispose() {
    debugPrint('TVShowEpisodesSectionState dispose called');
    super.dispose();
  }

  Future<void> _fetchEpisodes(int seasonNumber) async {
    if (_episodesCache[seasonNumber] != null || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      debugPrint('Fetching episodes for season $seasonNumber');
      final seasonDetails =
          await tmdb.TMDBApi.fetchTVSeasonDetails(widget.tvId, seasonNumber);
      if (!mounted) return;
      setState(() {
        _episodesCache[seasonNumber] = seasonDetails['episodes'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _episodesCache[seasonNumber] = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load episodes: $e')),
      );
    }
  }

  void _showLoadingDialog() {
    debugPrint('Showing episode loading dialog');
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const EpisodeLoadingDialog(),
    );
  }

  void _showEpisodePlayOptionsModal(
      Map<String, dynamic> episode, int seasonNumber) {
    debugPrint(
        'Showing episode play options modal for episode: ${episode['name']}');
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return _EpisodePlayOptionsModal(
          onConfirm: (resolution, subtitles) async {
            debugPrint(
                'Episode play options confirmed: resolution=$resolution, subtitles=$subtitles');
            Navigator.pop(modalContext);
            _showLoadingDialog();

            final episodeNumber =
                (episode['episode_number'] as num?)?.toInt() ?? 1;
            final episodeName = episode['name'] as String? ?? 'Untitled';

            Map<String, String> streamingInfo = {};
            try {
              streamingInfo = await StreamingService.getStreamingLink(
                tmdbId: widget.tvId.toString(),
                title: widget.tvShowName.isNotEmpty
                    ? widget.tvShowName
                    : episodeName,
                season: seasonNumber,
                episode: episodeNumber,
                resolution: resolution,
                enableSubtitles: subtitles,
              );
            } catch (e, stacktrace) {
              debugPrint("Streaming fetch error: $e");
              debugPrintStack(stackTrace: stacktrace);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to get streaming info: $e")),
                );
              }
              return;
            }

            if (!mounted) {
              debugPrint('Context not mounted, aborting episode streaming');
              Navigator.pop(context);
              return;
            }
            Navigator.pop(context);

            final streamUrl = streamingInfo['url'] ?? '';
            final urlType = streamingInfo['type'] ?? 'unknown';
            final subtitleUrl = streamingInfo['subtitleUrl'];
            debugPrint(
                'Episode stream URL: $streamUrl, Type: $urlType, Subtitle: $subtitleUrl');

            if (streamUrl.isEmpty) {
              debugPrint('Episode stream URL is empty');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Streaming details not available")),
                );
              }
              return;
            }

            debugPrint('Navigating to MainVideoPlayer for episode');
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MainVideoPlayer(
                    videoPath: streamUrl,
                    title: streamingInfo['title'] ?? episodeName,
                    isFullSeason: true,
                    episodeFiles: [],
                    similarMovies: [],
                    subtitleUrl: subtitleUrl,
                    isHls: urlType == 'm3u8',
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('TVShowEpisodesSectionState build called');
    if (widget.seasons.isEmpty) return const SizedBox.shrink();

    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return VisibilityDetector(
          key: ValueKey('episodes_${widget.tvId}'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction > 0 && !_isVisible && !_isLoading) {
              _isVisible = true;
              _fetchEpisodes(_selectedSeasonNumber);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Episodes',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _selectedSeasonNumber,
                      dropdownColor: Colors.black87,
                      style: const TextStyle(color: Colors.white),
                      iconEnabledColor: settings.accentColor,
                      items: widget.seasons
                          .map<DropdownMenuItem<int>>(
                              (season) => DropdownMenuItem(
                                    value: season['season_number'] as int? ?? 0,
                                    child: Text(
                                        'Season ${season['season_number'] ?? 0}'),
                                  ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null && mounted) {
                          setState(() {
                            _selectedSeasonNumber = value;
                            _fetchEpisodes(value);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: settings.accentColor))
                  : _buildEpisodesList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEpisodesList() {
    final episodes = _episodesCache[_selectedSeasonNumber] ?? [];
    if (episodes.isEmpty && !_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No episodes available.',
            style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final episode = episodes[index];
        return _EpisodeCard(
          episode: episode,
          seasonNumber: _selectedSeasonNumber,
          onTap: () =>
              _showEpisodePlayOptionsModal(episode, _selectedSeasonNumber),
        );
      },
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final Map<String, dynamic> episode;
  final int seasonNumber;
  final VoidCallback onTap;

  const _EpisodeCard({
    required this.episode,
    required this.seasonNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final episodeNumber =
        (episode['episode_number'] as num?)?.toString().padLeft(2, '0') ?? '01';
    final episodeName = episode['name'] as String? ?? 'Untitled';
    final episodeOverview = episode['overview'] as String? ?? '';
    final stillPath = episode['still_path'] as String?;
    final runtime = (episode['runtime'] as int?) ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: settings.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.125)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: stillPath != null
                      ? CachedNetworkImage(
                          imageUrl: "https://image.tmdb.org/t/p/w300$stillPath",
                          width: 120,
                          height: 70,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[800]!,
                            highlightColor: Colors.grey[600]!,
                            child: Container(
                              width: 120,
                              height: 70,
                              color: Colors.grey[800],
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 120,
                            height: 70,
                            color: Colors.grey,
                            child: const Icon(Icons.error, color: Colors.red),
                          ),
                        )
                      : Container(
                          width: 120,
                          height: 70,
                          color: Colors.grey,
                          child: Icon(Icons.tv, color: settings.accentColor),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Episode $episodeNumber: $episodeName',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        episodeOverview,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (runtime > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${runtime}m',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white60),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodePlayOptionsModal extends StatefulWidget {
  final void Function(String, bool) onConfirm;

  const _EpisodePlayOptionsModal({required this.onConfirm});

  @override
  _EpisodePlayOptionsModalState createState() =>
      _EpisodePlayOptionsModalState();
}

class _EpisodePlayOptionsModalState extends State<_EpisodePlayOptionsModal> {
  String _resolution = "720p";
  bool _subtitles = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              "Play Options",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          const Text("Select Resolution:",
              style: TextStyle(fontSize: 16, color: Colors.white)),
          DropdownButton<String>(
            value: _resolution,
            dropdownColor: Colors.black87,
            iconEnabledColor: settings.accentColor,
            items: const [
              DropdownMenuItem(
                  value: "480p",
                  child: Text("480p", style: TextStyle(color: Colors.white))),
              DropdownMenuItem(
                  value: "720p",
                  child: Text("720p", style: TextStyle(color: Colors.white))),
              DropdownMenuItem(
                  value: "1080p",
                  child: Text("1080p", style: TextStyle(color: Colors.white))),
            ],
            onChanged: (value) => setState(() => _resolution = value!),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text("Enable Subtitles:",
                  style: TextStyle(fontSize: 16, color: Colors.white)),
              Switch(
                value: _subtitles,
                activeColor: settings.accentColor,
                onChanged: (value) => setState(() => _subtitles = value),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: settings.accentColor),
              onPressed: () {
                debugPrint(
                    'Episode Play Now button pressed: resolution=$_resolution, subtitles=$_subtitles');
                widget.onConfirm(_resolution, _subtitles);
              },
              child:
                  const Text("Play Now", style: TextStyle(color: Colors.black)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class EpisodeLoadingDialog extends StatefulWidget {
  const EpisodeLoadingDialog({Key? key}) : super(key: key);

  @override
  EpisodeLoadingDialogState createState() => EpisodeLoadingDialogState();
}

class EpisodeLoadingDialogState extends State<EpisodeLoadingDialog> {
  bool showSecondMessage = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    debugPrint('EpisodeLoadingDialogState initState called');
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => showSecondMessage = true);
    });
  }

  @override
  void dispose() {
    debugPrint('EpisodeLoadingDialogState dispose called');
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: settings.accentColor),
            const SizedBox(height: 16),
            const Text(
              "Preparing your episode...",
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (showSecondMessage) ...[
              const SizedBox(height: 12),
              const Text(
                "The app is in its inception stage,\nso some TV shows and episodes might not be available.",
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
