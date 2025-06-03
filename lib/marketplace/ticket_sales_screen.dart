import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'marketplace_item_db.dart';
import 'marketplace_item_model.dart';
import 'marketplace_post_screen.dart';
import 'ticket_details_screen.dart';
import 'checkout_screen.dart';
import 'package:movie_app/components/socialsection/chat_screen.dart';

class TicketSalesScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const TicketSalesScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<TicketSalesScreen> createState() => _TicketSalesScreenState();
}

class _TicketSalesScreenState extends State<TicketSalesScreen> {
  late Future<List<MarketplaceItem>> _ticketsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'trending';
  Map<int, int> _cart = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      developer.log('Reloading items', name: 'Database');
      _ticketsFuture = MarketplaceItemDb.instance.getAll();
    });
  }

  void _filterTickets(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _sortTickets(String sortBy) {
    setState(() {
      _sortBy = sortBy;
    });
  }

  void _addToCart(int itemId) async {
    setState(() {
      _cart[itemId] = (_cart[itemId] ?? 0) + 1;
      developer.log('Added item $itemId to cart', name: 'UserAction');
    });
    try {
      final items = await _ticketsFuture;
      final item = items.firstWhere((t) => t.id == itemId);
      if (item is MarketplaceTicket) {
        final updatedItem = item.copyWith(updates: {'isLocked': true});
        await MarketplaceItemDb.instance.update(updatedItem);
        developer.log('Item updated: Locked item $itemId', name: 'Database');
        _reload();
      }
    } catch (e) {
      developer.log('Error updating item $itemId: $e',
          name: 'Database', error: e);
    }
  }

  void _removeFromCart(int itemId) async {
    setState(() {
      if (_cart.containsKey(itemId) && _cart[itemId]! > 0) {
        _cart[itemId] = _cart[itemId]! - 1;
        if (_cart[itemId] == 0) _cart.remove(itemId);
        developer.log('Removed item $itemId from cart', name: 'UserAction');
      }
    });
    if (!_cart.containsKey(itemId)) {
      try {
        final items = await _ticketsFuture;
        final item = items.firstWhere((t) => t.id == itemId);
        if (item is MarketplaceTicket) {
          final updatedItem = item.copyWith(updates: {'isLocked': false});
          await MarketplaceItemDb.instance.update(updatedItem);
          developer.log('Item updated: Unlocked item $itemId',
              name: 'Database');
          _reload();
        }
      } catch (e) {
        developer.log('Error updating item $itemId: $e',
            name: 'Database', error: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Colors.blueAccent; // Fallback accent color

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Colors.black],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            _reload();
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: true,
                backgroundColor: Colors.black.withOpacity(0.8),
                title: Text(
                  'Trending',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    onPressed: () => _showFilterBottomSheet(context),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search movies...',
                      hintStyle:
                          GoogleFonts.poppins(color: Colors.grey.shade600),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white70),
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
                    onChanged: _filterTickets,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: FutureBuilder<List<MarketplaceItem>>(
                    future: _ticketsFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        developer.log('Error loading items: ${snap.error}',
                            name: 'Database', error: snap.error);
                        return Center(
                          child: Text(
                            'Error loading tickets',
                            style: GoogleFonts.poppins(
                                color: accent, fontSize: 16),
                          ),
                        );
                      }
                      final items = snap.data ?? [];
                      final filteredTickets = items
                          .where((item) =>
                              item is MarketplaceTicket &&
                              item.movieTitle
                                  .toLowerCase()
                                  .contains(_searchQuery))
                          .cast<MarketplaceTicket>()
                          .toList();

                      if (_sortBy == 'price_asc') {
                        filteredTickets
                            .sort((a, b) => a.price.compareTo(b.price));
                      } else if (_sortBy == 'price_desc') {
                        filteredTickets
                            .sort((a, b) => b.price.compareTo(a.price));
                      }

                      if (filteredTickets.isEmpty) {
                        return Center(
                          child: Text(
                            'No tickets found',
                            style: GoogleFonts.poppins(
                                color: accent, fontSize: 16),
                          ),
                        );
                      }

                      return SizedBox(
                        height: 350,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredTickets.length,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemBuilder: (context, i) {
                            final t = filteredTickets[i];
                            return _TicketCard(
                              ticket: t,
                              accent: accent,
                              cartQuantity: _cart[t.id!] ?? 0,
                              onAddToCart: () => _addToCart(t.id!),
                              onRemoveFromCart: () => _removeFromCart(t.id!),
                              onMessage: () => _showMessageDialog(context, t),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            backgroundColor: accent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () async {
              developer.log('Navigating to MarketplacePostScreen',
                  name: 'Navigation');
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => MarketplacePostScreen(
                    userName: widget.userName,
                    userEmail: widget.userEmail,
                  ),
                ),
              );
              if (created == true) {
                _reload();
              }
            },
            child: const Icon(Icons.add, size: 28, color: Colors.white),
          ),
          if (_cart.isNotEmpty) ...[
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              backgroundColor: accent,
              onPressed: () async {
                developer.log('Navigating to CheckoutScreen',
                    name: 'Navigation');
                final currentContext = context; // Store context before async
                final itemsList = (await _ticketsFuture)
                    .where((t) =>
                        _cart.containsKey(t.id!) && t is MarketplaceTicket)
                    .cast<MarketplaceTicket>()
                    .toList();
                if (currentContext.mounted) {
                  Navigator.push(
                    currentContext,
                    MaterialPageRoute(
                      builder: (_) => CheckoutScreen(
                        cart: _cart,
                        tickets: itemsList,
                      ),
                    ),
                  );
                }
              },
              label: Text(
                'Proceed to Checkout',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('Trending',
                style: GoogleFonts.poppins(color: Colors.white)),
            onTap: () {
              _sortTickets('trending');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('Price: Low to High',
                style: GoogleFonts.poppins(color: Colors.white)),
            onTap: () {
              _sortTickets('price_asc');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('Price: High to Low',
                style: GoogleFonts.poppins(color: Colors.white)),
            onTap: () {
              _sortTickets('price_desc');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showMessageDialog(BuildContext context, MarketplaceTicket ticket) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text('Contact Seller',
            style: GoogleFonts.poppins(color: Colors.white)),
        content: Text(
          'Start a chat with the seller (${ticket.sellerName ?? 'Seller'}) about this ticket?',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              developer.log(
                  'Navigating to IndividualChatScreen for ticket ${ticket.id}',
                  name: 'Navigation');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IndividualChatScreen(
                    currentUser: {
                      'id': widget.userEmail, // Using email as a unique ID
                      'username': widget.userName,
                    },
                    otherUser: {
                      'id': ticket.sellerEmail ?? 'seller@example.com',
                      'username': ticket.sellerName ?? 'Seller',
                    },
                  ),
                ),
              );
            },
            child:
                Text('Chat', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final MarketplaceTicket ticket;
  final Color accent;
  final int cartQuantity;
  final VoidCallback onAddToCart;
  final VoidCallback onRemoveFromCart;
  final VoidCallback onMessage;

  const _TicketCard({
    required this.ticket,
    required this.accent,
    required this.cartQuantity,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isAddDisabled = ticket.isLocked && cartQuantity == 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketDetailsScreen(ticket: ticket),
          ),
        );
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: ticket.imageBase64 != null
                    ? Image.memory(
                        base64Decode(ticket.imageBase64!),
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        ticket.moviePoster,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade800,
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.movieTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Genre: Thriller',
                            style: GoogleFonts.poppins(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed:
                                        isAddDisabled ? null : onAddToCart,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isAddDisabled ? Colors.grey : accent,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                    child: const Icon(Icons.add, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$cartQuantity',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  if (cartQuantity > 0)
                                    ElevatedButton(
                                      onPressed: onRemoveFromCart,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade700,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      child: const Icon(Icons.remove, size: 16),
                                    ),
                                ],
                              ),
                              IconButton(
                                onPressed: onMessage,
                                icon: const Icon(Icons.message,
                                    color: Colors.white),
                                tooltip: 'Message Seller',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
