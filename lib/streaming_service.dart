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

  static Future<Map<String, String>> getStreamingLink({
    required String tmdbId,
    required String title,
    required int releaseYear, // Now required
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
      'releaseYear': releaseYear.toString(),
      'resolution': resolution,
      'subtitleLanguage': 'en',
      if (isShow) ...{
        'seasonNumber': season,
        'seasonTmdbId': seasonTmdbId ?? tmdbId,
        'episodeNumber': episode,
        'episodeTmdbId': episodeTmdbId ?? tmdbId,
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
      if (decoded is! Map<String, dynamic> || decoded['streams'] == null) {
        _logger.e('Invalid response format: $decoded');
        throw StreamingNotAvailableException('Invalid response format.');
      }

      final streams = List<Map<String, dynamic>>.from(decoded['streams']);
      if (streams.isEmpty) {
        _logger.w('No streams found');
        throw StreamingNotAvailableException('No streaming links available.');
      }

      // Select the first stream for now; you can add logic to choose the best one
      final selectedStream = streams.first;

      String? playlist;
      String streamType = 'm3u8';
      String streamUrl = '';
      String subtitleUrl = '';

      // Handle base64-encoded M3U8 playlist
      final playlistEncoded = selectedStream['playlist'] as String?;
      if (playlistEncoded != null &&
          playlistEncoded
              .startsWith('data:application/vnd.apple.mpegurl;base64,')) {
        final base64Part = playlistEncoded.split(',')[1];
        playlist = utf8.decode(base64Decode(base64Part));
        _logger.i('Decoded M3U8 playlist:\n$playlist');

        if (kIsWeb) {
          final bytes = base64Decode(base64Part);
          final blob = html.Blob([bytes], 'application/vnd.apple.mpegurl');
          streamUrl = html.Url.createObjectUrlFromBlob(blob);
        } else {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$tmdbId-playlist.m3u8');
          await file.writeAsString(playlist);
          streamUrl = file.path;
        }
        streamType = 'm3u8';
      } else {
        final urlValue = selectedStream['url']?.toString();
        if (urlValue == null || urlValue.isEmpty) {
          _logger.e('No stream URL provided: $selectedStream');
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
                  'Failed to fetch M3U8 playlist: ${playlistResponse.statusCode}');
              throw StreamingNotAvailableException('Failed to fetch playlist.');
            }
          }
        } else if (streamUrl.endsWith('.mp4')) {
          streamType = 'mp4';
        } else {
          streamType = selectedStream['type']?.toString() ?? 'm3u8';
        }
      }

      // Handle subtitles
      final captionsList = selectedStream['captions'] as List<dynamic>?;
      if (enableSubtitles && captionsList != null && captionsList.isNotEmpty) {
        final selectedCap = captionsList.firstWhere(
          (c) => c['language'] == 'en',
          orElse: () => captionsList.first,
        );
        subtitleUrl = selectedCap['url']?.toString() ?? '';
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
