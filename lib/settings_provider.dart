import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SettingsProvider with ChangeNotifier {
  String _downloadQuality = 'Medium';
  bool _wifiOnlyDownloads = true;
  String _playbackQuality = '720p';
  bool _subtitlesEnabled = true;
  String _language = 'English';
  bool _autoPlayTrailers = true;
  bool _notificationsEnabled = true;
  bool _parentalControl = false;
  bool _dataSaverMode = false;
  double _cacheSize = 0.0;
  Color _accentColor = Colors.red;

  SettingsProvider() {
    _loadCacheSize();
  }

  String get downloadQuality => _downloadQuality;
  bool get wifiOnlyDownloads => _wifiOnlyDownloads;
  String get playbackQuality => _playbackQuality;
  bool get subtitlesEnabled => _subtitlesEnabled;
  String get language => _language;
  bool get autoPlayTrailers => _autoPlayTrailers;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get parentalControl => _parentalControl;
  bool get dataSaverMode => _dataSaverMode;
  double get cacheSize => _cacheSize;
  Color get accentColor => _accentColor;

  List<Color> get accentGradientColors => [
        _accentColor.withOpacity(0.5),
        _accentColor.withOpacity(0.3),
      ];

  void setDownloadQuality(String quality) {
    _downloadQuality = quality;
    notifyListeners();
  }

  void setWifiOnlyDownloads(bool value) {
    _wifiOnlyDownloads = value;
    notifyListeners();
  }

  void setPlaybackQuality(String quality) {
    _playbackQuality = quality;
    notifyListeners();
  }

  void setSubtitlesEnabled(bool value) {
    _subtitlesEnabled = value;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  void setAutoPlayTrailers(bool value) {
    _autoPlayTrailers = value;
    notifyListeners();
  }

  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    notifyListeners();
  }

  void setParentalControl(bool value) {
    _parentalControl = value;
    notifyListeners();
  }

  void setDataSaverMode(bool value) {
    _dataSaverMode = value;
    notifyListeners();
  }

  void setAccentColor(Color color) {
    _accentColor = color;
    notifyListeners();
  }

  Future<void> _loadCacheSize() async {
    final tempDir = await getTemporaryDirectory();
    double sizeInMB = 0.0;
    if (tempDir.existsSync()) {
      await for (var entity in tempDir.list(recursive: true)) {
        if (entity is File) {
          final sizeInBytes = await entity.length();
          sizeInMB += sizeInBytes / (1024 * 1024); // Convert to MB
        }
      }
    }
    _cacheSize = sizeInMB;
    notifyListeners();
  }

  Future<void> clearCache() async {
    final tempDir = await getTemporaryDirectory();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
      await tempDir.create(recursive: true); // Recreate empty directory
    }
    _cacheSize = 0.0;
    notifyListeners();
  }

  Locale getLocale() {
    switch (_language) {
      case 'Spanish':
        return const Locale('es');
      case 'French':
        return const Locale('fr');
      case 'German':
        return const Locale('de');
      case 'English':
      default:
        return const Locale('en');
    }
  }
}
