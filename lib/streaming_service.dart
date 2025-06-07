import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

class StreamingNotAvailableException implements Exception {
  final String message;
  StreamingNotAvailableException(this.message);

  @override
  String toString() => 'StreamingNotAvailableException: $message';
}

class StreamingService {
  static final _logger = Logger();

  /// Retrieves a streaming link or playlist for a movie or TV show.
  ///
  /// Parameters:
  /// - tmdbId: The TMDB ID of the media.
  /// - title: The title of the media.
  /// - resolution: Desired resolution (e.g., "720p", "1080p").
  /// - enableSubtitles: Whether to include subtitles if available.
  /// - season: Season number for TV shows (optional).
  /// - episode: Episode number for TV shows (optional).
  /// - seasonTmdbId: TMDB ID for the season (optional, defaults to tmdbId).
  /// - episodeTmdbId: TMDB ID for the episode (optional, defaults to tmdbId).
  /// - forDownload: If true, fetches and saves the playlist for offline use.
  ///
  /// Returns a map with keys:
  /// - 'url': A URL or file path playable by VideoPlayerController.
  /// - 'type': 'm3u8' or 'mp4'.
  /// - 'title': The input title.
  /// - 'subtitleUrl': URL to subtitle (.srt) if available and enabled.
  /// - 'playlist': Raw M3U8 playlist content if applicable.
  static Future<Map<String, String>> getStreamingLink({
    required String tmdbId,
    required String title,
    required String resolution,
    required bool enableSubtitles,
    int? season,
    int? episode,
    String? seasonTmdbId,
    String? episodeTmdbId,
    bool forDownload = false,
  }) async {
    _logger.i('Calling backend for streaming link: $tmdbId');

    final url = Uri.parse('https://moviflxpro.onrender.com/media-links');
    final isShow = season != null && episode != null;

    final body = <String, dynamic>{
      'type': isShow ? 'show' : 'movie',
      'tmdbId': tmdbId,
      'title': title,
      'releaseYear': DateTime.now().year.toString(),
      if (isShow) ...{
        'seasonNumber': season, // Send as integer
        'seasonTmdbId': int.parse(seasonTmdbId ?? tmdbId), // Parse to integer
        'episodeNumber': episode, // Send as integer
        'episodeTmdbId': int.parse(episodeTmdbId ?? tmdbId), // Parse to integer
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        _logger.e('Backend error: ${response.statusCode} ${response.body}');
        throw StreamingNotAvailableException(
          'Failed to get streaming link: ${response.statusCode}',
        );
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _logger.e('Invalid response format: $decoded');
        throw StreamingNotAvailableException('Invalid response format.');
      }
      final data = decoded;
      _logger.d('Raw backend JSON: $data');

      // Normalize streams list
      List<Map<String, dynamic>> streamsList;
      if (data['streams'] != null) {
        streamsList = List<Map<String, dynamic>>.from(data['streams']);
      } else if (data['stream'] != null) {
        streamsList = [
          {
            'sourceId': data['sourceId']?.toString() ?? 'unknown',
            'stream': Map<String, dynamic>.from(data['stream']),
          }
        ];
      } else {
        _logger.w('No streams found: $data');
        throw StreamingNotAvailableException('No streaming links available.');
      }

      if (streamsList.isEmpty) {
        _logger.w('Streams list is empty.');
        throw StreamingNotAvailableException('No streaming links available.');
      }

      final selected = streamsList.firstWhere(
        (s) => s['stream'] != null,
        orElse: () {
          _logger.w('No valid stream in list: $streamsList');
          throw StreamingNotAvailableException('No valid stream available.');
        },
      );

      final streamData = selected['stream'] as Map<String, dynamic>;

      String? playlist;
      String streamType = 'm3u8';
      String streamUrl = '';
      String subtitleUrl = '';

      // Handle base64-encoded M3U8 playlist
      final playlistEncoded = streamData['playlist'] as String?;
      if (playlistEncoded != null &&
          playlistEncoded
              .startsWith('data:application/vnd.apple.mpegurl;base64,')) {
        final base64Part = playlistEncoded.split(',')[1];
        playlist = utf8.decode(base64Decode(base64Part));
        _logger.i('Decoded M3U8 playlist:\n$playlist');

        if (kIsWeb) {
          // Create a Blob URL for web
          final bytes = base64Decode(base64Part);
          final blob = html.Blob([bytes], 'application/vnd.apple.mpegurl');
          streamUrl = html.Url.createObjectUrlFromBlob(blob);
        } else {
          // Write to temporary file on mobile/desktop
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$tmdbId-playlist.m3u8');
          await file.writeAsString(playlist);
          streamUrl = file.path;
        }
        streamType = 'm3u8';
      } else {
        // Handle non-base64 URL
        final urlValue = streamData['url']?.toString();
        if (urlValue == null || urlValue.isEmpty) {
          _logger.e('No stream URL provided: $streamData');
          throw StreamingNotAvailableException('No stream URL available.');
        }
        streamUrl = urlValue;

        if (streamUrl.endsWith('.m3u8')) {
          streamType = 'm3u8';
          if (forDownload) {
            final playlistResponse = await http.get(Uri.parse(streamUrl));
            if (playlistResponse.statusCode == 200) {
              playlist = playlistResponse.body;
              if (!kIsWeb) {
                final dir = await getTemporaryDirectory();
                final file = File('${dir.path}/$tmdbId-playlist.m3u8');
                await file.writeAsString(playlist);
                streamUrl = file.path;
              }
            } else {
              _logger.e(
                'Failed to fetch M3U8 playlist: ${playlistResponse.statusCode}',
              );
              throw StreamingNotAvailableException('Failed to fetch playlist.');
            }
          }
        } else if (streamUrl.endsWith('.mp4')) {
          streamType = 'mp4';
        } else {
          streamType = streamData['type']?.toString() ?? 'm3u8';
        }
      }

      // Handle subtitles
      final captionsList = streamData['captions'] as List<dynamic>?;
      if (enableSubtitles && captionsList != null && captionsList.isNotEmpty) {
        final selectedCap = captionsList.firstWhere(
          (c) => c['language'] == 'en',
          orElse: () => captionsList.first,
        );
        subtitleUrl = selectedCap['url']?.toString() ?? '';
        // For downloads, save subtitle file locally on mobile/desktop
        if (forDownload && subtitleUrl.isNotEmpty) {
          try {
            final subtitleResponse = await http.get(Uri.parse(subtitleUrl));
            if (subtitleResponse.statusCode == 200) {
              if (!kIsWeb) {
                final dir = await getTemporaryDirectory();
                final subtitleFile = File('${dir.path}/$tmdbId-subtitles.srt');
                await subtitleFile.writeAsBytes(subtitleResponse.bodyBytes);
                subtitleUrl = subtitleFile.path;
              }
            } else {
              _logger.w(
                  'Failed to download subtitles: ${subtitleResponse.statusCode}');
              subtitleUrl = '';
            }
          } catch (e) {
            _logger.w('Error downloading subtitles: $e');
            subtitleUrl = '';
          }
        }
      }

      final result = <String, String>{
        'url': streamUrl,
        'type': streamType,
        'title': title,
      };
      if (playlist != null) {
        result['playlist'] = playlist;
      }
      if (subtitleUrl.isNotEmpty) {
        result['subtitleUrl'] = subtitleUrl;
      }

      _logger.i('Streaming link retrieved: $result');
      return result;
    } catch (e, st) {
      _logger.e('Error fetching stream for tmdbId: $tmdbId',
          error: e, stackTrace: st);
      rethrow;
    }
  }
}
