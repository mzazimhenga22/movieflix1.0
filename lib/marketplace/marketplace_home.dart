import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movie_app/marketplace/ticket_sales_screen.dart';
import 'package:movie_app/marketplace/marketplace_listings_screen.dart';
import 'package:movie_app/marketplace/my_assets_screen.dart';

class MarketplaceHomeScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String? userAvatar;

  const MarketplaceHomeScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.userAvatar,
  });

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _filterFeatures(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = Colors.blueAccent; // Fallback accent color
    final filteredFeatures = _features
        .where((f) => f.title.toLowerCase().contains(_searchQuery))
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Marketplace',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyAssetsScreen(
                      userName: widget.userName,
                      userEmail: widget.userEmail,
                      userAvatar: widget.userAvatar,
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundImage: widget.userAvatar != null &&
                        widget.userAvatar!.isNotEmpty &&
                        Uri.tryParse(widget.userAvatar!)?.hasAbsolutePath ==
                            true
                    ? NetworkImage(widget.userAvatar!)
                    : null,
                child: widget.userAvatar == null ||
                        widget.userAvatar!.isEmpty ||
                        Uri.tryParse(widget.userAvatar!)?.hasAbsolutePath !=
                            true
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111927),
          image: DecorationImage(
            image: AssetImage('assets/marketplace_banner.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
          gradient: RadialGradient(
            center: Alignment(0.0, -0.6),
            radius: 1.2,
            colors: [Color.fromRGBO(0, 255, 191, 0.2), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(180, 17, 25, 40),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search categories...',
                              hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade600),
                              prefixIcon: const Icon(Icons.search,
                                  color: Colors.white70),
                              filled: true,
                              fillColor: Colors.grey.shade900,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                            ),
                            style: GoogleFonts.poppins(color: Colors.white),
                            onChanged: _filterFeatures,
                          ),
                        ),
                        // Banner with Animation
                        Container(
                          height: 160,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image:
                                  AssetImage('assets/marketplace_banner.png'),
                              fit: BoxFit.cover,
                            ),
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.7),
                                  Colors.transparent
                                ],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Text(
                                'Spring Movie Sale!',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 4,
                                      color: Colors.black54,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Quick Actions Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _QuickActionButton(
                                icon: Icons.add_circle,
                                label: 'Sell Now',
                                accent: accent,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TicketSalesScreen(
                                        userName: widget.userName,
                                        userEmail: widget.userEmail,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _QuickActionButton(
                                icon: Icons.shopping_cart,
                                label: 'View Cart',
                                accent: accent,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MarketplaceListingsScreen(
                                        userName: widget.userName,
                                        userEmail: widget.userEmail,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        // Featured Listings Carousel
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Featured Listings',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 180,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _featuredListings.length,
                                  itemBuilder: (context, index) {
                                    final listing = _featuredListings[index];
                                    return _FeaturedListingCard(
                                      listing: listing,
                                      accent: accent,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TicketSalesScreen(
                                              userName: widget.userName,
                                              userEmail: widget.userEmail,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Feature Grid
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Explore Categories',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final crossAxisCount =
                                      constraints.maxWidth > 600 ? 3 : 2;
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: filteredFeatures.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 1,
                                    ),
                                    itemBuilder: (context, i) {
                                      return _FeatureCard(
                                        feature: filteredFeatures[i],
                                        accent: accent,
                                        userName: widget.userName,
                                        userEmail: widget.userEmail,
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const List<_Feature> _features = [
    _Feature(
        icon: Icons.shopping_bag, title: 'Collectibles', routeToListings: true),
    _Feature(icon: Icons.gavel, title: 'Auctions', routeToListings: true),
    _Feature(icon: Icons.swap_horiz, title: 'Rentals', routeToListings: true),
    _Feature(
        icon: Icons.confirmation_number,
        title: 'Theater Tickets',
        routeToTickets: true),
    _Feature(icon: Icons.movie, title: 'Indie Films', routeToListings: true),
    _Feature(
        icon: Icons.new_releases, title: 'Premieres', routeToListings: true),
    _Feature(icon: Icons.star, title: 'Exclusive Merch', routeToListings: true),
    _Feature(icon: Icons.event, title: 'Fan Events', routeToListings: true),
  ];

  static const List<_FeaturedListing> _featuredListings = [
    _FeaturedListing(
      title: 'Exclusive Premiere Ticket',
      image: 'assets/icon/premierticket.jpg',
      price: 49.99,
    ),
    _FeaturedListing(
      title: 'Rare Movie Poster',
      image: 'assets/icon/movieposter.jpg',
      price: 29.99,
    ),
    _FeaturedListing(
      title: 'Indie Film Screening',
      image: 'assets/icon/indiefilm.jpg',
      price: 19.99,
    ),
  ];
}

class _Feature {
  final IconData icon;
  final String title;
  final bool routeToListings;
  final bool routeToTickets;

  const _Feature({
    required this.icon,
    required this.title,
    this.routeToListings = false,
    this.routeToTickets = false,
  });
}

class _FeaturedListing {
  final String title;
  final String image;
  final double price;

  const _FeaturedListing({
    required this.title,
    required this.image,
    required this.price,
  });
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  final Color accent;
  final String userName;
  final String userEmail;

  const _FeatureCard({
    required this.feature,
    required this.accent,
    required this.userName,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (feature.routeToTickets) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TicketSalesScreen(
                userName: userName,
                userEmail: userEmail,
              ),
            ),
          );
        } else if (feature.routeToListings) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MarketplaceListingsScreen(
                userName: userName,
                userEmail: userEmail,
              ),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(160, 17, 25, 40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(feature.icon, size: 42, color: accent),
                const SizedBox(height: 12),
                Text(
                  feature.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedListingCard extends StatelessWidget {
  final _FeaturedListing listing;
  final Color accent;
  final VoidCallback onTap;

  const _FeaturedListingCard({
    required this.listing,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade900,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.asset(
                listing.image,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 100,
                  color: Colors.grey.shade800,
                  child: const Icon(Icons.image_not_supported,
                      color: Colors.white70),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${listing.price.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
