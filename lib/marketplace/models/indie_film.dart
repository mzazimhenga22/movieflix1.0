// models/indie_film.dart
class IndieFilm {
  final int? id; // Changed from String? to int?
  final String title;
  final String synopsis;
  final double fundingGoal;
  final String videoBase64;
  final String creatorName;
  final String creatorEmail;

  IndieFilm({
    this.id,
    required this.title,
    required this.synopsis,
    required this.fundingGoal,
    required this.videoBase64,
    required this.creatorName,
    required this.creatorEmail,
  });
}
