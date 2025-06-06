import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'package:movie_app/tmdb_api.dart' as tmdb;
import 'package:movie_app/movie_detail_screen.dart';
import 'package:movie_app/components/movie_card.dart';
import 'package:shimmer/shimmer.dart';

/// RecommendedMoviesScreen widget: Displays all recommended movies with pagination
class RecommendedMoviesScreen extends StatefulWidget {
  const RecommendedMoviesScreen({super.key});

  @override
  RecommendedMoviesScreenState createState() => RecommendedMoviesScreenState();
}

class RecommendedMoviesScreenState extends State<RecommendedMoviesScreen> {
  final ScrollController _controller = ScrollController();
  List<dynamic> recommendedMovies = [];
  bool isLoading = false;
  int currentPage = 1;
  int? totalPages;

  @override
  void initState() {
    super.initState();
    fetchMovies(currentPage);
    _controller.addListener(_onScroll);
  }

  Future<void> fetchMovies(int page) async {
    if (isLoading || (totalPages != null && currentPage > totalPages!)) return;
    setState(() => isLoading = true);
    final response = await tmdb.TMDBApi.fetchRecommendedMovies(page: page);
    setState(() {
      recommendedMovies.addAll(response['movies']);
      totalPages = response['total_pages'];
      isLoading = false;
      currentPage++;
    });
  }

  void _onScroll() {
    if (_controller.position.extentAfter < 200 && !isLoading) {
      fetchMovies(currentPage);
    }
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

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Recommended Movies',
              style: TextStyle(
                color: settings.accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: recommendedMovies.isEmpty && isLoading
              ? GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.67,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) => buildMovieCardPlaceholder(),
                )
              : GridView.builder(
                  controller: _controller,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.67,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: recommendedMovies.length + (isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == recommendedMovies.length && isLoading) {
                      return buildMovieCardPlaceholder();
                    }
                    final movie = recommendedMovies[index];
                    if (movie == null) return const SizedBox();
                    final posterPath = movie['poster_path'];
                    final posterUrl = posterPath != null
                        ? 'https://image.tmdb.org/t/p/w342$posterPath'
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
                            builder: (context) =>
                                MovieDetailScreen(movie: movie),
                          ),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
