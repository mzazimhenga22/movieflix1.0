import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;
  final void Function(String type, Map<String, dynamic> data)?
      onStoryInteraction;
  final String currentUserId;

  const StoryScreen({
    Key? key,
    required this.stories,
    required this.currentUserId,
    this.initialIndex = 0,
    this.onStoryInteraction,
  }) : super(key: key);

  @override
  _StoryScreenState createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  VideoPlayerController? _videoController;
  int _currentIndex = 0;
  final TextEditingController _replyController = TextEditingController();
  late List<Map<String, dynamic>> _activeStories;
  final FocusNode _replyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _activeStories = widget.stories;
    _currentIndex = widget.initialIndex.clamp(0, _activeStories.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _nextStory();
      });
    _loadStory(_currentIndex);

    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _animationController.stop();
        if (_videoController != null && _videoController!.value.isPlaying) {
          _videoController!.pause();
        }
      } else {
        if (_videoController != null && _videoController!.value.isInitialized) {
          _videoController!.play();
        } else {
          _animationController.forward();
        }
      }
    });
  }

  void _loadStory(int index) {
    _animationController.reset();
    _videoController?.dispose();
    _videoController = null;
    final story = _activeStories[index];
    final DateTime storyTime = DateTime.parse(story['timestamp']);
    if (DateTime.now().difference(storyTime) >= const Duration(hours: 24)) {
      _deleteStory(index);
      return;
    }
    if (story['type'] == 'video') {
      _videoController = VideoPlayerController.network(story['media'])
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _videoController!.play();
              _animationController.duration = _videoController!.value.duration;
              _animationController.forward();
            });
          }
        }).catchError((error) {
          debugPrint('Error initializing video: $error');
        });
    } else {
      _animationController.duration = const Duration(seconds: 5);
      _animationController.forward();
    }
  }

  void _nextStory() {
    if (_currentIndex < _activeStories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  void _deleteStory(int index) {
    final story = _activeStories[index];
    if (story['userId'] == widget.currentUserId) {
      FirebaseFirestore.instance
          .collection('stories')
          .doc(story['id'])
          .delete();
      setState(() {
        _activeStories.removeAt(index);
        if (_activeStories.isEmpty) {
          Navigator.pop(context);
          return;
        }
        _currentIndex = index.clamp(0, _activeStories.length - 1);
        _loadStory(_currentIndex);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Story deleted")),
      );
    }
  }

  void _updateChatWithInteraction(String type, String content) {
    if (widget.onStoryInteraction != null) {
      widget.onStoryInteraction!(type, {
        'storyUser': _activeStories[_currentIndex]['user'],
        'storyUserId': _activeStories[_currentIndex]['userId'],
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _videoController?.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeStories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Text("No active stories",
                style: TextStyle(color: Colors.white))),
      );
    }
    final story = _activeStories[_currentIndex];
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > 0)
              _previousStory();
            else if (details.primaryVelocity! < 0) _nextStory();
          }
        },
        onTapUp: (details) {
          final double screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            _previousStory();
          } else if (details.globalPosition.dx > 2 * screenWidth / 3) {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _activeStories.length,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _loadStory(index);
              },
              itemBuilder: (context, index) {
                final story = _activeStories[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: story['type'] == 'video' &&
                              _videoController != null &&
                              _videoController!.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            )
                          : CachedNetworkImage(
                              imageUrl: story['media'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) =>
                                  const Center(
                                child: Icon(Icons.broken_image,
                                    size: 40, color: Colors.white),
                              ),
                            ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              top: 48,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: NetworkImage(
                                  story['userAvatar'] ??
                                      'https://via.placeholder.com/150'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                story['user'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black45,
                                        offset: Offset(1, 1),
                                        blurRadius: 2),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _animationController.value,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
            if (story['userId'] == widget.currentUserId)
              Positioned(
                top: 48,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.delete,
                      color: Colors.redAccent, size: 22),
                  onPressed: () => _deleteStory(_currentIndex),
                ),
              ),
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (story['userId'] != widget.currentUserId) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.favorite_border,
                                color: Colors.white, size: 22),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        "Liked story by ${story['user']}")),
                              );
                              _updateChatWithInteraction("like", "");
                            },
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.comment,
                                color: Colors.white, size: 22),
                            onPressed: () => FocusScope.of(context)
                                .requestFocus(_replyFocusNode),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.share,
                                color: Colors.white, size: 22),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Shared story")),
                              );
                              _updateChatWithInteraction("share", "");
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _replyController,
                        focusNode: _replyFocusNode,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Reply to ${story['user']}...",
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.black54,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send,
                                color: Colors.white70, size: 20),
                            onPressed: () {
                              if (_replyController.text.trim().isEmpty) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        "Replied: ${_replyController.text}")),
                              );
                              _updateChatWithInteraction(
                                  "reply", _replyController.text);
                              _replyController.clear();
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) {
                          if (value.trim().isEmpty) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Replied: $value")),
                          );
                          _updateChatWithInteraction("reply", value);
                          _replyController.clear();
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ],
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
