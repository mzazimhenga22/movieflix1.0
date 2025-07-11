import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:movie_app/tmdb_api.dart' as tmdb;
import 'package:movie_app/streaming_service.dart';
import 'package:movie_app/main_videoplayer.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'package:http/http.dart' as http;

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
  final Map<int, String?> _seasonTmdbIdCache = {};
  late int _selectedSeasonNumber;
  bool _isLoading = false;
  bool _isVisible = false;
  bool _fetchError = false;
  String _errorMessage = '';
  int? _releaseYear;

  @override
  void initState() {
    super.initState();
    _selectedSeasonNumber = widget.seasons.isNotEmpty
        ? (widget.seasons.first['season_number'] as int? ?? 1)
        : 1;
    _fetchTVShowDetails();
  }

  Future<void> _fetchTVShowDetails() async {
    try {
      final tvDetails = await tmdb.TMDBApi.fetchTVShowDetails(widget.tvId);
      final firstAirDate =
          tvDetails['first_air_date'] as String? ?? '1970-01-01';
      if (mounted) {
        setState(() {
          _releaseYear = int.parse(firstAirDate.split('-')[0]);
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch TV show details: $e');
      if (mounted) {
        setState(() {
          _releaseYear = 1970; // Fallback year
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchEpisodes(int seasonNumber) async {
    if (_episodesCache[seasonNumber] != null || _isLoading) return;
    setState(() {
      _isLoading = true;
      _fetchError = false;
      _errorMessage = '';
    });
    try {
      final seasonDetails =
          await tmdb.TMDBApi.fetchTVSeasonDetails(widget.tvId, seasonNumber);
      if (!mounted) return;
      setState(() {
        _episodesCache[seasonNumber] = seasonDetails['episodes'] ?? [];
        _seasonTmdbIdCache[seasonNumber] = seasonDetails['id']?.toString();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching episodes: $e');
      if (!mounted) return;
      setState(() {
        _episodesCache[seasonNumber] = [];
        _seasonTmdbIdCache[seasonNumber] = null;
        _isLoading = false;
        _fetchError = true;
        _errorMessage = 'Unable to load episodes.';
      });
    }
  }

  void _showLoadingDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingDialog(),
    );
  }

  Future<bool> _isUrlAccessible(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('URL inaccessible: $url, Error: $e');
      return false;
    }
  }

  void _showEpisodePlayOptionsModal(
      Map<String, dynamic> episode, int seasonNumber) {
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
            Navigator.pop(modalContext);
            _showLoadingDialog();

            final episodeNumber =
                (episode['episode_number'] as num?)?.toInt() ?? 1;
            final episodeName = episode['name'] as String? ?? 'Untitled';
            final episodeId = episode['id']?.toString();
            final seasonTmdbId = _seasonTmdbIdCache[seasonNumber];

            if (episodeId == null || seasonTmdbId == null) {
              if (mounted) {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Error"),
                    content: const Text(
                        "Unable to fetch episode details. Please try again later."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              }
              return;
            }

            Map<String, dynamic> streamingInfo = {};
            const maxRetries = 2;
            bool success = false;

            for (int attempt = 1;
                attempt <= maxRetries && !success;
                attempt++) {
              try {
                streamingInfo = await StreamingService.getStreamingLink(
                  tmdbId: widget.tvId.toString(),
                  title: widget.tvShowName.isNotEmpty
                      ? widget.tvShowName
                      : episodeName,
                  releaseYear: _releaseYear ?? 1970,
                  season: seasonNumber,
                  episode: episodeNumber,
                  resolution: resolution,
                  enableSubtitles: subtitles,
                  seasonTmdbId: seasonTmdbId,
                  episodeTmdbId: episodeId,
                );
                success = true;
              } catch (e) {
                debugPrint("Streaming fetch error (Attempt $attempt): $e");
                if (attempt < maxRetries) {
                  await Future.delayed(const Duration(seconds: 1));
                }
              }
            }

            if (!mounted) {
              Navigator.pop(context);
              return;
            }
            Navigator.pop(context);

            if (!success) {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Streaming Error"),
                    content: const Text(
                        "Failed to load episode. Please try again later."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              }
              return;
            }

            final streamUrl = streamingInfo['url'] as String? ?? '';
            final subtitleUrl = streamingInfo['subtitleUrl'] as String?;
            final isHls = streamingInfo['type'] == 'm3u8';
            final episodeFiles = _episodesCache[seasonNumber]
                    ?.map((ep) => ep['episode_number'].toString())
                    .toList() ??
                [];

            if (streamUrl.isEmpty || !(await _isUrlAccessible(streamUrl))) {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Unavailable"),
                    content: const Text(
                        "This episode is not available at the moment."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              }
              return;
            }

            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MainVideoPlayer(
                    videoPath: streamUrl,
                    title: streamingInfo['title'] as String? ?? episodeName,
                    releaseYear: _releaseYear ?? 1970,
                    isHls: isHls,
                    subtitleUrl: subtitleUrl,
                    isFullSeason: true,
                    episodeFiles: episodeFiles,
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
                        color: Colors.white,
                      ),
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
                            ),
                          )
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
                        color: settings.accentColor,
                      ),
                    )
                  : _fetchError
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                _errorMessage,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: settings.accentColor,
                                ),
                                onPressed: () =>
                                    _fetchEpisodes(_selectedSeasonNumber),
                                child: const Text(
                                  "Retry",
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildEpisodesList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEpisodesList() {
    final episodes = _episodesCache[_selectedSeasonNumber] ?? [];
    if (episodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No episodes found for this season.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemExtent: 100.0,
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
                  child: stillPath != null && stillPath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: "https://image.tmdb.org/t/p/w300$stillPath",
                          width: 120,
                          height: 70,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 120,
                            height: 70,
                            color: Colors.grey,
                            child: CircularProgressIndicator(
                              color: settings.accentColor,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 120,
                            height: 70,
                            color: Colors.grey,
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : Container(
                          width: 120,
                          height: 70,
                          color: Colors.grey,
                          child: Icon(
                            Icons.tv,
                            color: settings.accentColor,
                          ),
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
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        episodeOverview.isEmpty
                            ? 'No description available.'
                            : episodeOverview,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (runtime > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${runtime}m',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white60,
                            ),
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
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Select Resolution:",
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
          DropdownButton<String>(
            value: _resolution,
            dropdownColor: Colors.black87,
            style: const TextStyle(color: Colors.white),
            iconEnabledColor: settings.accentColor,
            items: const [
              DropdownMenuItem(
                value: "480p",
                child: Text("480p", style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: "720p",
                child: Text("720p", style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: "1080p",
                child: Text("1080p", style: TextStyle(color: Colors.white)),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _resolution = value);
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                "Enable Subtitles:",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
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
                backgroundColor: settings.accentColor,
              ),
              onPressed: () {
                widget.onConfirm(_resolution, _subtitles);
              },
              child: const Text(
                "Play Now",
                style: TextStyle(color: Colors.black),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class LoadingDialog extends StatefulWidget {
  const LoadingDialog({Key? key}) : super(key: key);

  @override
  LoadingDialogState createState() => LoadingDialogState();
}

class LoadingDialogState extends State<LoadingDialog> {
  bool showSecondMessage = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => showSecondMessage = true);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
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
                "This is taking longer than expected.",
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: settings.accentColor,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
