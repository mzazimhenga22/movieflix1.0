import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Subtitle {
  final Duration start;
  final Duration end;
  final String text;

  Subtitle({required this.start, required this.end, required this.text});
}

/// Main video player screen with controls styled like MainVideoPlayer.
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String? subtitleUrl;
  const VideoPlayerScreen({Key? key, required this.videoUrl, this.subtitleUrl})
      : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isBuffering = false;
  bool _isMuted = false;
  bool _controlsVisible = false; // Controls start hidden
  Timer? _hideTimer;
  bool _autoHideControls = true;
  double _volume = 1.0;
  double _brightness = 0.5;
  bool _isLocked = false;
  bool _isAdjustingBrightness = false;
  bool _isAdjustingVolume = false;
  double? _startX;
  double _playbackSpeed = 1.0;
  List<Subtitle> _subtitles = [];
  String _currentSubtitle = "";
  bool _showSubtitles = true;
  Offset? _lastTapPosition;
  String? _seekFeedback;
  Duration? _seekTargetDuration;
  double? _dragStartX;
  Duration? _dragStartPosition;
  Color _controlColor = Colors.white;
  double _iconSize = 30;
  final Map<String, double> _iconSizePresets = {
    'Small': 30,
    'Medium': 44,
    'Large': 63,
  };
  String _iconSizeKey = 'Small';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoHideControls = !widget.videoUrl.toLowerCase().contains("youtube");
    _enforceLandscape();
    _initializeVideo();
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
    if (kIsWeb) return;
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

Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: {
          'Accept': '*/*',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Referer': 'https://www.youtube.com/',
        },
      );
      _controller.addListener(_videoListener);
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _volume = _controller.value.volume;
        });
        await _controller.play();
        await _controller.setPlaybackSpeed(_playbackSpeed);
        if (_autoHideControls && !widget.videoUrl.toLowerCase().contains("youtube")) {
          _startHideTimer();
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load video: $error";
        });
      }
    }
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _isBuffering = _controller.value.isBuffering;
        _updateSubtitle();
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
    if (widget.subtitleUrl != null && widget.subtitleUrl!.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(widget.subtitleUrl!));
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _subtitles = _parseSrt(response.body);
            });
          }
        } else {
          debugPrint('Failed to fetch subtitles: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Failed to load subtitles: $e');
      }
    }
  }

  List<Subtitle> _parseSrt(String srt) {
    final List<Subtitle> subtitles = [];
    final regex = RegExp(
        r'(\d+)\s+(\d{2}:\d{2}:\d{2},\d{3})\s+-->\s+(\d{2}:\d{2}:\d{2},\d{3})\s+([\s\S]*?)(?=\n\n|\$)');
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
    if (!_showSubtitles ||
        _subtitles.isEmpty ||
        !_controller.value.isInitialized) return;
    final position = _controller.value.position;
    final current = _subtitles.firstWhere(
        (sub) => position >= sub.start && position <= sub.end,
        orElse: () =>
            Subtitle(start: Duration.zero, end: Duration.zero, text: ""));
    if (mounted) {
      setState(() {
        _currentSubtitle = current.text;
      });
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_autoHideControls && !_isLocked) {
      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _controlsVisible = false;
          });
        }
      });
    }
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() {
      _controlsVisible = true; // Only show controls, no toggle off
    });
    _startHideTimer();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartPosition = _controller.value.position;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_controller.value.isInitialized ||
        _dragStartX == null ||
        _dragStartPosition == null) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx - _dragStartX!;
    final offset = dx / screenWidth * _controller.value.duration.inSeconds;
    final newPosition = (_dragStartPosition!.inSeconds + offset)
        .clamp(0, _controller.value.duration.inSeconds);
    setState(() {
      _seekTargetDuration = Duration(seconds: newPosition.round());
      _controlsVisible = true;
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
        _controlsVisible = true;
      });
      _setBrightness(_brightness);
    } else {
      setState(() {
        _volume = (_volume + delta).clamp(0.0, 1.0);
        _controller.setVolume(_volume);
        _isMuted = _volume == 0;
        _isAdjustingVolume = true;
        _controlsVisible = true;
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Customize Player',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Control Color:',
                      style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 8),
                  DropdownButton<Color>(
                    value: _controlColor,
                    dropdownColor: Colors.black87,
                    items: const [
                      DropdownMenuItem(
                          value: Colors.white,
                          child: Text('White',
                              style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: Colors.yellow,
                          child: Text('Yellow',
                              style: TextStyle(color: Colors.yellow))),
                      DropdownMenuItem(
                          value: Colors.red,
                          child:
                              Text('Red', style: TextStyle(color: Colors.red))),
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
                  const Text('Icon Size:',
                      style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CupertinoSegmentedControl<String>(
                      groupValue: _iconSizeKey,
                      children: _iconSizePresets.map((label, size) {
                        return MapEntry(
                          label,
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Text(label,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center),
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
              ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close Settings')),
            ],
          ),
        );
      },
    ).whenComplete(_startHideTimer);
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

  Widget _buildControls() {
    if (!_controller.value.isInitialized) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1.0 : 0.0,
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
                gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: _controlColor, size: _iconSize),
                      onPressed: () {
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Trailer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.speed,
                              color: _controlColor, size: _iconSize),
                          onPressed: _showSpeedMenu,
                        ),
                        IconButton(
                          icon: Icon(Icons.settings,
                              color: _controlColor, size: _iconSize),
                          onPressed: _showSettingsMenu,
                        ),
                        IconButton(
                          icon: Icon(
                              _showSubtitles
                                  ? Icons.closed_caption
                                  : Icons.closed_caption_off,
                              color: _controlColor,
                              size: _iconSize),
                          onPressed: () {
                            setState(() {
                              _showSubtitles = !_showSubtitles;
                            });
                            _startHideTimer();
                          },
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
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                          offset: Offset(1, 1),
                          color: Colors.black,
                          blurRadius: 2)
                    ]),
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
                    final newPos = _controller.value.position -
                        const Duration(seconds: 10);
                    _controller.seekTo(
                        newPos > Duration.zero ? newPos : Duration.zero);
                    _startHideTimer();
                  },
                ),
                IconButton(
                  iconSize: _iconSize + 24,
                  icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: _controlColor),
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
                    final newPos = _controller.value.position +
                        const Duration(seconds: 10);
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
            Center(
                child: Text(_formatDuration(_seekTargetDuration!),
                    style: const TextStyle(color: Colors.white, fontSize: 24))),
          if (_seekFeedback != null)
            Center(
                child: Text(_seekFeedback!,
                    style: const TextStyle(color: Colors.white, fontSize: 24))),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter)),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                          playedColor: Colors.deepPurpleAccent,
                          backgroundColor: Colors.grey,
                          bufferedColor: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(_formatDuration(_controller.value.position),
                            style:
                                TextStyle(color: _controlColor, fontSize: 14)),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                              _isMuted ? Icons.volume_off : Icons.volume_up,
                              color: _controlColor,
                              size: _iconSize),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.black87,
                                title: const Text('Volume',
                                    style: TextStyle(color: Colors.white)),
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
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close',
                                          style:
                                              TextStyle(color: Colors.white))),
                                ],
                              ),
                            ).whenComplete(_startHideTimer);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.lock,
                              color: _controlColor, size: _iconSize),
                          onPressed: () {
                            setState(() {
                              _isLocked = true;
                            });
                            _startHideTimer();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.fullscreen,
                              color: _controlColor, size: _iconSize),
                          onPressed: () {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Fullscreen toggled")));
                            }
                            _startHideTimer();
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(_formatDuration(_controller.value.duration),
                            style:
                                TextStyle(color: _controlColor, fontSize: 14)),
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
                  Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _initializeVideo, child: const Text('Retry')),
                ],
              ),
            )
          : _isInitialized
              ? GestureDetector(
                  onTap: _isLocked ? null : _toggleControls,
                  onDoubleTap: _isLocked
                      ? null
                      : () {
                          if (_lastTapPosition == null) return;
                          final screenWidth = MediaQuery.of(context).size.width;
                          final tapX = _lastTapPosition!.dx;
                          if (tapX < screenWidth / 3) {
                            final newPos = _controller.value.position -
                                const Duration(seconds: 10);
                            _controller.seekTo(newPos > Duration.zero
                                ? newPos
                                : Duration.zero);
                            setState(() {
                              _seekFeedback = "-10s";
                            });
                          } else if (tapX > screenWidth * 2 / 3) {
                            final newPos = _controller.value.position +
                                const Duration(seconds: 10);
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
                  onTapDown: _isLocked
                      ? null
                      : (details) => _lastTapPosition = details.globalPosition,
                  onHorizontalDragStart:
                      _isLocked ? null : _onHorizontalDragStart,
                  onHorizontalDragUpdate:
                      _isLocked ? null : _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _isLocked ? null : _onHorizontalDragEnd,
                  onVerticalDragStart: _isLocked ? null : _onVerticalDragStart,
                  onVerticalDragUpdate:
                      _isLocked ? null : _onVerticalDragUpdate,
                  onVerticalDragEnd: _isLocked ? null : _onVerticalDragEnd,
                  child: Stack(
                    children: [
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                              width: _controller.value.size.width,
                              height: _controller.value.size.height,
                              child: VideoPlayer(_controller)),
                        ),
                      ),
                      if (_isBuffering)
                        const Center(child: CircularProgressIndicator()),
                      if (_isLocked)
                        Center(
                          child: IconButton(
                            icon: Icon(Icons.lock,
                                color: _controlColor, size: _iconSize + 10),
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
                              const Icon(Icons.brightness_6,
                                  color: Colors.white, size: 32),
                              Text('${(_brightness * 100).round()}%',
                                  style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      if (_isAdjustingVolume)
                        Positioned(
                          right: 16,
                          top: MediaQuery.of(context).size.height / 2 - 50,
                          child: Column(
                            children: [
                              const Icon(Icons.volume_up,
                                  color: Colors.white, size: 32),
                              Text('${(_volume * 100).round()}%',
                                  style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
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
}

/// Helper function to navigate to the VideoPlayerScreen.
void playVideo(BuildContext context, String videoUrl, {String? subtitleUrl}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>
          VideoPlayerScreen(videoUrl: videoUrl, subtitleUrl: subtitleUrl),
    ),
  );
}

