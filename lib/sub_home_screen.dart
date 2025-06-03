import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'package:movie_app/tmdb_api.dart' as tmdb;
import 'package:movie_app/movie_detail_screen.dart';
import 'package:movie_app/components/movie_card.dart';
import 'package:shimmer/shimmer.dart';

/// SubHomeScreen widget: Handles trending and recommended movies sections
class SubHomeScreen extends StatefulWidget {
  const SubHomeScreen({Key? key}) : super(key: key);

  @override
  SubHomeScreenState createState() => SubHomeScreenState();
}

class SubHomeScreenState extends State<SubHomeScreen> {
  final trendingController = ScrollController();
  final recommendedController = ScrollController();
  List<dynamic> trendingMovies = [];
  List<dynamic> recommendedMovies = [];
  bool isLoadingTrending = false;
  bool isLoadingRecommended = false;

  @override
  void initState() {
    super.initState();
    fetchInitialData();
    trendingController.addListener(onScrollTrending);
    recommendedController.addListener(onScrollRecommended);
  }

  Future<void> fetchInitialData() async {
    await fetchTrendingMovies();
    await fetchRecommendedMovies();
  }

  Future<void> fetchTrendingMovies() async {
    if (isLoadingTrending) return;
    setState(() => isLoadingTrending = true);
    final movies = await tmdb.TMDBApi.fetchTrendingMovies();
    setState(() {
      trendingMovies.addAll(movies);
      isLoadingTrending = false;
    });
  }

  Future<void> fetchRecommendedMovies() async {
    if (isLoadingRecommended) return;
    setState(() => isLoadingRecommended = true);
    final movies = await tmdb.TMDBApi.fetchRecommendedMovies();
    setState(() {
      recommendedMovies.addAll(movies);
      isLoadingRecommended = false;
    });
  }

  void onScrollTrending() {
    if (trendingController.position.extentAfter < 200 && !isLoadingTrending) {
      fetchTrendingMovies();
    }
  }

  void onScrollRecommended() {
    if (recommendedController.position.extentAfter < 200 &&
        !isLoadingRecommended) {
      fetchRecommendedMovies();
    }
  }

  Future<void> refreshData() async {
    setState(() {
      trendingMovies.clear();
      recommendedMovies.clear();
    });
    await fetchInitialData();
  }

  Widget buildMovieCardPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Container(
        width: 120,
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 10,
                    color: Colors.grey[900],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 40,
                    height: 10,
                    color: Colors.grey[900],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTrendingMovies() {
    if (trendingMovies.isEmpty && isLoadingTrending) {
      return SizedBox(
        height: 240,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 5, // Show 5 placeholders
          itemBuilder: (context, index) => buildMovieCardPlaceholder(),
        ),
      );
    }
    return SizedBox(
      height: 240,
      child: ListView.builder(
        controller: trendingController,
        scrollDirection: Axis.horizontal,
        itemCount: trendingMovies.length + (isLoadingTrending ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == trendingMovies.length) {
            return buildMovieCardPlaceholder(); // Replaced CircularProgressIndicator
          }
          final movie = trendingMovies[index];
          if (movie == null) return const SizedBox();
          final posterPath = movie['poster_path'];
          final posterUrl = posterPath != null
              ? 'https://image.tmdb.org/t/p/w500$posterPath'
              : '';
          return MovieCard(
            imageUrl: posterUrl,
            title: movie['title'] ?? movie['name'] ?? 'No Title',
            rating: movie['vote_average'] != null
                ? double.tryParse(movie['vote_average'].toString())
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailScreen(movie: movie),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget buildRecommendedMovies() {
    if (recommendedMovies.isEmpty && isLoadingRecommended) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.67,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: 6, // Show 6 placeholders
        itemBuilder: (context, index) => buildMovieCardPlaceholder(),
      );
    }
    return GridView.builder(
      controller: recommendedController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.67,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: recommendedMovies.length + (isLoadingRecommended ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == recommendedMovies.length) {
          return buildMovieCardPlaceholder(); // Replaced CircularProgressIndicator
        }
        final movie = recommendedMovies[index];
        if (movie == null) return const SizedBox();
        final posterPath = movie['poster_path'];
        final posterUrl = posterPath != null
            ? 'https://image.tmdb.org/t/p/w500$posterPath'
            : '';
        return MovieCard(
          imageUrl: posterUrl,
          title: movie['title'] ?? movie['name'] ?? 'No Title',
          rating: movie['vote_average'] != null
              ? double.tryParse(movie['vote_average'].toString())
              : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailScreen(movie: movie),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Trending',
                style: TextStyle(
                  color: settings.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(height: 10),
            buildTrendingMovies(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Recommended',
                style: TextStyle(
                  color: settings.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(height: 10),
            buildRecommendedMovies(),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    trendingController.dispose();
    recommendedController.dispose();
    super.dispose();
  }
}
