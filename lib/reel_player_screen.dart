import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'models/reel.dart'; // Import your Reel model

class ReelPlayerScreen extends StatefulWidget {
  final List<Reel> reels;
  final int initialIndex;

  const ReelPlayerScreen({
    Key? key,
    required this.reels,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _ReelPlayerScreenState createState() => _ReelPlayerScreenState();
}

class _ReelPlayerScreenState extends State<ReelPlayerScreen> {
  late PageController _pageController;
  int currentIndex = 0;
  /// Map to hold active controllers only for the current, previous, and next pages.
  final Map<int, YoutubePlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex, viewportFraction: 1.0);
    _updateControllers(currentIndex);
    // Ensure the current video plays.
    _controllers[currentIndex]?.play();
  }

  /// Update the controllers: only keep controllers for currentIndex-1, currentIndex, and currentIndex+1.
  void _updateControllers(int newIndex) {
    final activeIndices = <int>{newIndex - 1, newIndex, newIndex + 1};

    // Dispose controllers that are no longer active.
    _controllers.keys.toList().forEach((index) {
      if (!activeIndices.contains(index)) {
        _controllers[index]?.dispose();
        _controllers.remove(index);
      }
    });

    // For each active index, ensure a controller exists.
    for (var index in activeIndices) {
      if (index >= 0 && index < widget.reels.length && !_controllers.containsKey(index)) {
        final reel = widget.reels[index];
        final videoId = YoutubePlayer.convertUrlToId(reel.videoUrl) ?? "";
        if (videoId.isNotEmpty) {
          _controllers[index] = YoutubePlayerController(
  initialVideoId: videoId,
  flags: YoutubePlayerFlags(
    autoPlay: newIndex == index, // ✔️ dynamic value allowed now
    mute: false,
    hideControls: true,
    controlsVisibleAtStart: false,
    enableCaption: false,
  ),
);

        }
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      // Pause the controller for the previous currentIndex if exists.
      _controllers[currentIndex]?.pause();
      currentIndex = index;
      _updateControllers(currentIndex);
      // Play the new controller.
      _controllers[currentIndex]?.play();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemCount: widget.reels.length,
            onPageChanged: _onPageChanged,
            physics: const ClampingScrollPhysics(),
            itemBuilder: (context, index) {
              // It's safe to force unwrap here because _updateControllers guarantees a controller exists.
              final reel = widget.reels[index];
              final controller = _controllers[index]!;
              return ReelVideoPage(
                reel: reel,
                controller: controller,
              );
            },
          ),
          // Page Indicator
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.reels.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentIndex == index ? 12 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentIndex == index ? Colors.redAccent : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class ReelVideoPage extends StatefulWidget {
  final Reel reel;
  final YoutubePlayerController controller;

  const ReelVideoPage({
    Key? key,
    required this.reel,
    required this.controller,
  }) : super(key: key);

  @override
  _ReelVideoPageState createState() => _ReelVideoPageState();
}

class _ReelVideoPageState extends State<ReelVideoPage> {
  bool isLiked = false;
  int likeCount = 42; // Dummy initial like count
  List<String> comments = [
    "Amazing trailer!",
    "Can’t wait to watch this!",
    "Epic scenes!",
  ]; // Dummy comments
  TextEditingController commentController = TextEditingController();

  // Controls for the play/pause overlay.
  bool _showControls = false;
  Timer? _hideControlTimer;
  
  // Toggle the overlay on tap.
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    // Auto-hide the controls after 3 seconds.
    if (_showControls) {
      _hideControlTimer?.cancel();
      _hideControlTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    _hideControlTimer?.cancel();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
  }

  void _addComment() {
    if (commentController.text.trim().isNotEmpty) {
      setState(() {
        comments.add(commentController.text.trim());
      });
      commentController.clear();
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            comments.removeLast(); // Remove comment after delay.
          });
        }
      });
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 400,
              decoration: BoxDecoration(
                color: const Color.fromARGB(180, 17, 19, 40),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Comments (${comments.length})",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(
                                comments[index],
                                style: const TextStyle(color: Colors.white70),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: commentController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "Add a comment...",
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.deepPurpleAccent),
                              onPressed: () {
                                _addComment();
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tapping anywhere toggles the play/pause overlay.
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          YoutubePlayer(
            controller: widget.controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.redAccent,
            aspectRatio: 9 / 16,
          ),
          // Overlay play/pause button
          if (_showControls)
            Center(
              child: IconButton(
                iconSize: 64,
                icon: Icon(
                  widget.controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.white.withOpacity(0.8),
                ),
                onPressed: () {
                  setState(() {
                    if (widget.controller.value.isPlaying) {
                      widget.controller.pause();
                    } else {
                      widget.controller.play();
                    }
                    _showControls = false;
                    _hideControlTimer?.cancel();
                  });
                },
              ),
            ),
          // Top overlay for title and description (glassmorphism style)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.reel.movieTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black87, offset: Offset(2, 2)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.reel.movieDescription,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            shadows: [
                              Shadow(blurRadius: 2, color: Colors.black87, offset: Offset(1, 1)),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right action buttons: Like, Comment, Share.
          Positioned(
            bottom: 80,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(180, 17, 19, 40),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Like button and count.
                      Column(
                        children: [
                          IconButton(
                            icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.redAccent : Colors.white,
                              size: 32,
                            ),
                            onPressed: _toggleLike,
                          ),
                          Text(
                            likeCount.toString(),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Comment button and count.
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.comment, color: Colors.white, size: 32),
                            onPressed: _showComments,
                          ),
                          Text(
                            comments.length.toString(),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Share button.
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white, size: 32),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Shared: ${widget.reel.movieTitle}")),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

