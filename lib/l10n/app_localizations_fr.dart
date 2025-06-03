// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settings => 'Paramètres';

  @override
  String get downloadQuality => 'Qualité de téléchargement';

  @override
  String get wifiOnlyDownloads => 'Téléchargements uniquement via Wi-Fi';

  @override
  String get playbackQuality => 'Qualité de lecture';

  @override
  String get subtitles => 'Sous-titres';

  @override
  String get language => 'Langue';

  @override
  String get autoPlayTrailers => 'Lecture automatique des bandes-annonces';

  @override
  String get notifications => 'Notifications';

  @override
  String get parentalControl => 'Contrôle parental';

  @override
  String get dataSaverMode => 'Mode économiseur de données';

  @override
  String get clearCache => 'Vider le cache';

  @override
  String get cacheSize => 'Taille du cache';

  @override
  String get cacheCleared => 'Cache vidé';

  @override
  String get backgroundColor => 'Couleur de fond';
}
