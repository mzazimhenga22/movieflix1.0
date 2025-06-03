import 'package:flutter/material.dart';
import 'package:movie_app/tmdb_api.dart' as tmdb;
import 'package:movie_app/components/movie_card.dart';
import 'package:movie_app/movie_detail_screen.dart';

class TrendingMoviesWidget extends StatefulWidget {
  const TrendingMoviesWidget({Key? key}) : super(key: key);

  @override
  _TrendingMoviesWidgetState createState() => _TrendingMoviesWidgetState();
}

class _TrendingMoviesWidgetState extends State<TrendingMoviesWidget> {
  late Future<List<dynamic>> _trendingMoviesFuture;

  @override
  void initState() {
    super.initState();
    _trendingMoviesFuture = tmdb.TMDBApi.fetchTrendingMovies();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _trendingMoviesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox();
        }
        final trendingMovies = snapshot.data!;
        return SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: trendingMovies.length,
            itemBuilder: (context, index) {
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
      },
    );
  }
}
