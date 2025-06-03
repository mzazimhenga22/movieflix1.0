// video_player_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Main video player screen with controls.
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isMuted = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  // If the video URL is from YouTube, we disable auto-hide so that our custom controls remain visible.
  late final bool _autoHideControls;

  @override
  void initState() {
    super.initState();
    // Determine if we should auto-hide controls.
    _autoHideControls = !widget.videoUrl.toLowerCase().contains("youtube");
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        if (_autoHideControls) {
          _startHideTimer();
        }
      });
  }

  /// Hides the overlay controls after a short delay if auto-hiding is enabled.
  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_autoHideControls) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        setState(() {
          _controlsVisible = false;
        });
      });
    }
  }

  /// Toggle visibility of controls when the user taps the video.
  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible && _autoHideControls) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Optional transparent app bar.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Video Player'),
      ),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Center(
          child: _controller.value.isInitialized
              ? Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    if (_controlsVisible) _buildControls(),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }

  /// Builds the overlay controls.
  Widget _buildControls() {
    final position = _controller.value.position;
    final duration = _controller.value.duration;
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar with scrubbing support.
          VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            colors: const VideoProgressColors(
              playedColor: Colors.red,
              backgroundColor: Colors.grey,
              bufferedColor: Colors.white70,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Play/Pause Button.
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                      if (_autoHideControls) {
                        _startHideTimer();
                      }
                    }
                  });
                },
              ),
              // Duration display.
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(color: Colors.white),
              ),
              // Mute/Unmute Button.
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isMuted = !_isMuted;
                    _controller.setVolume(_isMuted ? 0.0 : 1.0);
                  });
                },
              ),
              // Fullscreen Button.
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenVideoPlayer(
                        controller: _controller,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Helper to format a Duration into mm:ss.
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

/// Fullscreen video player view.
class FullScreenVideoPlayer extends StatelessWidget {
  final VideoPlayerController controller;
  const FullScreenVideoPlayer({Key? key, required this.controller})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Optionally force landscape mode or handle orientation.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: controller.value.isInitialized
            ? GestureDetector(
                onTap: () => Navigator.pop(context),
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

/// Helper function to navigate to the VideoPlayerScreen.
void playVideo(BuildContext context, String videoUrl) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
    ),
  );
}
