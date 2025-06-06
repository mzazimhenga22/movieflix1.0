import 'dart:convert';
import 'package:http/http.dart' as http;

class TMDBApi {
  static const String apiKey = '1ba41bda48d0f1c90954f4811637b6d6';
  static const String baseUrl = 'https://api.themoviedb.org/3';

  /// (Legacy) Fetches one featured movie (the first popular movie).
  static Future<Map<String, dynamic>> fetchFeaturedMovie() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/movie/popular?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List results = data['results'];
        if (results.isNotEmpty) {
          return results[0]; // Return the first movie as featured.
        } else {
          throw Exception("No movies found");
        }
      } else {
        throw Exception(
            'Failed to load featured movie: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching featured movie: $e');
    }
  }

  /// Fetches upcoming movies.
  static Future<List<dynamic>> fetchUpcomingMovies() async {
    final uri = Uri.parse('$baseUrl/movie/upcoming?api_key=$apiKey');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['results'];
    } else {
      throw Exception(
          'Failed to load upcoming: ${response.statusCode} ${response.reasonPhrase}');
    }
  }

  /// Fetches trending movies or TV shows.
  static Future<List<dynamic>> fetchTrendingMovies() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trending/all/day?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to load trending movies: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching trending movies: $e');
    }
  }

  /// Fetches trending TV shows.
  static Future<List<dynamic>> fetchTrendingTVShows() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trending/tv/day?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to load trending TV shows: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching trending TV shows: $e');
    }
  }

  /// Fetches recommendations.
  static Future<List<dynamic>> fetchRecommendations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/movie/popular?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to load recommendations: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching recommendations: $e');
    }
  }

  /// Fetches recommended movies with pagination, returning movies and total pages.
  static Future<Map<String, dynamic>> fetchRecommendedMovies(
      {int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/movie/popular?api_key=$apiKey&page=$page'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'movies': data['results'],
          'total_pages': data['total_pages'],
        };
      } else {
        throw Exception(
            'Failed to load recommended movies: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching recommended movies: $e');
    }
  }

  /// Fetches recommended movies as a list (legacy support for non-paginated use cases).
  static Future<List<dynamic>> fetchRecommendedMoviesList() async {
    final result = await fetchRecommendedMovies(page: 1);
    return result['movies'];
  }

  /// Fetches the list of movie genres.
  static Future<List<dynamic>> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/genre/movie/list?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['genres'];
      } else {
        throw Exception(
            'Failed to load categories: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching categories: $e');
    }
  }

  /// A map for converting category names to TMDB genre IDs.
  static Map<String, int> genreMap = {
    'Action': 28,
    'Comedy': 35,
    'Drama': 18,
    'Horror': 27,
    'Sci-Fi': 878,
    'Romance': 10749,
    'Animation': 16,
    'Thriller': 53,
    'Documentary': 99,
  };

  /// Fetches movies for the given [categoryName] using the Discover endpoint.
  static Future<List<dynamic>> fetchCategoryMovies(String categoryName) async {
    final genreId = genreMap[categoryName];
    if (genreId == null) {
      throw Exception("Genre not found for $categoryName");
    }
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=$genreId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to load category movies: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching category movies: $e');
    }
  }

  /// Fetches TV shows for the given [categoryName] using the Discover endpoint.
  static Future<List<dynamic>> fetchCategoryTVShows(String categoryName) async {
    final genreId = genreMap[categoryName];
    if (genreId == null) {
      throw Exception("Genre not found for $categoryName");
    }
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/discover/tv?api_key=$apiKey&with_genres=$genreId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to load category TV shows: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching category TV shows: $e');
    }
  }

  /// Fetches similar movies for a given movie ID.
  static Future<List<dynamic>> fetchSimilarMovies(int movieId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/movie/$movieId/similar?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to load similar movies: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching similar movies: $e');
    }
  }

  /// Fetches similar TV shows for a given TV show ID.
  static Future<List<dynamic>> fetchSimilarTVShows(int tvId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tv/$tvId/similar?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to load similar TV shows: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching similar TV shows: $e');
    }
  }

  /// Fetches trailers (videos) for a given movie or TV show ID.
  static Future<List<dynamic>> fetchTrailers(int id,
      {bool isTVShow = false}) async {
    final String endpoint = isTVShow ? 'tv/$id' : 'movie/$id';
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint/videos?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to load trailers: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching trailers: $e');
    }
  }

  /// Fetches detailed TV show information, including seasons.
  static Future<Map<String, dynamic>> fetchTVShowDetails(int tvId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tv/$tvId?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to load TV show details: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching TV show details: $e');
    }
  }

  /// Fetches detailed TV season information, including episodes.
  static Future<Map<String, dynamic>> fetchTVSeasonDetails(
      int tvId, int seasonNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tv/$tvId/season/$seasonNumber?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to load TV season details: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching TV season details: $e');
    }
  }

  /// Fetches all episodes for all seasons of a TV show.
  static Future<Map<String, dynamic>> fetchAllEpisodesForTVShow(
      int tvId) async {
    try {
      // Fetch basic TV show details, which includes the list of seasons.
      final tvDetails = await fetchTVShowDetails(tvId);
      final seasons = tvDetails['seasons'] as List<dynamic>;

      // For each season, fetch its episode details.
      for (var season in seasons) {
        final seasonNumber = season['season_number'] as int;
        final seasonDetails = await fetchTVSeasonDetails(tvId, seasonNumber);
        season['episodes'] =
            seasonDetails['episodes']; // Add episodes to the season map.
      }

      return tvDetails; // Return the updated TV show details with episodes.
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception(
          'Unexpected error while fetching all episodes for TV show: $e');
    }
  }

  /// Fetches movies matching the search [query].
  static Future<List<dynamic>> fetchSearchMovies(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search/movie?api_key=$apiKey&query=$query'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to search movies: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while searching movies: $e');
    }
  }

  /// Fetches movies, TV shows, and people matching the search [query].
  static Future<List<dynamic>> fetchSearchMulti(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search/multi?api_key=$apiKey&query=$query'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to search: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while searching multi: $e');
    }
  }

  /// Fetches featured movies (popular movies).
  static Future<List<dynamic>> fetchFeaturedMovies() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/movie/popular?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to load featured movies: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching featured movies: $e');
    }
  }

  /// Fetches featured TV shows (popular TV shows).
  static Future<List<dynamic>> fetchFeaturedTVShows() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tv/popular?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'];
      } else {
        throw Exception(
            'Failed to load featured TV shows: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching featured TV shows: $e');
    }
  }

  /// Fetches featured content by combining featured movies and TV shows.
  /// The results are merged, sorted by popularity, and limited to 20 items.
  static Future<List<dynamic>> fetchFeaturedContent() async {
    try {
      final movies = await fetchFeaturedMovies();
      final tvShows = await fetchFeaturedTVShows();

      // Combine movies and tv shows into one list.
      List<dynamic> combined = [...movies, ...tvShows];

      // Sort the combined list by popularity (descending).
      combined.sort(
          (a, b) => (b['popularity'] as num).compareTo(a['popularity'] as num));

      // Limit to 20 items.
      if (combined.length > 20) {
        combined = combined.sublist(0, 20);
      }
      return combined;
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching featured content: $e');
    }
  }

  /// Fetches dynamic reels.
  static Future<List<dynamic>> fetchReels() async {
    try {
      final trendingResponse = await http.get(
        Uri.parse('$baseUrl/trending/movie/day?api_key=$apiKey'),
      );
      if (trendingResponse.statusCode != 200) {
        throw Exception(
            'Failed to load trending movies for reels: ${trendingResponse.statusCode} - ${trendingResponse.reasonPhrase}');
      }
      final trendingData = jsonDecode(trendingResponse.body);
      List trendingMovies = trendingData['results'];
      List<dynamic> reels = [];
      for (var movie in trendingMovies) {
        final int movieId = movie['id'];
        final trailerResponse = await http.get(
          Uri.parse('$baseUrl/movie/$movieId/videos?api_key=$apiKey'),
        );
        if (trailerResponse.statusCode == 200) {
          final trailerData = jsonDecode(trailerResponse.body);
          List trailers = trailerData['results'];
          if (trailers.isNotEmpty) {
            var trailer = trailers.firstWhere(
              (t) => t['type'] == 'Trailer' || t['type'] == 'Teaser',
              orElse: () => trailers[0],
            );
            reels.add({
              'title': movie['title'] ?? movie['name'] ?? 'Reel',
              'videoUrl': 'https://www.youtube.com/watch?v=${trailer['key']}',
              'thumbnail_url': movie['backdrop_path'] != null
                  ? 'https://image.tmdb.org/t/p/w500${movie['backdrop_path']}'
                  : '',
            });
          }
        } else {
          // Log failure but continue with other movies
          print(
              'Failed to load trailers for movie $movieId: ${trailerResponse.statusCode}');
        }
      }
      return reels;
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching reels: $e');
    }
  }

  /// Fetches dynamic stories.
  static Future<List<dynamic>> fetchStories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trending/tv/day?api_key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List results = data['results'];
        return results.map((tv) {
          return {
            'name': tv['name'] ?? 'Story',
            'imageUrl': tv['poster_path'] != null
                ? 'https://image.tmdb.org/t/p/w200${tv['poster_path']}'
                : 'https://source.unsplash.com/random/100x100/?face',
          };
        }).toList();
      } else {
        throw Exception(
            'Failed to load stories: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Failed to connect to TMDB API - $e');
    } catch (e) {
      throw Exception('Unexpected error while fetching stories: $e');
    }
  }
}
