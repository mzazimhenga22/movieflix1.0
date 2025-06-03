import 'dart:convert';
import 'package:movie_app/marketplace/models/indie_film.dart';
import 'package:movie_app/marketplace/models/premiere.dart';

/// Interface for marketplace items
abstract class MarketplaceItem {
  int? get id;
  String get type;
  bool get isHidden;
  Map<String, dynamic> toSqlMap();
  MarketplaceItem copyWith({Map<String, dynamic> updates});
}

/// Ticket listing
class MarketplaceTicket implements MarketplaceItem {
  @override
  final int? id;
  final int movieId;
  final String movieTitle;
  final String moviePoster;
  final String location;
  final double price;
  final String date;
  final int seats;
  final String? imageBase64;
  final String? seatDetails;
  final String? ticketFileBase64;
  bool isLocked;
  final String? sellerName;
  final String? sellerEmail;
  @override
  final bool isHidden;
  @override
  final String type = 'ticket';

  MarketplaceTicket({
    this.id,
    required this.movieId,
    required this.movieTitle,
    required this.moviePoster,
    required this.location,
    required this.price,
    required this.date,
    required this.seats,
    this.imageBase64,
    this.seatDetails,
    this.ticketFileBase64,
    this.isLocked = false,
    this.sellerName,
    this.sellerEmail,
    this.isHidden = false,
  });

  @override
  Map<String, dynamic> toSqlMap() => {
        'id': id,
        'type': type,
        'movieId': movieId,
        'movieTitle': movieTitle,
        'moviePoster': moviePoster,
        'location': location,
        'price': price,
        'date': date,
        'seats': seats,
        'imageBase64': imageBase64,
        'seatDetails': seatDetails,
        'ticketFileBase64': ticketFileBase64,
        'isLocked': isLocked ? 1 : 0,
        'sellerName': sellerName,
        'sellerEmail': sellerEmail,
        'isHidden': isHidden ? 1 : 0,
      };

  factory MarketplaceTicket.fromSql(Map<String, dynamic> row) =>
      MarketplaceTicket(
        id: row['id'] as int?,
        movieId: row['movieId'] as int? ?? 0,
        movieTitle: row['movieTitle'] as String? ?? 'Unknown',
        moviePoster: row['moviePoster'] as String? ?? '',
        location: row['location'] as String? ?? '',
        price: (row['price'] as num?)?.toDouble() ?? 0.0,
        date: row['date'] as String? ?? DateTime.now().toIso8601String(),
        seats: row['seats'] as int? ?? 1,
        imageBase64: row['imageBase64'] as String?,
        seatDetails: row['seatDetails'] as String?,
        ticketFileBase64: row['ticketFileBase64'] as String?,
        isLocked: (row['isLocked'] as int?) == 1,
        sellerName: row['sellerName'] as String?,
        sellerEmail: row['sellerEmail'] as String?,
        isHidden: (row['isHidden'] as int?) == 1,
      );

  @override
  MarketplaceTicket copyWith({Map<String, dynamic> updates = const {}}) =>
      MarketplaceTicket(
        id: updates['id'] as int? ?? id,
        movieId: updates['movieId'] as int? ?? movieId,
        movieTitle: updates['movieTitle'] as String? ?? movieTitle,
        moviePoster: updates['moviePoster'] as String? ?? moviePoster,
        location: updates['location'] as String? ?? location,
        price: updates['price'] as double? ?? price,
        date: updates['date'] as String? ?? date,
        seats: updates['seats'] as int? ?? seats,
        imageBase64: updates['imageBase64'] as String? ?? imageBase64,
        seatDetails: updates['seatDetails'] as String? ?? seatDetails,
        ticketFileBase64:
            updates['ticketFileBase64'] as String? ?? ticketFileBase64,
        isLocked: updates['isLocked'] as bool? ?? isLocked,
        sellerName: updates['sellerName'] as String? ?? sellerName,
        sellerEmail: updates['sellerEmail'] as String? ?? sellerEmail,
        isHidden: updates['isHidden'] as bool? ?? isHidden,
      );
}

