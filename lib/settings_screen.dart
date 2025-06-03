import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/l10n/app_localizations.dart';
import 'settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Map<String, Color> availableBackgroundColors = {
    'Purple': Colors.purple,
    'Indigo': Colors.indigo,
    'Blue': Colors.blue,
    'Red': Colors.red,
    'Green': Colors.green,
    'Orange': Colors.orange,
    'Yellow': Colors.yellow,
    'Brown': Colors.brown,
    'Grey': Colors.grey,
    'Black': Color(0xff6e0101),
    'White': Colors.white,
    'cyan': Colors.cyan,
    'lime': Colors.lime,
    'pink': Colors.pink,
  };

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final localizations = AppLocalizations.of(context)!;
    String currentColorName = availableBackgroundColors.entries
        .firstWhere(
          (entry) => entry.value == settings.accentColor,
          orElse: () => const MapEntry('Default (Purple)', Colors.purple),
        )
        .key;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(localizations.downloadQuality),
            trailing: DropdownButton<String>(
              value: settings.downloadQuality,
              items: const [
                DropdownMenuItem(value: 'Low', child: Text('Low')),
                DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                DropdownMenuItem(value: 'High', child: Text('High')),
              ],
              onChanged: (val) {
                if (val != null) settings.setDownloadQuality(val);
              },
            ),
          ),
          SwitchListTile(
            title: Text(localizations.wifiOnlyDownloads),
            value: settings.wifiOnlyDownloads,
            onChanged: settings.setWifiOnlyDownloads,
          ),
          ListTile(
            title: Text(localizations.playbackQuality),
            trailing: DropdownButton<String>(
              value: settings.playbackQuality,
              items: const [
                DropdownMenuItem(value: '480p', child: Text('480p')),
                DropdownMenuItem(value: '720p', child: Text('720p')),
                DropdownMenuItem(value: '1080p', child: Text('1080p')),
                DropdownMenuItem(value: '4K', child: Text('4K')),
              ],
              onChanged: (val) {
                if (val != null) settings.setPlaybackQuality(val);
              },
            ),
          ),
          SwitchListTile(
            title: Text(localizations.subtitles),
            value: settings.subtitlesEnabled,
            onChanged: settings.setSubtitlesEnabled,
          ),
          ListTile(
            title: Text(localizations.language),
            trailing: DropdownButton<String>(
              value: settings.language,
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: 'Spanish', child: Text('Spanish')),
                DropdownMenuItem(value: 'French', child: Text('French')),
                DropdownMenuItem(value: 'German', child: Text('German')),
              ],
              onChanged: (val) {
                if (val != null) settings.setLanguage(val);
              },
            ),
          ),
          SwitchListTile(
            title: Text(localizations.autoPlayTrailers),
            value: settings.autoPlayTrailers,
            onChanged: settings.setAutoPlayTrailers,
          ),
          SwitchListTile(
            title: Text(localizations.notifications),
            value: settings.notificationsEnabled,
            onChanged: settings.setNotificationsEnabled,
          ),
          SwitchListTile(
            title: Text(localizations.parentalControl),
            value: settings.parentalControl,
            onChanged: settings.setParentalControl,
          ),
          SwitchListTile(
            title: Text(localizations.dataSaverMode),
            value: settings.dataSaverMode,
            onChanged: settings.setDataSaverMode,
          ),
          ListTile(
            title: Text(localizations.clearCache),
            subtitle: Text(
                "${localizations.cacheSize}: ${settings.cacheSize.toStringAsFixed(1)} MB"),
            trailing: ElevatedButton(
              onPressed: () {
                settings.clearCache();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(localizations.cacheCleared)),
                );
              },
              child: const Text("Clear"),
            ),
          ),
          ListTile(
            title: Text(localizations.backgroundColor),
            trailing: DropdownButton<String>(
              value: currentColorName,
              items: availableBackgroundColors.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.key),
                    ),
                  )
                  .toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  final newColor = availableBackgroundColors[newValue]!;
                  settings.setAccentColor(newColor);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
