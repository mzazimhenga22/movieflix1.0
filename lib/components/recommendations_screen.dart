import 'package:flutter/material.dart';
import 'package:movie_app/tmdb_api.dart'
    as tmdb; // Ensure this provides fetchRecommendations()

/// A stateful widget that fetches movie recommendations from TMDB and displays them.
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({Key? key}) : super(key: key);

  @override
  _RecommendationsScreenState createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  bool _isLoading = true;
  List<dynamic> _movies = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    try {
      // Pull movie recommendations from TMDB.
      final movies = await tmdb.TMDBApi.fetchRecommendations();
      setState(() {
        _movies = movies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load recommendations: $e";
        _isLoading = false;
      });
    }
  }

  void _openMovieDetail(Map<String, dynamic> movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailScreen(movie: movie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Personalized Watchlists & AI Recommendations"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _movies.length,
                  itemBuilder: (context, index) {
                    var movie = _movies[index];
                    // Build the poster URL.
                    final posterUrl = movie['poster_path'] != null
                        ? 'https://image.tmdb.org/t/p/w500${movie['poster_path']}'
                        : 'https://via.placeholder.com/500x750?text=No+Image';
                    return GestureDetector(
                      onTap: () => _openMovieDetail(movie),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // Poster image fills the card.
                            Positioned.fill(
                              child: Image.network(
                                posterUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Gradient overlay for readability.
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 80,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black54
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            // Movie title and rating.
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie['title'] ?? movie['name'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star,
                                          color: Colors.yellow, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        (movie['vote_average'] != null)
                                            ? movie['vote_average'].toString()
                                            : 'N/A',
                                        style: const TextStyle(
                                            color: Colors.white),
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
                  },
                ),
    );
  }
}

/// The movie detail screen shows movie details along with 5 interactive features.
class MovieDetailScreen extends StatelessWidget {
  final Map<String, dynamic> movie;
  const MovieDetailScreen({Key? key, required this.movie}) : super(key: key);

  void _showFeatureSnackBar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$feature feature activated")),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build the poster URL.
    final posterUrl = movie['poster_path'] != null
        ? 'https://image.tmdb.org/t/p/w500${movie['poster_path']}'
        : 'https://via.placeholder.com/500x750?text=No+Image';
    return Scaffold(
      appBar: AppBar(
        title: Text(movie['title'] ?? movie['name'] ?? 'Movie Detail'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display the poster image.
            Image.network(
              posterUrl,
              width: double.infinity,
              height: 400,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                movie['title'] ?? movie['name'] ?? '',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text(movie['release_date'] ?? 'Unknown'),
                  const SizedBox(width: 16),
                  const Icon(Icons.star, color: Colors.yellow, size: 16),
                  const SizedBox(width: 4),
                  Text(movie['vote_average'] != null
                      ? movie['vote_average'].toString()
                      : 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                movie['overview'] ?? 'No description available.',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            // 5 Interactive Feature Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showFeatureSnackBar(context, "View Trailer"),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("View Trailer"),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showFeatureSnackBar(context, "Add to Watchlist"),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text("Add to Watchlist"),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showFeatureSnackBar(context, "Rate"),
                    icon: const Icon(Icons.star),
                    label: const Text("Rate"),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showFeatureSnackBar(context, "Share"),
                    icon: const Icon(Icons.share),
                    label: const Text("Share"),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showFeatureSnackBar(context, "Read Reviews"),
                    icon: const Icon(Icons.rate_review),
                    label: const Text("Read Reviews"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
