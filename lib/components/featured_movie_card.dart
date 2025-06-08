import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class FeaturedMovieCard extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String releaseDate;
  final List<int> genres;
  final double rating;
  final String trailerUrl;
  final bool isCurrentPage;
  final VoidCallback? onTap;

  const FeaturedMovieCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.releaseDate,
    required this.genres,
    required this.rating,
    required this.trailerUrl,
    required this.isCurrentPage,
    this.onTap,
  });

  @override
  State<FeaturedMovieCard> createState() => _FeaturedMovieCardState();
}

class _FeaturedMovieCardState extends State<FeaturedMovieCard>
    with AutomaticKeepAliveClientMixin {
  bool isFavorite = false;
  bool _showVideo = false;
  Timer? _videoTimer;
  YoutubePlayerController? _videoController;
  String? _genresText;

  static const Map<int, String> _genreMap = {
    28: "Action",
    12: "Adventure",
    16: "Animation",
    35: "Comedy",
    80: "Crime",
    18: "Drama",
    10749: "Romance",
    878: "Sci-Fi",
  };

  static const _loadingWidget = SizedBox(
    height: 320,
    child: Center(child: CircularProgressIndicator()),
  );

  static const _errorWidget = SizedBox(
    height: 320,
    child: Center(child: Icon(Icons.error, color: Colors.red, size: 50)),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _genresText =
        widget.genres.map((id) => _genreMap[id] ?? "Unknown").join(', ');
  }

  @override
  void didUpdateWidget(FeaturedMovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.genres != oldWidget.genres) {
      _genresText =
          widget.genres.map((id) => _genreMap[id] ?? "Unknown").join(', ');
    }
    if (widget.isCurrentPage != oldWidget.isCurrentPage) {
      if (widget.isCurrentPage) {
        _videoTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && widget.isCurrentPage && widget.trailerUrl.isNotEmpty) {
            final videoId = YoutubePlayer.convertUrlToId(widget.trailerUrl);
            if (videoId != null) {
              _videoController = YoutubePlayerController(
                initialVideoId: videoId,
                flags: const YoutubePlayerFlags(
                  autoPlay: true,
                  mute: false,
                  hideControls: true,
                  controlsVisibleAtStart: false,
                ),
              );
              setState(() {
                _showVideo = true;
              });
            }
          }
        });
      } else {
        _videoTimer?.cancel();
        if (_videoController != null) {
          _videoController!.pause();
          _videoController!.dispose();
          _videoController = null;
        }
        setState(() {
          _showVideo = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _showVideo && _videoController != null
                    ? YoutubePlayer(
                        key: ValueKey(widget.trailerUrl),
                        controller: _videoController!,
                        showVideoProgressIndicator: false,
                        aspectRatio: 16 / 9,
                      )
                    : Hero(
                        key: ValueKey(widget.imageUrl),
                        tag: widget.imageUrl,
                        child: Image.network(
                          widget.imageUrl,
                          height: 320,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return _loadingWidget;
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              _errorWidget,
                        ),
                      ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color.fromRGBO(0, 0, 0, 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Release Date: ${widget.releaseDate}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.yellow, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            widget.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Genres: $_genresText',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.play_arrow, color: Colors.black),
                        label: const Text('Watch Trailer',
                            style: TextStyle(color: Colors.black)),
                        style: const ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(Colors.white),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isFavorite = !isFavorite;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isFavorite
                                ? Colors.redAccent
                                : Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.white : Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
