import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ticket_post_screen.dart';
import 'collectible_post_screen.dart';
import 'auction_post_screen.dart';
import 'rental_post_screen.dart';
import 'indie_film_post_screen.dart';
import 'premiere_post_screen.dart';
import 'marketplace_item_model.dart';
import 'fan_events_screen.dart';

class MarketplacePostScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final MarketplaceItem? existingItem;

  const MarketplacePostScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.existingItem,
  });

  @override
  State<MarketplacePostScreen> createState() => _MarketplacePostScreenState();
}

class _MarketplacePostScreenState extends State<MarketplacePostScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onItemPosted() {
    // Notify the parent screen to refresh listings
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingItem != null ? 'Edit Item' : 'Post Item',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.blueAccent,
          labelStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(color: Colors.white70),
          tabs: const [
            Tab(text: 'Tickets'),
            Tab(text: 'Collectibles'),
            Tab(text: 'Auctions'),
            Tab(text: 'Rentals'),
            Tab(text: 'Indie Films'),
            Tab(text: 'Premieres'),
            Tab(text: 'Fan Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TicketPostScreen(
            userName: widget.userName,
            userEmail: widget.userEmail,
            existingTicket: widget.existingItem is MarketplaceTicket
                ? widget.existingItem as MarketplaceTicket
                : null,
            onPosted: _onItemPosted,
          ),
          CollectiblePostScreen(
            userName: widget.userName,
            userEmail: widget.userEmail,
            existingCollectible: widget.existingItem is MarketplaceCollectible
                ? widget.existingItem as MarketplaceCollectible
                : null,
            onPosted:
                _onItemPosted, // Uncomment when CollectiblePostScreen is updated
          ),
          AuctionPostScreen(
            userName: widget.userName,
            userEmail: widget.userEmail,
            existingAuction: widget.existingItem is MarketplaceAuction
                ? widget.existingItem as MarketplaceAuction
                : null,
            onPosted: _onItemPosted,
          ),
          RentalPostScreen(
            userName: widget.userName,
            userEmail: widget.userEmail,
            existingRental: widget.existingItem is MarketplaceRental
                ? widget.existingItem as MarketplaceRental
                : null,
            onPosted:
                _onItemPosted, // Uncomment when RentalPostScreen is updated
          ),
          IndieFilmsScreen(
            userName: widget.userName,
            userEmail: widget.userEmail,
            existingFilm: widget.existingItem is MarketplaceIndieFilm
                ? widget.existingItem as MarketplaceIndieFilm
                : null,
            onPosted:
                _onItemPosted, // Uncomment when IndieFilmsScreen is updated
          ),
          PremieresScreen(
            userName: widget.userName,
            userEmail: widget.userEmail,
            existingPremiere: widget.existingItem is MarketplacePremiere
                ? widget.existingItem as MarketplacePremiere
                : null,
            onPosted:
                _onItemPosted, // Uncomment when PremieresScreen is updated
          ),
          FanEventsScreen(
            userName: widget.userName,
            userEmail: widget.userEmail,
            existingEvent: widget.existingItem is FanEvent
                ? widget.existingItem as FanEvent
                : null,
            onPosted:
                _onItemPosted, // Uncomment when FanEventsScreen is updated
          ),
        ],
      ),
    );
  }
}
