// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get settings => 'Configuraciones';

  @override
  String get downloadQuality => 'Calidad de descarga';

  @override
  String get wifiOnlyDownloads => 'Descargas solo con Wi-Fi';

  @override
  String get playbackQuality => 'Calidad de reproducción';

  @override
  String get subtitles => 'Subtítulos';

  @override
  String get language => 'Idioma';

  @override
  String get autoPlayTrailers => 'Reproducir avances automáticamente';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get parentalControl => 'Control parental';

  @override
  String get dataSaverMode => 'Modo de ahorro de datos';

  @override
  String get clearCache => 'Borrar caché';

  @override
  String get cacheSize => 'Tamaño del caché';

  @override
  String get cacheCleared => 'Caché borrado';

  @override
  String get backgroundColor => 'Color de fondo';
}