/// Collectible item
class MarketplaceCollectible implements MarketplaceItem {
  @override
  final int? id;
  final String name;
  final String description;
  final double price;
  final String? imageBase64;
  final String? authenticityDocBase64;
  final String? sellerName;
  final String? sellerEmail;
  @override
  final bool isHidden;
  @override
  final String type = 'collectible';

  MarketplaceCollectible({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageBase64,
    this.authenticityDocBase64,
    this.sellerName,
    this.sellerEmail,
    this.isHidden = false,
  });

  @override
  Map<String, dynamic> toSqlMap() => {
        'id': id,
        'type': type,
        'name': name,
        'description': description,
        'price': price,
        'imageBase64': imageBase64,
        'authenticityDocBase64': authenticityDocBase64,
        'sellerName': sellerName,
        'sellerEmail': sellerEmail,
        'isHidden': isHidden ? 1 : 0,
      };

  factory MarketplaceCollectible.fromSql(Map<String, dynamic> row) =>
      MarketplaceCollectible(
        id: row['id'] as int?,
        name: row['name'] as String? ?? 'Unknown',
        description: row['description'] as String? ?? '',
        price: (row['price'] as num?)?.toDouble() ?? 0.0,
        imageBase64: row['imageBase64'] as String?,
        authenticityDocBase64: row['authenticityDocBase64'] as String?,
        sellerName: row['sellerName'] as String?,
        sellerEmail: row['sellerEmail'] as String?,
        isHidden: (row['isHidden'] as int?) == 1,
      );

  @override
  MarketplaceCollectible copyWith({Map<String, dynamic> updates = const {}}) =>
      MarketplaceCollectible(
        id: updates['id'] as int? ?? id,
        name: updates['name'] as String? ?? name,
        description: updates['description'] as String? ?? description,
        price: updates['price'] as double? ?? price,
        imageBase64: updates['imageBase64'] as String? ?? imageBase64,
        authenticityDocBase64: updates['authenticityDocBase64'] as String? ??
            authenticityDocBase64,
        sellerName: updates['sellerName'] as String? ?? sellerName,
        sellerEmail: updates['sellerEmail'] as String? ?? sellerEmail,
        isHidden: updates['isHidden'] as bool? ?? isHidden,
      );
}

/// Auction item
class MarketplaceAuction implements MarketplaceItem {
  @override
  final int? id;
  final String name;
  final String description;
  final double startingPrice;
  final String endDate;
  final String? imageBase64;
  final String? sellerName;
  final String? sellerEmail;
  @override
  final bool isHidden;
  @override
  final String type = 'auction';

  MarketplaceAuction({
    this.id,
    required this.name,
    required this.description,
    required this.startingPrice,
    required this.endDate,
    this.imageBase64,
    this.sellerName,
    this.sellerEmail,
    this.isHidden = false,
  });

  @override
  Map<String, dynamic> toSqlMap() => {
        'id': id,
        'type': type,
        'name': name,
        'description': description,
        'startingPrice': startingPrice,
        'endDate': endDate,
        'imageBase64': imageBase64,
        'sellerName': sellerName,
        'sellerEmail': sellerEmail,
        'isHidden': isHidden ? 1 : 0,
      };

  factory MarketplaceAuction.fromSql(Map<String, dynamic> row) =>
      MarketplaceAuction(
        id: row['id'] as int?,
        name: row['name'] as String? ?? 'Unknown',
        description: row['description'] as String? ?? '',
        startingPrice: (row['startingPrice'] as num?)?.toDouble() ?? 0.0,
        endDate: row['endDate'] as String? ?? DateTime.now().toIso8601String(),
        imageBase64: row['imageBase64'] as String?,
        sellerName: row['sellerName'] as String?,
        sellerEmail: row['sellerEmail'] as String?,
        isHidden: (row['isHidden'] as int?) == 1,
      );

