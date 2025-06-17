import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:movie_app/streaming_service.dart';
import 'dart:io';

class Subtitle {
  final Duration start;
  final Duration end;
  final String text;

  Subtitle({required this.start, required this.end, required this.text});
}

class MainVideoPlayer extends StatefulWidget {
  final String videoPath;
  final String title;
  final int releaseYear;
  final bool isFullSeason;
  final List<String> episodeFiles;
  final List<Map<String, dynamic>> similarMovies;
  final String? subtitleUrl;
  final String? localSubtitlePath;
  final bool isHls;
  final bool isLocal;

  const MainVideoPlayer({
    super.key,
    required this.videoPath,
    required this.title,
    required this.releaseYear,
    this.isFullSeason = false,
    this.episodeFiles = const [],
    this.similarMovies = const [],
    this.subtitleUrl,
    this.localSubtitlePath,
    required this.isHls,
    this.isLocal = false,
  });

  @override
  MainVideoPlayerState createState() => MainVideoPlayerState();
}

class MainVideoPlayerState extends State<MainVideoPlayer> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isBuffering = false;

  bool _showControls = false; // Controls start hidden
  Timer? _hideTimer;

  double _volume = 1.0;
  bool _isMuted = false;
  double _brightness = 0.5;
  bool _isLocked = false;
  bool _isAdjustingBrightness = false;
  bool _isAdjustingVolume = false;
  double? _startX;
  double _playbackSpeed = 1.0;

  List<Subtitle> _subtitles = [];
  String _currentSubtitle = "";
  final List<String> _qualities = ["Auto", "360p", "480p", "720p", "1080p"];
  String _selectedQuality = "Auto";

  Color _controlColor = Colors.white;
  double _iconSize = 30;
  final Map<String, double> _iconSizePresets = {
    'Small': 30,
    'Medium': 44,
    'Large': 63,
  };
  String _iconSizeKey = 'Small';

  String _currentVideoPath = "";
  String _title = "";
  int? _currentEpisodeNumber;
  bool _showNextEpisodeBar = false;
  Map<String, String>? _nextEpisodeData;
  bool _showRecommendationsBar = false;
  Map<String, dynamic>? _recommendationData;
  Timer? _recommendationTimer;

  bool _showSubtitles = true;

  Offset? _lastTapPosition;
  String? _seekFeedback;
  Duration? _seekTargetDuration;
  double? _dragStartX;
  Duration? _dragStartPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _title = widget.title;
    _enforceLandscape();
    _initializeVideoPath().then((_) => _initializeVideo());
    _initializeBrightness();
    _loadSubtitles();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      _enforceLandscape();
      if (_controller.value.isInitialized && !_controller.value.isPlaying) {
        _controller.play();
      }
    }
  }

  Future<void> _enforceLandscape() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e) {
      debugPrint('Error setting landscape mode: $e');
    }
  }

  Future<void> _initializeVideoPath() async {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
      _currentVideoPath = widget.videoPath;
    });
  }

  Future<void> _initializeVideo() async {
    if (_currentVideoPath.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = "No valid video URL or path provided.";
        });
      }
      return;
    }

    try {
      if (widget.isLocal) {
        final file = File(_currentVideoPath);
        if (!await file.exists()) {
          if (mounted) {
            setState(() {
              _errorMessage = "Local file not found: $_currentVideoPath";
            });
          }
          return;
        }
        _controller = VideoPlayerController.file(file);
      } else {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(_currentVideoPath),
          formatHint: widget.isHls ? VideoFormat.hls : VideoFormat.other,
          httpHeaders: {
            'Accept': '*/*',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        );
      }

      _controller.addListener(_videoListener);

      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _volume = _controller.value.volume;
        });
        await _controller.play(); // Autoplay on initialization
        await _controller.setPlaybackSpeed(_playbackSpeed);
      }
    } catch (error) {
      if (mounted) {
        if (_selectedQuality == "Auto") {
          _selectedQuality = "360p";
          await _fetchNewQualityStream("360p");
        } else {
          final nextQuality = _getNextLowerQuality(_selectedQuality);
          if (nextQuality != null) {
            setState(() {
              _selectedQuality = nextQuality;
            });
            await _fetchNewQualityStream(nextQuality);
          } else {
            setState(() {
              _errorMessage = "Failed to load video: $error";
            });
          }
        }
      }
    }
  }

  String? _getNextLowerQuality(String currentQuality) {
    switch (currentQuality) {
      case "1080p":
        return "720p";
      case "720p":
        return "480p";
      case "480p":
        return "360p";
      default:
        return null;
    }
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _isBuffering = _controller.value.isBuffering;
        _updateSubtitle();
        _checkForEndOfContent();
      });
    }
  }

  Future<void> _initializeBrightness() async {
    if (kIsWeb) {
      _brightness = 0.5;
      if (mounted) setState(() {});
      return;
    }
    try {
      _brightness = await ScreenBrightness().application;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to get brightness: $e');
      _brightness = 0.5;
      if (mounted) setState(() {});
    }
  }

  Future<void> _setBrightness(double value) async {
    if (kIsWeb) return;
    try {
      await ScreenBrightness().setApplicationScreenBrightness(value);
    } catch (e) {
      debugPrint('Failed to set brightness: $e');
    }
  }

  Future<void> _loadSubtitles() async {
    if (widget.isLocal && widget.localSubtitlePath != null) {
      try {
        final file = File(widget.localSubtitlePath!);
        if (await file.exists()) {
          final srt = await file.readAsString();
          if (mounted) {
            setState(() {
              _subtitles = _parseSrt(srt);
            });
          }
        } else {
          debugPrint('Local subtitle file not found');
        }
      } catch (e) {
        debugPrint('Failed to load local subtitles: $e');
      }
    } else if (widget.subtitleUrl != null && widget.subtitleUrl!.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(widget.subtitleUrl!));
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _subtitles = _parseSrt(response.body);
            });
          }
        } else {
          debugPrint('Failed to fetch network subtitles: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Failed to load network subtitles: $e');
      }
    }
  }

  List<Subtitle> _parseSrt(String srt) {
    final List<Subtitle> subtitles = [];
    final regex = RegExp(r'(\d+)\s+(\d{2}:\d{2}:\d{2},\d{3})\s+-->\s+(\d{2}:\d{2}:\d{2},\d{3})\s+([\s\S]*?)(?=\n\n|\$)');
    final matches = regex.allMatches(srt);
    for (final match in matches) {
      final start = _parseDuration(match.group(2)!);
      final end = _parseDuration(match.group(3)!);
      final text = match.group(4)!.trim().replaceAll('\n', ' ');
      subtitles.add(Subtitle(start: start, end: end, text: text));
    }
    return subtitles;
  }

  Duration _parseDuration(String timeString) {
    final parts = timeString.split(RegExp(r'[:,]'));
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: int.parse(parts[2]),
      milliseconds: int.parse(parts[3]),
    );
  }

  void _updateSubtitle() {
    if (!_showSubtitles || _subtitles.isEmpty || !_controller.value.isInitialized) return;
    final position = _controller.value.position;
    final current = _subtitles.firstWhere(
        (sub) => position >= sub.start && position <= sub.end,
        orElse: () => Subtitle(start: Duration.zero, end: Duration.zero, text: ""));
    if (mounted) {
      setState(() {
        _currentSubtitle = current.text;
      });
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isLocked) {
        setState(() {
          _showControls = false;
          if (_showNextEpisodeBar || _showRecommendationsBar) _showControls = true;
        });
      }
    });
  }

  void _toggleControls() {
    if (!mounted || _isLocked) return;
    setState(() {
      _showControls = true; // Only show controls, no toggle off here
      if (_recommendationTimer != null) {
        _recommendationTimer!.cancel();
        _showRecommendationsBar = false;
      }
    });
    _startHideTimer();
  }

  Future<void> _retryLoad() async {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
      _isInitialized = false;
    });
    await _initializeVideoPath();
    await _initializeVideo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _recommendationTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.pause().then((_) => _controller.dispose());
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartPosition = _controller.value.position;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_controller.value.isInitialized || _dragStartX == null || _dragStartPosition == null) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx - _dragStartX!;
    final offset = dx / screenWidth * _controller.value.duration.inSeconds;
    final newPosition = (_dragStartPosition!.inSeconds + offset).clamp(0, _controller.value.duration.inSeconds);
    setState(() {
      _seekTargetDuration = Duration(seconds: newPosition.round());
      _showControls = true;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_seekTargetDuration != null) {
      _controller.seekTo(_seekTargetDuration!);
      setState(() {
        _seekTargetDuration = null;
      });
      _dragStartX = null;
      _dragStartPosition = null;
      _startHideTimer();
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _startX = details.globalPosition.dx;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final delta = -details.delta.dy / screenHeight;
    if (_startX == null) return;
    if (_startX! < screenWidth / 2 && !kIsWeb) {
      setState(() {
        _brightness = (_brightness + delta).clamp(0.0, 1.0);
        _isAdjustingBrightness = true;
        _showControls = true;
      });
      _setBrightness(_brightness);
    } else {
      setState(() {
        _volume = (_volume + delta).clamp(0.0, 1.0);
        _controller.setVolume(_volume);
        _isMuted = _volume == 0;
        _isAdjustingVolume = true;
        _showControls = true;
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _isAdjustingBrightness = false;
      _isAdjustingVolume = false;
    });
    _startHideTimer();
  }

  void _showQualityMenu() async {
    final quality = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 100, 100),
      items: _qualities.map((q) => PopupMenuItem<String>(value: q, child: Text(q))).toList(),
    );
    if (quality != null && quality != _selectedQuality) {
      setState(() {
        _selectedQuality = quality;
      });
      await _fetchNewQualityStream(quality);
      _startHideTimer();
    }
  }

  Future<void> _fetchNewQualityStream(String quality) async {
    try {
      final streamingInfo = await StreamingService.getStreamingLink(
        tmdbId: widget.title.hashCode.toString(),
        title: widget.title,
        releaseYear: widget.releaseYear,
        resolution: quality == "Auto" ? "auto" : quality,
        enableSubtitles: _showSubtitles,
      );
      final newUrl = streamingInfo['url'] ?? _currentVideoPath;
      final newSubtitleUrl = streamingInfo['subtitleUrl'];
      final isHls = streamingInfo['type'] == 'm3u8';
      await _switchVideo(newUrl, widget.title, newSubtitleUrl: newSubtitleUrl, isHls: isHls);
    } catch (e) {
      debugPrint('Failed to fetch new quality stream: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to switch quality: $e")),
        );
      }
    }
  }

  void _showSpeedMenu() async {
    final speed = await showMenu<double>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 100, 100),
      items: [
        const PopupMenuItem(value: 0.5, child: Text('0.5x')),
        const PopupMenuItem(value: 1.0, child: Text('1.0x')),
        const PopupMenuItem(value: 1.25, child: Text('1.25x')),
        const PopupMenuItem(value: 1.5, child: Text('1.5x')),
        const PopupMenuItem(value: 1.75, child: Text('1.75x')),
        const PopupMenuItem(value: 2.0, child: Text('2.0x')),
      ],
    );
    if (speed != null) {
      setState(() {
        _playbackSpeed = speed;
      });
      await _controller.setPlaybackSpeed(speed);
      _startHideTimer();
    }
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Customize Player', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Control Color:', style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 8),
                  DropdownButton<Color>(
                    value: _controlColor,
                    dropdownColor: Colors.black87,
                    items: const [
                      DropdownMenuItem(value: Colors.white, child: Text('White', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: Colors.yellow, child: Text('Yellow', style: TextStyle(color: Colors.yellow))),
                      DropdownMenuItem(value: Colors.red, child: Text('Red', style: TextStyle(color: Colors.red))),
                    ],
                    onChanged: (color) {
                      if (mounted) {
                        setState(() {
                          _controlColor = color!;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Icon Size:', style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CupertinoSegmentedControl<String>(
                      groupValue: _iconSizeKey,
                      children: _iconSizePresets.map((label, size) {
                        return MapEntry(
                          label,
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Text(label, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                          ),
                        );
                      }),
                      onValueChanged: (value) {
                        if (mounted) {
                          setState(() {
                            _iconSizeKey = value;
                            _iconSize = _iconSizePresets[value]!;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close Settings')),
            ],
          ),
        );
      },
    ).whenComplete(_startHideTimer);
  }

  int? _extractEpisodeNumber(String videoPath) {
    final match = RegExp(r'[sS]\d+[eE](\d+)').firstMatch(videoPath);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  void _checkForEndOfContent() {
    if (!_controller.value.isInitialized) return;
    final position = _controller.value.position;
    final duration = _controller.value.duration;
    final remaining = duration - position;

    if (remaining <= const Duration(seconds: 30)) {
      if (widget.isFullSeason && !_showNextEpisodeBar) {
        setState(() {
          _showNextEpisodeBar = true;
          _showControls = true;
        });
        _fetchNextEpisode();
      } else if (!widget.isFullSeason && !_showRecommendationsBar) {
        setState(() {
          _showRecommendationsBar = true;
          _showControls = true;
        });
        _fetchRecommendations();
      }
    }

    if (remaining <= Duration.zero) {
      if (widget.isFullSeason && _nextEpisodeData != null) {
        _playNextEpisode();
      } else if (!widget.isFullSeason && _recommendationData != null) {
        _playRecommendedMovie();
      }
    }
  }

  void _fetchNextEpisode() {
    if (_currentEpisodeNumber == null || !widget.isFullSeason || widget.episodeFiles.isEmpty) return;
    final currentIndex = widget.episodeFiles.indexOf(_currentVideoPath);
    if (currentIndex != -1 && currentIndex < widget.episodeFiles.length - 1) {
      final nextVideoPath = widget.episodeFiles[currentIndex + 1];
      if (mounted) {
        setState(() {
          _nextEpisodeData = {'videoPath': nextVideoPath};
        });
      }
    }
  }

  Future<void> _fetchRecommendations() async {
    if (widget.similarMovies.isEmpty) return;
    final recommendation = widget.similarMovies.first;
    try {
      final releaseDate = recommendation['release_date'] as String? ?? recommendation['first_air_date'] as String? ?? '1970-01-01';
      final releaseYear = int.parse(releaseDate.split('-')[0]);
      final streamingInfo = await StreamingService.getStreamingLink(
        tmdbId: recommendation['id'].toString(),
        title: recommendation['title']?.toString() ?? recommendation['name']?.toString() ?? 'Untitled',
        releaseYear: releaseYear,
        resolution: _selectedQuality,
        enableSubtitles: _showSubtitles,
      );
      if (mounted) {
        setState(() {
          _recommendationData = {
            'title': streamingInfo['title'] ?? recommendation['title'] ?? recommendation['name'] ?? 'Untitled',
            'videoPath': streamingInfo['url'] ?? '',
          };
        });
        if (streamingInfo['url'] != null && streamingInfo['url']!.isNotEmpty) {
          _recommendationTimer?.cancel();
          _recommendationTimer = Timer(const Duration(seconds: 10), () {
            if (mounted && _recommendationData != null) {
              _playRecommendedMovie();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch streaming URL for recommendation: $e');
    }
  }

  void _playRecommendedMovie() {
    if (_recommendationData == null || _recommendationData!['videoPath'].isEmpty) return;
    final nextVideoPath = _recommendationData!['videoPath'];
    final nextTitle = _recommendationData!['title'];
    if (nextVideoPath != null) {
      _switchVideo(nextVideoPath, nextTitle);
    }
  }

  Future<void> _switchEpisode(String videoPath) async {
    if (!mounted) return;
    setState(() {
      _currentVideoPath = videoPath;
      _currentEpisodeNumber = _extractEpisodeNumber(videoPath);
      _showNextEpisodeBar = false;
      _nextEpisodeData = null;
      _isInitialized = false;
    });
    await _controller.pause();
    await _controller.dispose();
    await _initializeVideo();
    await _loadSubtitles();
  }

  Future<void> _switchVideo(String videoPath, String title, {String? newSubtitleUrl, bool isHls = false}) async {
    if (!mounted) return;
    setState(() {
      _currentVideoPath = videoPath;
      _title = title;
      _showRecommendationsBar = false;
      _recommendationData = null;
      _isInitialized = false;
    });
    await _controller.pause();
    await _controller.dispose();
    final newWidget = MainVideoPlayer(
      videoPath: videoPath,
      title: title,
      releaseYear: widget.releaseYear,
      isFullSeason: widget.isFullSeason,
      episodeFiles: widget.episodeFiles,
      similarMovies: widget.similarMovies,
      subtitleUrl: newSubtitleUrl ?? widget.subtitleUrl,
      localSubtitlePath: widget.localSubtitlePath,
      isHls: isHls,
      isLocal: widget.isLocal,
    );
    setState(() {
      _currentVideoPath = newWidget.videoPath;
      _title = newWidget.title;
    });
    await _initializeVideo();
    await _loadSubtitles();
  }

  void _showEpisodeMenu() async {
    if (!widget.isFullSeason || widget.episodeFiles.isEmpty) return;
    final episode = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 100, 100),
      items: widget.episodeFiles.asMap().entries.map((entry) => PopupMenuItem<String>(value: entry.value, child: Text("Episode ${entry.key + 1}"))).toList(),
    );
    if (episode != null && episode != _currentVideoPath) {
      await _switchEpisode(episode);
    }
    _startHideTimer();
  }

  void _playNextEpisode() {
    if (_nextEpisodeData == null || _nextEpisodeData!['videoPath'] == null) return;
    final nextVideoPath = _nextEpisodeData!['videoPath']!;
    _switchEpisode(nextVideoPath);
  }

  Widget _buildControls() {
    if (!_controller.value.isInitialized) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Colors.black87, Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: _controlColor, size: _iconSize),
                      onPressed: () {
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _controlColor, fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.high_quality, color: _controlColor, size: _iconSize),
                          onPressed: _showQualityMenu,
                        ),
                        IconButton(
                          icon: Icon(Icons.speed, color: _controlColor, size: _iconSize),
                          onPressed: _showSpeedMenu,
                        ),
                        IconButton(
                          icon: Icon(Icons.settings, color: _controlColor, size: _iconSize),
                          onPressed: _showSettingsMenu,
                        ),
                        IconButton(
                          icon: Icon(_showSubtitles ? Icons.closed_caption : Icons.closed_caption_off, color: _controlColor, size: _iconSize),
                          onPressed: () {
                            setState(() {
                              _showSubtitles = !_showSubtitles;
                            });
                            _startHideTimer();
                          },
                        ),
                        if (widget.isFullSeason)
                          IconButton(
                            icon: Icon(Icons.list, color: _controlColor, size: _iconSize),
                            onPressed: _showEpisodeMenu,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showSubtitles && _currentSubtitle.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: Text(
                _currentSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(offset: Offset(1, 1), color: Colors.black, blurRadius: 2)]),
              ),
            ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  iconSize: _iconSize,
                  icon: Icon(Icons.replay_10, color: _controlColor),
                  onPressed: () {
                    final newPos = _controller.value.position - const Duration(seconds: 10);
                    _controller.seekTo(newPos > Duration.zero ? newPos : Duration.zero);
                    _startHideTimer();
                  },
                ),
                IconButton(
                  iconSize: _iconSize + 24,
                  icon: Icon(_controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: _controlColor),
                  onPressed: () {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    });
                    _startHideTimer();
                  },
                ),
                IconButton(
                  iconSize: _iconSize,
                  icon: Icon(Icons.forward_10, color: _controlColor),
                  onPressed: () {
                    final newPos = _controller.value.position + const Duration(seconds: 10);
                    if (newPos < _controller.value.duration) {
                      _controller.seekTo(newPos);
                    }
                    _startHideTimer();
                  },
                ),
              ],
            ),
          ),
          if (_seekTargetDuration != null)
            Center(child: Text(_formatDuration(_seekTargetDuration!), style: const TextStyle(color: Colors.white, fontSize: 24))),
          if (_seekFeedback != null)
            Center(child: Text(_seekFeedback!, style: const TextStyle(color: Colors.white, fontSize: 24))),
          if (_showNextEpisodeBar)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _nextEpisodeData != null ? 'Next: Episode ${_extractEpisodeNumber(_nextEpisodeData!['videoPath']!)}' : 'Loading next episode...',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    ElevatedButton(onPressed: _nextEpisodeData != null ? _playNextEpisode : null, child: const Text('Play Now')),
                  ],
                ),
              ),
            ),
          if (_showRecommendationsBar && _recommendationData != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Up Next: ${_recommendationData!['title']}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ElevatedButton(onPressed: _playRecommendedMovie, child: const Text('Play Now')),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black87], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(playedColor: Colors.deepPurpleAccent, backgroundColor: Colors.grey, bufferedColor: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(_formatDuration(_controller.value.position), style: TextStyle(color: _controlColor, fontSize: 14)),
                        const Spacer(),
                        IconButton(
                          icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: _controlColor, size: _iconSize),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.black87,
                                title: const Text('Volume', style: TextStyle(color: Colors.white)),
                                content: Slider(
                                  value: _volume,
                                  onChanged: (value) {
                                    setState(() {
                                      _volume = value;
                                      _controller.setVolume(value);
                                      _isMuted = value == 0;
                                    });
                                  },
                                  min: 0,
                                  max: 1,
                                  divisions: 20,
                                  activeColor: Colors.deepPurpleAccent,
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.white))),
                                ],
                              ),
                            ).whenComplete(_startHideTimer);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.lock, color: _controlColor, size: _iconSize),
                          onPressed: () {
                            setState(() {
                              _isLocked = true;
                            });
                            _startHideTimer();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.fullscreen, color: _controlColor, size: _iconSize),
                          onPressed: () {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fullscreen toggled")));
                            }
                            _startHideTimer();
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(_formatDuration(_controller.value.duration), style: TextStyle(color: _controlColor, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _retryLoad, child: const Text('Retry')),
                ],
              ),
            )
          : _isInitialized
              ? GestureDetector(
                  onTap: _isLocked ? null : _toggleControls, // Single tap only shows controls
                  onDoubleTap: _isLocked
                      ? null
                      : () {
                          if (_lastTapPosition == null) return;
                          final screenWidth = MediaQuery.of(context).size.width;
                          final tapX = _lastTapPosition!.dx;
                          if (tapX < screenWidth / 3) {
                            final newPos = _controller.value.position - const Duration(seconds: 10);
                            _controller.seekTo(newPos > Duration.zero ? newPos : Duration.zero);
                            setState(() {
                              _seekFeedback = "-10s";
                            });
                          } else if (tapX > screenWidth * 2 / 3) {
                            final newPos = _controller.value.position + const Duration(seconds: 10);
                            if (newPos < _controller.value.duration) {
                              _controller.seekTo(newPos);
                            }
                            setState(() {
                              _seekFeedback = "+10s";
                            });
                          }
                          _lastTapPosition = null;
                          Timer(const Duration(seconds: 1), () {
                            if (mounted) {
                              setState(() {
                                _seekFeedback = null;
                              });
                            }
                          });
                        },
                  onTapDown: _isLocked ? null : (details) => _lastTapPosition = details.globalPosition,
                  onHorizontalDragStart: _isLocked ? null : _onHorizontalDragStart,
                  onHorizontalDragUpdate: _isLocked ? null : _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _isLocked ? null : _onHorizontalDragEnd,
                  onVerticalDragStart: _isLocked ? null : _onVerticalDragStart,
                  onVerticalDragUpdate: _isLocked ? null : _onVerticalDragUpdate,
                  onVerticalDragEnd: _isLocked ? null : _onVerticalDragEnd,
                  child: Stack(
                    children: [
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(width: _controller.value.size.width, height: _controller.value.size.height, child: VideoPlayer(_controller)),
                        ),
                      ),
                      if (_isBuffering) const Center(child: CircularProgressIndicator()),
                      if (_isLocked)
                        Center(
                          child: IconButton(
                            icon: Icon(Icons.lock, color: _controlColor, size: _iconSize + 10),
                            onPressed: () {
                              setState(() {
                                _isLocked = false;
                              });
                            },
                          ),
                        )
                      else
                        _buildControls(),
                      if (_isAdjustingBrightness && !kIsWeb)
                        Positioned(
                          left: 16,
                          top: MediaQuery.of(context).size.height / 2 - 50,
                          child: Column(
                            children: [
                              const Icon(Icons.brightness_6, color: Colors.white, size: 32),
                              Text('${(_brightness * 100).round()}%', style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      if (_isAdjustingVolume)
                        Positioned(
                          right: 16,
                          top: MediaQuery.of(context).size.height / 2 - 50,
                          child: Column(
                            children: [
                              const Icon(Icons.volume_up, color: Colors.white, size: 32),
                              Text('${(_volume * 100).round()}%', style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
