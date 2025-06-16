import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:movie_app/tmdb_api.dart';
import 'package:shimmer/shimmer.dart';
import '../reel_player_screen.dart';
import '../models/reel.dart';

class ReelsSection extends StatefulWidget {
  const ReelsSection({super.key});

  @override
  State<ReelsSection> createState() => _ReelsSectionState();
}

class _ReelsSectionState extends State<ReelsSection>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static List<dynamic> _cachedReels = [];
  List<dynamic> reelsData = [];
  late AnimationController _controller;
  late Animation<double> _shineAnimation;
  bool _isInitialized = false;

  static final _loadingWidget = Shimmer.fromColors(
    baseColor: Colors.grey[800]!,
    highlightColor: Colors.grey[600]!,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
          child: Container(
            width: 160,
            height: 320,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
    ),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
    _shineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _isInitialized = true;
    if (_cachedReels.isNotEmpty) {
      reelsData = _cachedReels;
      setState(() {});
    } else {
      fetchReels();
    }
  }

  Future<void> fetchReels({bool forceRefresh = false}) async {
    if (_cachedReels.isNotEmpty && !forceRefresh) {
      if (reelsData != _cachedReels) {
        setState(() {
          reelsData = _cachedReels;
        });
      }
      return;
    }

    try {
      final fetchedReels = await TMDBApi.fetchReels();
      if (mounted) {
        setState(() {
          reelsData = fetchedReels;
          _cachedReels = fetchedReels;
          for (var r in reelsData) {
            precacheImage(NetworkImage(r['thumbnail_url']), context);
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching reels: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 10.0),
          child: _isInitialized
              ? AnimatedBuilder(
                  animation: _shineAnimation,
                  builder: (context, child) {
                    return ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.red
                                .withOpacity(0.8 - _shineAnimation.value * 0.4),
                            Colors.redAccent
                                .withOpacity(0.8 + _shineAnimation.value * 0.4),
                            Colors.red
                                .withOpacity(0.8 - _shineAnimation.value * 0.4),
                          ],
                          stops: [
                            0.0,
                            0.5 + _shineAnimation.value * 0.5,
                            1.0,
                          ],
                        ).createShader(rect);
                      },
                      child: const Text(
                        "Movie Reels",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          shadows: [
                            Shadow(
                              color: Colors.red,
                              blurRadius: 10,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : const Text(
                  "Movie Reels",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
        ),
        SizedBox(
          height: 360,
          child: reelsData.isEmpty
              ? _loadingWidget
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: reelsData.length,
                  cacheExtent: 1000,
                  itemBuilder: (context, index) {
                    final reel = reelsData[index];
                    final title = reel['title'] as String? ?? "Reel";
                    final thumbnailUrl = reel['thumbnail_url'] as String? ?? "";
                    final List<Reel> reels = reelsData.map<Reel>((r) {
                      return Reel(
                        videoUrl: r['videoUrl'] as String? ?? "",
                        movieTitle: r['title'] as String? ?? "Reel",
                        movieDescription: "Watch the trailer",
                      );
                    }).toList();

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 20.0),
                      child: GestureDetector(
                        key: ValueKey(thumbnailUrl),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReelPlayerScreen(
                                reels: reels,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 160,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(103, 58, 183, 0.6),
                                blurRadius: 15,
                                spreadRadius: 1,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: CachedNetworkImage(
                                    imageUrl: thumbnailUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        const ColoredBox(
                                      color: Color.fromRGBO(33, 33, 33, 1),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const ColoredBox(
                                      color: Color.fromRGBO(33, 33, 33, 1),
                                      child: Icon(Icons.error,
                                          color: Colors.red, size: 40),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color.fromRGBO(0, 0, 0, 0.7),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                left: 10,
                                right: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 4,
                                            offset: Offset(1, 1),
                                          ),
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.all(6.0),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.deepPurpleAccent,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color.fromRGBO(
                                                  103, 58, 183, 0.5),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 20,
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
                    );
                  },
                ),
        ),
      ],
    );
  }
}


