import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'package:movie_app/tmdb_api.dart' as tmdb;
import 'package:movie_app/search_screen.dart';
import 'package:movie_app/profile_screen.dart';
import 'package:movie_app/categories_screen.dart';
import 'package:movie_app/downloads_screen.dart';
import 'package:movie_app/movie_detail_screen.dart';
import 'package:movie_app/mylist_screen.dart';
import 'package:movie_app/components/stories_section.dart';
import 'package:movie_app/components/reels_section.dart';
import 'package:movie_app/interactive_features_screen.dart';
import 'package:movie_app/components/song_of_movies_screen.dart';
import 'package:movie_app/sub_home_screen.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

/// AnimatedBackground widget: Static gradient background for reduced GPU usage
class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.redAccent, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

/// RandomMovieScreen widget: Displays a random movie or TV show
class RandomMovieScreen extends StatefulWidget {
  const RandomMovieScreen({super.key});

  @override
  RandomMovieScreenState createState() => RandomMovieScreenState();
}

class RandomMovieScreenState extends State<RandomMovieScreen> {
  Map<String, dynamic>? randomMovie;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRandomMovie();
  }

  Future<void> fetchRandomMovie() async {
    setState(() => isLoading = true);
    try {
      final movies = await tmdb.TMDBApi.fetchTrendingMovies();
      final tvShows = await tmdb.TMDBApi.fetchTrendingTVShows();
      List<Map<String, dynamic>> allContent = [];
      allContent.addAll(movies.cast<Map<String, dynamic>>());
      allContent.addAll(tvShows.cast<Map<String, dynamic>>());
      if (allContent.isNotEmpty) {
        allContent.shuffle();
        setState(() {
          randomMovie = allContent.first;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching random content: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? Shimmer.fromColors(
              baseColor: Colors.grey[800]!,
              highlightColor: Colors.grey[600]!,
              child: Container(
                color: Colors.grey[800],
                child: const Center(
                  child: Text(
                    'Loading Random Movie...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            )
          : randomMovie == null
              ? const Center(child: Text('No content found'))
              : MovieDetailScreen(movie: randomMovie!),
    );
  }
}

/// FeaturedMovieCard widget: Optimized with user-initiated video playback and image caching
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
  FeaturedMovieCardState createState() => FeaturedMovieCardState();
}

class FeaturedMovieCardState extends State<FeaturedMovieCard> {
  bool isFavorite = false;
  bool showVideo = false;
  YoutubePlayerController? videoController;
  double _buttonScale = 1.0;

  final Map<int, String> genreMap = {
    28: "Action",
    12: "Adventure",
    16: "Animation",
    35: "Comedy",
    80: "Crime",
    18: "Drama",
    10749: "Romance",
    878: "Sci-Fi",
  };

  String getGenresText() {
    return widget.genres.map((id) => genreMap[id] ?? "Unknown").join(', ');
  }

  @override
  void dispose() {
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: showVideo && videoController != null
                    ? YoutubePlayer(
                        key: const ValueKey('video'),
                        controller: videoController!,
                        aspectRatio: 16 / 9,
                      )
                    : Hero(
                        tag: widget.imageUrl,
                        child: CachedNetworkImage(
                          key: const ValueKey('image'),
                          imageUrl: widget.imageUrl,
                          height: 320,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[800]!,
                            highlightColor: Colors.grey[600]!,
                            child: Container(
                              height: 320,
                              color: Colors.grey[800],
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 320,
                            color: Colors.grey,
                            child: const Center(
                              child: Icon(Icons.error, size: 50),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
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
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.yellow,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Genres: ${getGenresText()}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTapDown: (_) => setState(() => _buttonScale = 0.95),
                        onTapUp: (_) => setState(() => _buttonScale = 1.0),
                        onTapCancel: () => setState(() => _buttonScale = 1.0),
                        child: AnimatedScale(
                          scale: _buttonScale,
                          duration: const Duration(milliseconds: 100),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (videoController == null &&
                                  widget.trailerUrl.isNotEmpty) {
                                final videoId = YoutubePlayer.convertUrlToId(
                                    widget.trailerUrl);
                                if (videoId != null) {
                                  videoController = YoutubePlayerController(
                                    initialVideoId: videoId,
                                    flags: const YoutubePlayerFlags(
                                      autoPlay: true,
                                      mute: false,
                                      hideControls: true,
                                    ),
                                  );
                                }
                              }
                              setState(() => showVideo = true);
                            },
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.black,
                            ),
                            label: const Text(
                              'Watch Trailer',
                              style: TextStyle(color: Colors.black),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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
                                ? settings.accentColor
                                : Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite
                                ? Colors.white
                                : settings.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showVideo)
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      showVideo = false;
                      videoController?.pause();
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// FeaturedSlider widget: Manages a vertical carousel of featured content
class FeaturedSlider extends StatefulWidget {
  const FeaturedSlider({super.key});

  @override
  FeaturedSliderState createState() => FeaturedSliderState();
}

class FeaturedSliderState extends State<FeaturedSlider> {
  late PageController pageController;
  List<Map<String, dynamic>> featuredContent = [];
  int currentPage = 0;
  int pageCount = 0;
  bool isLoading = false;
  Timer? timer;
  static List<Map<String, dynamic>> _cachedContent = [];

  @override
  void initState() {
    super.initState();
    pageController = PageController();
    if (_cachedContent.isNotEmpty) {
      featuredContent = _cachedContent;
      pageCount = featuredContent.length;
      startTimer();
    } else {
      loadInitialContent();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageController.hasClients) {
        pageController.position.isScrollingNotifier.addListener(onScroll);
      }
    });
  }

  Future<void> loadInitialContent() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    final content = await fetchFeaturedContent(limit: 5);
    setState(() {
      featuredContent = content;
      _cachedContent = content;
      pageCount = content.length;
      isLoading = false;
    });
    startTimer();
  }

  Future<List<Map<String, dynamic>>> fetchFeaturedContent(
      {int limit = 5}) async {
    try {
      final List<dynamic> movies = await tmdb.TMDBApi.fetchFeaturedMovies();
      final List<dynamic> tvShows = await tmdb.TMDBApi.fetchFeaturedTVShows();
      List<Map<String, dynamic>> content = [];
      content.addAll(movies.cast<Map<String, dynamic>>());
      content.addAll(tvShows.cast<Map<String, dynamic>>());
      content.sort(
          (a, b) => (b['popularity'] as num).compareTo(a['popularity'] as num));
      return content.take(limit).toList();
    } catch (e) {
      debugPrint("Error fetching featured content: $e");
      return [];
    }
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (pageController.hasClients && pageCount > 0) {
        currentPage++;
        if (currentPage >= pageCount) {
          currentPage = 0;
          pageController.jumpToPage(0);
        } else {
          pageController.animateToPage(
            currentPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void onScroll() {
    if (pageController.position.isScrollingNotifier.value) {
      timer?.cancel();
    } else {
      startTimer();
    }
  }

  Future<void> loadMoreContent() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    final newContent = await fetchFeaturedContent(limit: 5);
    setState(() {
      featuredContent.addAll(newContent);
      _cachedContent = featuredContent;
      pageCount = featuredContent.length;
      isLoading = false;
    });
  }

  Widget buildFeaturedPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 320,
                width: double.infinity,
                color: Colors.grey[800],
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
                  Container(
                    width: 200,
                    height: 24,
                    color: Colors.grey[800],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 150,
                        height: 16,
                        color: Colors.grey[800],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            color: Colors.grey[800],
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 30,
                            height: 16,
                            color: Colors.grey[800],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 100,
                    height: 14,
                    color: Colors.grey[800],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 120,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
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

  @override
  void dispose() {
    if (pageController.hasClients) {
      pageController.position.isScrollingNotifier.removeListener(onScroll);
    }
    timer?.cancel();
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: featuredContent.isEmpty
          ? buildFeaturedPlaceholder()
          : PageView.builder(
              controller: pageController,
              scrollDirection: Axis.vertical,
              itemCount: featuredContent.length,
              onPageChanged: (index) {
                setState(() => currentPage = index);
                if (index >= featuredContent.length - 2 && !isLoading) {
                  loadMoreContent();
                }
              },
              itemBuilder: (context, index) {
                final item = featuredContent[index];
                final imageUrl =
                    'https://image.tmdb.org/t/p/w500${item['backdrop_path'] ?? item['poster_path'] ?? ''}';
                final title = item['title'] ?? item['name'] ?? 'Featured';
                final releaseDate =
                    item['release_date'] ?? item['first_air_date'] ?? 'Unknown';
                final genres = item['genre_ids'] != null
                    ? List<int>.from(item['genre_ids'])
                    : <int>[];
                final rating = item['vote_average'] != null
                    ? double.tryParse(item['vote_average'].toString()) ?? 0.0
                    : 0.0;
                final trailerUrl = item['trailer_url'] ??
                    'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
                return FeaturedMovieCard(
                  key: ValueKey(imageUrl), // Ensure widget reuse
                  imageUrl: imageUrl,
                  title: title,
                  releaseDate: releaseDate,
                  genres: genres,
                  rating: rating,
                  trailerUrl: trailerUrl,
                  isCurrentPage: index == currentPage,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailScreen(movie: item),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// HomeScreenMain widget: Main screen with optimized structure
class HomeScreenMain extends StatefulWidget {
  final String? profileName;
  const HomeScreenMain({super.key, this.profileName});

  @override
  HomeScreenMainState createState() => HomeScreenMainState();
}

class HomeScreenMainState extends State<HomeScreenMain>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  int selectedIndex = 0;
  late AnimationController _textAnimationController;
  late Animation<double> _textFadeAnimation;
  final _subHomeScreenKey = GlobalKey<SubHomeScreenState>();

  // Static cache for navigation items
  static const _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categories'),
    BottomNavigationBarItem(icon: Icon(Icons.download), label: 'Downloads'),
    BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Interactive'),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _textFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textAnimationController, curve: Curves.easeIn),
    );
    _textAnimationController.forward();
  }

  Future<void> refreshData() async {
    await _subHomeScreenKey.currentState?.refreshData();
  }

  void onItemTapped(int index) {
    setState(() => selectedIndex = index);
    if (index == 1) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const CategoriesScreen()));
    } else if (index == 2) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const DownloadsScreen()));
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InteractiveFeaturesScreen(
            isDarkMode: false,
            onThemeChanged: (bool newValue) {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final screenHeight = MediaQuery.of(context).size.height;
    return Selector<SettingsProvider, Color>(
      selector: (_, settings) => settings.accentColor,
      builder: (context, accentColor, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: accentColor.withOpacity(0.1),
            elevation: 0,
            title: FadeTransition(
              opacity: _textFadeAnimation,
              child: Text(
                widget.profileName != null
                    ? "Welcome, ${widget.profileName}"
                    : "Movie App",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.search, color: accentColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SearchScreen()),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.list, color: accentColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MyListScreen()),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.person, color: accentColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfileScreen()),
                  );
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              const AnimatedBackground(),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.06, -0.34),
                      radius: 1.0,
                      colors: [
                        accentColor.withOpacity(0.5),
                        const Color.fromARGB(255, 0, 0, 0),
                      ],
                      stops: const [0.0, 0.59],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.64, 0.3),
                      radius: 1.0,
                      colors: [
                        accentColor.withOpacity(0.3),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5,
                        colors: [
                          accentColor.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(160, 17, 19, 40),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            border: Border(
                              top: BorderSide(
                                  color: Color.fromRGBO(255, 255, 255, 0.125)),
                              bottom: BorderSide(
                                  color: Color.fromRGBO(255, 255, 255, 0.125)),
                              left: BorderSide(
                                  color: Color.fromRGBO(255, 255, 255, 0.125)),
                              right: BorderSide(
                                  color: Color.fromRGBO(255, 255, 255, 0.125)),
                            ),
                          ),
                          child: RefreshIndicator(
                            onRefresh: refreshData,
                            child: ConstrainedBox(
                              constraints:
                                  BoxConstraints(minHeight: screenHeight),
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const StoriesSection(),
                                        const SizedBox(height: 10),
                                        const FeaturedSlider(),
                                        const SizedBox(height: 20),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16.0),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          const SongOfMoviesScreen()),
                                                );
                                              },
                                              child: Container(
                                                height: 180,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      accentColor
                                                          .withOpacity(0.2),
                                                      accentColor
                                                          .withOpacity(0.2),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: accentColor
                                                          .withOpacity(0.6),
                                                      blurRadius: 12,
                                                      offset:
                                                          const Offset(0, 6),
                                                    ),
                                                  ],
                                                ),
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.music_note,
                                                      color: Colors.white
                                                          .withOpacity(0.3),
                                                      size: 120,
                                                    ),
                                                    Container(
                                                      decoration:
                                                          const BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.all(
                                                                Radius.circular(
                                                                    24)),
                                                        gradient:
                                                            LinearGradient(
                                                          colors: [
                                                            Color.fromRGBO(
                                                                0, 0, 0, 0.2),
                                                            Colors.transparent,
                                                          ],
                                                          begin: Alignment
                                                              .bottomCenter,
                                                          end: Alignment
                                                              .topCenter,
                                                        ),
                                                      ),
                                                    ),
                                                    const Positioned(
                                                      bottom: 20,
                                                      child: Text(
                                                        'Song of Movies',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 32,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          shadows: [
                                                            Shadow(
                                                              blurRadius: 4,
                                                              color: Colors
                                                                  .black54,
                                                              offset:
                                                                  Offset(2, 2),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const SizedBox(
                                          height: 400,
                                          child: Opacity(
                                            opacity: 0.7,
                                            child: ReelsSection(),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        SubHomeScreen(key: _subHomeScreenKey),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: accentColor,
            child: const Icon(Icons.shuffle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RandomMovieScreen()),
              );
            },
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(160, 17, 19, 40),
              border: Border(
                top: BorderSide(
                    color: Colors.white.withOpacity(0.125), width: 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: BottomNavigationBar(
                  backgroundColor: Colors.transparent,
                  selectedItemColor: Colors.white,
                  unselectedItemColor: accentColor.withOpacity(0.6),
                  currentIndex: selectedIndex,
                  items: _navItems,
                  onTap: onItemTapped,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _textAnimationController.dispose();
    super.dispose();
  }
}