  @override
  MarketplaceAuction copyWith({Map<String, dynamic> updates = const {}}) =>
      MarketplaceAuction(
        id: updates['id'] as int? ?? id,
        name: updates['name'] as String? ?? name,
        description: updates['description'] as String? ?? description,
        startingPrice: updates['startingPrice'] as double? ?? startingPrice,
        endDate: updates['endDate'] as String? ?? endDate,
        imageBase64: updates['imageBase64'] as String? ?? imageBase64,
        sellerName: updates['sellerName'] as String? ?? sellerName,
        sellerEmail: updates['sellerEmail'] as String? ?? sellerEmail,
        isHidden: updates['isHidden'] as bool? ?? isHidden,
      );
}

/// Rental item
class MarketplaceRental implements MarketplaceItem {
  @override
  final int? id;
  final String name;
  final String description;
  final double pricePerDay;
  final int minDays;
  final String? imageBase64;
  final String? sellerName;
  final String? sellerEmail;
  @override
  final bool isHidden;
  @override
  final String type = 'rental';

  MarketplaceRental({
    this.id,
    required this.name,
    required this.description,
    required this.pricePerDay,
    required this.minDays,
    this.imageBase64,
    this.sellerName,
    this.sellerEmail,
    this.isHidden = false,
  });

  @override
  Map<String, dynamic> toSqlMap() => {
        'id': id,
        'type': type,
        'name': name,
        'description': description,
        'pricePerDay': pricePerDay,
        'minDays': minDays,
        'imageBase64': imageBase64,
        'sellerName': sellerName,
        'sellerEmail': sellerEmail,
        'isHidden': isHidden ? 1 : 0,
      };

  factory MarketplaceRental.fromSql(Map<String, dynamic> row) =>
      MarketplaceRental(
        id: row['id'] as int?,
        name: row['name'] as String? ?? 'Unknown',
        description: row['description'] as String? ?? '',
        pricePerDay: (row['pricePerDay'] as num?)?.toDouble() ?? 0.0,
        minDays: row['minDays'] as int? ?? 1,
        imageBase64: row['imageBase64'] as String?,
        sellerName: row['sellerName'] as String?,
        sellerEmail: row['sellerEmail'] as String?,
        isHidden: (row['isHidden'] as int?) == 1,
      );

  @override
  MarketplaceRental copyWith({Map<String, dynamic> updates = const {}}) =>
      MarketplaceRental(
        id: updates['id'] as int? ?? id,
        name: updates['name'] as String? ?? name,
        description: updates['description'] as String? ?? description,
        pricePerDay: updates['pricePerDay'] as double? ?? pricePerDay,
        minDays: updates['minDays'] as int? ?? minDays,
        imageBase64: updates['imageBase64'] as String? ?? imageBase64,
        sellerName: updates['sellerName'] as String? ?? sellerName,
        sellerEmail: updates['sellerEmail'] as String? ?? sellerEmail,
        isHidden: updates['isHidden'] as bool? ?? isHidden,
      );
}

/// Indie Film listing
class MarketplaceIndieFilm extends IndieFilm implements MarketplaceItem {
  @override
  final int? id;
  @override
  final bool isHidden;
  @override
  final String type = 'indie_film';

  MarketplaceIndieFilm({
    this.id,
    required String title,
    required String synopsis,
    required double fundingGoal,
    required String videoBase64,
    required String creatorName,
    required String creatorEmail,
    this.isHidden = false,
  }) : super(
          id: id,
          title: title,
          synopsis: synopsis,
          fundingGoal: fundingGoal,
          videoBase64: videoBase64,
          creatorName: creatorName,
          creatorEmail: creatorEmail,
        );

  @override
  Map<String, dynamic> toSqlMap() => {
        'id': id,
        'type': type,
        'title': title,
        'synopsis': synopsis,
        'fundingGoal': fundingGoal,
        'videoBase64': videoBase64,
        'creatorName': creatorName,
        'creatorEmail': creatorEmail,
        'isHidden': isHidden ? 1 : 0,
      };

