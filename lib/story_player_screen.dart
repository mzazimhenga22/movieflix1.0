import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class StoryPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String storyTitle;
  final String storyDescription;
  final int durationSeconds;
  // Optional: list of stories for navigation.
  // Ensure each story map contains non-empty 'videoUrl', 'title', 'description'.
  final List<Map<String, dynamic>>? stories;
  final int currentIndex;

  const StoryPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.storyTitle,
    required this.storyDescription,
    this.durationSeconds = 30,
    this.stories,
    this.currentIndex = 0,
  }) : super(key: key);

  @override
  _StoryPlayerScreenState createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends State<StoryPlayerScreen> {
  late YoutubePlayerController _controller;
  Timer? _timer;
  double _progress = 0.0;
  late int _storyDuration;

  @override
  void initState() {
    super.initState();
    _storyDuration = widget.durationSeconds;
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl) ?? "";
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true,
        controlsVisibleAtStart: false,
      ),
    );
    // Do not start the timer here.
  }

  void _startProgressTimer() {
    _timer?.cancel();
    _progress = 0.0;
    // Update every 100ms. Total increments: _storyDuration * 10.
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _progress += 1 / (_storyDuration * 10);
        if (_progress >= 1.0) {
          _progress = 1.0;
          _timer?.cancel();
          _goToNextStory();
        }
      });
    });
  }

  void _goToNextStory() {
    if (widget.stories != null && widget.stories!.isNotEmpty) {
      final nextIndex = widget.currentIndex + 1;
      if (nextIndex < widget.stories!.length &&
          (widget.stories![nextIndex]['videoUrl'] ?? '').isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StoryPlayerScreen(
              videoUrl: widget.stories![nextIndex]['videoUrl'] ?? '',
              storyTitle: widget.stories![nextIndex]['title'] ?? '',
              storyDescription:
                  widget.stories![nextIndex]['description'] ?? '',
              durationSeconds: widget.durationSeconds,
              stories: widget.stories,
              currentIndex: nextIndex,
            ),
          ),
        );
      } else {
        // No next story available; exit.
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }

  void _goToPreviousStory() {
    if (widget.stories != null && widget.stories!.isNotEmpty) {
      final prevIndex = widget.currentIndex - 1;
      if (prevIndex >= 0 &&
          (widget.stories![prevIndex]['videoUrl'] ?? '').isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StoryPlayerScreen(
              videoUrl: widget.stories![prevIndex]['videoUrl'] ?? '',
              storyTitle: widget.stories![prevIndex]['title'] ?? '',
              storyDescription:
                  widget.stories![prevIndex]['description'] ?? '',
              durationSeconds: widget.durationSeconds,
              stories: widget.stories,
              currentIndex: prevIndex,
            ),
          ),
        );
      } else {
        // Already at the first story: restart current.
        setState(() {
          _progress = 0.0;
          _startProgressTimer();
        });
      }
    }
  }

  void _onTapDown(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;
    if (dx < width / 3) {
      // Left tap: previous story.
      _goToPreviousStory();
    } else if (dx > 2 * width / 3) {
      // Right tap: next story.
      _goToNextStory();
    } else {
      // Center tap: toggle play/pause.
      if (_controller.value.isPlaying) {
        _controller.pause();
        _timer?.cancel();
      } else {
        _controller.play();
        _startProgressTimer();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use a Scaffold with an AppBar.
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTapDown: _onTapDown,
        child: Stack(
          children: [
            // Fullscreen YouTube player.
            SizedBox.expand(
              child: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: false,
                onReady: () {
                  // Start the timer only when the video is loaded and ready.
                  _startProgressTimer();
                },
                bottomActions: const [],
              ),
            ),
            // Top progress bar.
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white30,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            // Top overlay: Story title & description.
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.storyTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black45,
                          offset: Offset(2, 2),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.storyDescription,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            // Bottom: Comment input bar with heart icon.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const TextField(
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Send a message',
                            hintStyle: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.favorite,
                          color: Colors.pinkAccent),
                      onPressed: () {
                        // Handle like action.
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
