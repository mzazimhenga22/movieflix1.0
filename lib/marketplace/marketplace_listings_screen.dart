import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'package:movie_app/marketplace/marketplace_post_screen.dart';
import 'package:movie_app/marketplace/marketplace_item_model.dart';
import 'package:movie_app/marketplace/marketplace_item_db.dart';
import 'fan_events_screen.dart';

// -----------------------------------------------------------------------------
// Listing model (unchanged)
// -----------------------------------------------------------------------------
class Listing {
  final String id;
  final String title;
  final String imageUrl;
  final double price;
  final bool isAuction;
  final String timeRemaining;
  final String sellerName;
  final String sellerAvatarUrl;
  final double rating;
  final bool isSaved;

  Listing({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.isAuction,
    required this.timeRemaining,
    required this.sellerName,
    required this.sellerAvatarUrl,
    required this.rating,
    required this.isSaved,
  });

  factory Listing.fromItem(dynamic item) {
    String title;
    String imageUrl;
    double price;
    bool isAuction = item is MarketplaceAuction;
    String timeRemaining = '';
    String sellerName;
    String sellerAvatarUrl = 'https://via.placeholder.com/150';
    double rating = 4.5;
    String defaultImageUrl = 'https://via.placeholder.com/150';

    if (item is MarketplaceTicket) {
      title = item.movieTitle;
      imageUrl = (item.moviePoster?.isNotEmpty == true)
          ? item.moviePoster!
          : defaultImageUrl;
      price = item.price;
      sellerName = item.sellerName ?? 'Unknown';
    } else if (item is MarketplaceCollectible) {
      title = item.name;
      imageUrl = (item.imageBase64?.isNotEmpty == true)
          ? 'data:image/jpeg;base64,${item.imageBase64}'
          : defaultImageUrl;
      price = item.price;
      sellerName = item.sellerName ?? 'Unknown';
    } else if (item is MarketplaceAuction) {
      title = item.name;
      imageUrl = (item.imageBase64?.isNotEmpty == true)
          ? 'data:image/jpeg;base64,${item.imageBase64}'
          : defaultImageUrl;
      price = item.startingPrice;
      timeRemaining = item.endDate ?? 'Unknown';
      sellerName = item.sellerName ?? 'Unknown';
    } else if (item is MarketplaceRental) {
      title = item.name;
      imageUrl = (item.imageBase64?.isNotEmpty == true)
          ? 'data:image/jpeg;base64,${item.imageBase64}'
          : defaultImageUrl;
      price = item.pricePerDay;
      sellerName = item.sellerName ?? 'Unknown';
    } else if (item is MarketplaceIndieFilm) {
      title = item.title;
      imageUrl = (item.videoBase64?.isNotEmpty == true)
          ? 'data:video/mp4;base64,${item.videoBase64}'
          : defaultImageUrl;
      price = item.fundingGoal;
      sellerName = item.creatorName ?? 'Unknown';
    } else if (item is MarketplacePremiere) {
      title = item.movieTitle;
      imageUrl = defaultImageUrl;
      price = 0.0;
      sellerName = item.organizerName ?? 'Unknown';
    } else if (item is FanEvent) {
      title = item.eventName;
      imageUrl = defaultImageUrl;
      price = 0.0;
      sellerName = item.organizerName ?? 'Unknown';
    } else {
      title = 'Unknown Item';
      imageUrl = defaultImageUrl;
      price = 0.0;
      sellerName = 'Unknown';
    }

    return Listing(
      id: item.id?.toString() ?? '0',
      title: title,
      imageUrl: imageUrl,
      price: price,
      isAuction: isAuction,
      timeRemaining: timeRemaining,
      sellerName: sellerName,
      sellerAvatarUrl: sellerAvatarUrl,
      rating: rating,
      isSaved: false,
    );
  }
}

// -----------------------------------------------------------------------------
// Main screen + state (UPDATED to use getAll())
// -----------------------------------------------------------------------------
class MarketplaceListingsScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const MarketplaceListingsScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  MarketplaceListingsScreenState createState() =>
      MarketplaceListingsScreenState();
}

class MarketplaceListingsScreenState extends State<MarketplaceListingsScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Listing> _listings = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      // Fetch ALL items (newest first)
      final items = await MarketplaceItemDb.instance.getAll();
      setState(() {
        _listings = items
            .map((item) => Listing.fromItem(item))
            .where((listing) => listing.title
                .toLowerCase()
                .contains(_searchQuery.toLowerCase().trim()))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading items: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openFilters() {
    // TODO: implement your filter modal
  }

  @override
  Widget build(BuildContext context) {
    final accent = Provider.of<SettingsProvider>(context).accentColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Marketplace Listings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: accent),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            color: accent,
            onPressed: _openFilters,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search listings...',
                prefixIcon: Icon(Icons.search, color: accent),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _loadItems(); // re-fetch & re-filter
              },
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 2,
            colors: [
              Color.fromRGBO(0, 255, 191, 0.12),
              Color.fromRGBO(17, 25, 40, 1),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadItems,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _listings.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ListingCard(
                        item: _listings[index],
                        accent: accent,
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        child: const Icon(Icons.camera_alt),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MarketplacePostScreen(
                userName: widget.userName,
                userEmail: widget.userEmail,
              ),
            ),
          );
          if (result == true) {
            _loadItems(); // Refresh after new post
          }
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Listing Card (unchanged)
// -----------------------------------------------------------------------------
class _ListingCard extends StatelessWidget {
  final Listing item;
  final Color accent;

  const _ListingCard({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color.fromARGB(160, 17, 25, 40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: item.imageUrl.startsWith('data:image')
                      ? Image.memory(
                          base64Decode(item.imageUrl.split(',')[1]),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Image.network(
                            'https://via.placeholder.com/150',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Image.network(
                            'https://via.placeholder.com/150',
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Favorite
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                              item.isSaved
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: accent),
                          onPressed: () {
                            // TODO: toggle saved
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    item.isAuction
                        ? Text('Ends in ${item.timeRemaining}',
                            style: const TextStyle(color: Colors.redAccent))
                        : Text(
                            item.price > 0
                                ? '\$${item.price.toStringAsFixed(2)}'
                                : 'Free',
                            style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    // Seller info
                    Row(
                      children: [
                        CircleAvatar(
                            radius: 12,
                            backgroundImage:
                                NetworkImage(item.sellerAvatarUrl)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(item.sellerName,
                                style: const TextStyle(color: Colors.white70),
                                overflow: TextOverflow.ellipsis)),
                        Text('${item.rating.toStringAsFixed(1)} ★',
                            style: const TextStyle(color: Colors.amberAccent)),
                        IconButton(
                          icon: const Icon(Icons.location_on),
                          color: accent,
                          onPressed: () {
                            // TODO: show location
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Call to action
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Text(
                                item.isAuction ? 'Place Bid' : 'View Details'),
                            onPressed: () {
                              // TODO: handle buy/bid
                            },
                          ),
                        ),
                        if (!item.isAuction) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_shopping_cart),
                            color: accent,
                            onPressed: () {
                              // TODO: add to cart
                            },
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