  factory MarketplaceIndieFilm.fromSql(Map<String, dynamic> row) =>
      MarketplaceIndieFilm(
        id: row['id'] as int?,
        title: row['title'] as String? ?? 'Unknown',
        synopsis: row['synopsis'] as String? ?? '',
        fundingGoal: (row['fundingGoal'] as num?)?.toDouble() ?? 0.0,
        videoBase64: row['videoBase64'] as String? ?? '',
        creatorName: row['creatorName'] as String? ?? '',
        creatorEmail: row['creatorEmail'] as String? ?? '',
        isHidden: (row['isHidden'] as int?) == 1,
      );

  @override
  MarketplaceIndieFilm copyWith({Map<String, dynamic> updates = const {}}) =>
      MarketplaceIndieFilm(
        id: updates['id'] as int? ?? id,
        title: updates['title'] as String? ?? title,
        synopsis: updates['synopsis'] as String? ?? synopsis,
        fundingGoal: updates['fundingGoal'] as double? ?? fundingGoal,
        videoBase64: updates['videoBase64'] as String? ?? videoBase64,
        creatorName: updates['creatorName'] as String? ?? creatorName,
        creatorEmail: updates['creatorEmail'] as String? ?? creatorEmail,
        isHidden: updates['isHidden'] as bool? ?? isHidden,
      );
}

/// Premiere listing
class MarketplacePremiere extends Premiere implements MarketplaceItem {
  @override
  final int? id;
  @override
  final bool isHidden;
  @override
  final String type = 'premiere';

  MarketplacePremiere({
    this.id,
    required String movieTitle,
    required String location,
    required DateTime date,
    required String organizerName,
    required String organizerEmail,
    this.isHidden = false,
  }) : super(
          id: id,
          movieTitle: movieTitle,
          location: location,
          date: date,
          organizerName: organizerName,
          organizerEmail: organizerEmail,
        );

  @override
  Map<String, dynamic> toSqlMap() => {
        'id': id,
        'type': type,
        'movieTitle': movieTitle,
        'location': location,
        'date': date.toIso8601String(),
        'organizerName': organizerName,
        'organizerEmail': organizerEmail,
        'isHidden': isHidden ? 1 : 0,
      };

  factory MarketplacePremiere.fromSql(Map<String, dynamic> row) =>
      MarketplacePremiere(
        id: row['id'] as int?,
        movieTitle: row['movieTitle'] as String? ?? 'Unknown',
        location: row['location'] as String? ?? '',
        date: DateTime.parse(
            row['date'] as String? ?? DateTime.now().toIso8601String()),
        organizerName: row['organizerName'] as String? ?? '',
        organizerEmail: row['organizerEmail'] as String? ?? '',
        isHidden: (row['isHidden'] as int?) == 1,
      );

  @override
  MarketplacePremiere copyWith({Map<String, dynamic> updates = const {}}) =>
      MarketplacePremiere(
        id: updates['id'] as int? ?? id,
        movieTitle: updates['movieTitle'] as String? ?? movieTitle,
        location: updates['location'] as String? ?? location,
        date: updates['date'] is String
            ? DateTime.parse(updates['date'] as String)
            : (updates['date'] as DateTime? ?? date),
        organizerName: updates['organizerName'] as String? ?? organizerName,
        organizerEmail: updates['organizerEmail'] as String? ?? organizerEmail,
        isHidden: updates['isHidden'] as bool? ?? isHidden,
      );
}

/// Factory to create items from database rows
MarketplaceItem fromSql(Map<String, dynamic> row) {
  final type = row['type'] as String?;
  if (type == null) {
    throw Exception('Missing type in database row');
  }
  switch (type) {
    case 'ticket':
      return MarketplaceTicket.fromSql(row);
    case 'collectible':
      return MarketplaceCollectible.fromSql(row);
    case 'auction':
      return MarketplaceAuction.fromSql(row);
    case 'rental':
      return MarketplaceRental.fromSql(row);
    case 'indie_film':
      return MarketplaceIndieFilm.fromSql(row);
    case 'premiere':
      return MarketplacePremiere.fromSql(row);
    default:
      throw Exception('Unknown item type: $type');
  }
}
