import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/reel.dart';

class FeedReelPlayerScreen extends StatefulWidget {
  final List<Reel> reels;
  final int initialIndex;

  const FeedReelPlayerScreen({
    Key? key,
    required this.reels,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _FeedReelPlayerScreenState createState() => _FeedReelPlayerScreenState();
}

class _FeedReelPlayerScreenState extends State<FeedReelPlayerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final Map<int, VideoPlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize the current index and page controller
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    // Load the initial video controller
    _initializeController(_currentIndex);
  }

  // Initialize video controller for a given index
  void _initializeController(int index) {
    // Check if index is valid
    if (index < 0 || index >= widget.reels.length) return;

    // Dispose controllers outside the active range (previous, current, next)
    final activeIndices = {index - 1, index, index + 1};
    _controllers.keys.toList().forEach((i) {
      if (!activeIndices.contains(i)) {
        _controllers[i]?.dispose();
        _controllers.remove(i);
      }
    });

    // Initialize controller for the current index if not already
    if (!_controllers.containsKey(index)) {
      final reel = widget.reels[index];
      _controllers[index] = VideoPlayerController.network(reel.videoUrl)
        ..initialize().then((_) {
          // Play video if it's the current index and widget is still mounted
          if (mounted && index == _currentIndex) {
            _controllers[index]?.play();
            setState(() {});
          }
        }).catchError((e) {
          debugPrint('Error initializing video: $e');
        });
    }
  }

  // Handle page change when user swipes
  void _onPageChanged(int index) {
    setState(() {
      // Pause the current video
      _controllers[_currentIndex]?.pause();
      // Update current index
      _currentIndex = index;
      // Initialize new video
      _initializeController(index);
      // Play the new video
      _controllers[index]?.play();
    });
  }

  @override
  void dispose() {
    // Clean up resources
    _pageController.dispose();
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player with swipeable navigation
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.reels.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final reel = widget.reels[index];
              final controller = _controllers[index];
              // Show loading indicator if video isn't ready
              if (controller == null || !controller.value.isInitialized) {
                return const Center(child: CircularProgressIndicator());
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Video player
                  Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  // Video metadata (title and description)
                  Positioned(
                    bottom: 100,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reel.movieTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 2,
                                color: Colors.black54,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          reel.movieDescription,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            shadows: [
                              Shadow(
                                blurRadius: 2,
                                color: Colors.black54,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Interaction buttons (right side)
                  Positioned(
                    right: 16,
                    top: MediaQuery.of(context).size.height * 0.3,
                    child: Column(
                      children: [
                        // Like button
                        IconButton(
                          icon: const Icon(
                            Icons.favorite_border,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            // TODO: Implement like functionality
                          },
                        ),
                        const Text(
                          '0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            shadows: [
                              Shadow(
                                blurRadius: 2,
                                color: Colors.black54,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Dislike button
                        IconButton(
                          icon: const Icon(
                            Icons.thumb_down_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            // TODO: Implement dislike functionality
                          },
                        ),
                        const Text(
                          '0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            shadows: [
                              Shadow(
                                blurRadius: 2,
                                color: Colors.black54,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Comment button
                        IconButton(
                          icon: const Icon(
                            Icons.comment,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            // TODO: Implement comment functionality
                          },
                        ),
                        const Text(
                          '0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            shadows: [
                              Shadow(
                                blurRadius: 2,
                                color: Colors.black54,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Share button
                        IconButton(
                          icon: const Icon(
                            Icons.share,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            // TODO: Implement share functionality
                          },
                        ),
                        const Text(
                          '0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            shadows: [
                              Shadow(
                                blurRadius: 2,
                                color: Colors.black54,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // Back button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
