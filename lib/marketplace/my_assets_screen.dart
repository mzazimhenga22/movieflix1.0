import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'marketplace_item_model.dart';
import 'marketplace_item_db.dart';
import 'marketplace_post_screen.dart';

class MyAssetsScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String? userAvatar;

  MyAssetsScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.userAvatar,
  });

  @override
  State<MyAssetsScreen> createState() => _MyAssetsScreenState();
}

class _MyAssetsScreenState extends State<MyAssetsScreen> {
  List<MarketplaceItem> _posts = [];
  bool _isLoading = false;

  String _country = 'United States';
  String _city = 'New York';
  String _paymentMethod = 'Credit Card';
  String _currency = 'USD';
  bool _emailNotifications = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final posts =
          await MarketplaceItemDb.instance.getBySeller(widget.userEmail);
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: $e')),
        );
      }
    }
  }

  Future<void> _toggleVisibility(MarketplaceItem item) async {
    final updatedItem =
        item.copyWith(updates: {'isHidden': item.isHidden ? 0 : 1});
    try {
      await MarketplaceItemDb.instance.update(updatedItem);
      setState(() {
        _posts = _posts.map((p) => p.id == item.id ? updatedItem : p).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(item.isHidden ? 'Post shown' : 'Post hidden')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update visibility: $e')),
        );
      }
    }
  }

  Future<void> _deletePost(MarketplaceItem item) async {
    try {
      await MarketplaceItemDb.instance.delete(item.id!);
      setState(() {
        _posts = _posts.where((p) => p.id != item.id).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
    }
  }

  Future<void> _updatePost(MarketplaceItem item) async {
    final currentContext = context;
    final updated = await Navigator.push<bool>(
      currentContext,
      MaterialPageRoute(
        builder: (_) => MarketplacePostScreen(
          userName: widget.userName,
          userEmail: widget.userEmail,
          existingItem: item,
        ),
      ),
    );
    if (updated == true && currentContext.mounted) {
      await _fetchPosts();
    }
  }

  void _saveSettings() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Colors.blueAccent;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'My Assets',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111927),
          gradient: RadialGradient(
            center: Alignment(0.0, -0.6),
            radius: 1.2,
            colors: [Color.fromRGBO(0, 255, 191, 0.2), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                            child: Text(
                              widget.userName,
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: widget.userAvatar != null &&
                                        widget.userAvatar!.isNotEmpty &&
                                        Uri.tryParse(widget.userAvatar!)
                                                ?.hasAbsolutePath ==
                                            true
                                    ? NetworkImage(widget.userAvatar!)
                                    : null,
                                child: widget.userAvatar == null ||
                                        widget.userAvatar!.isEmpty ||
                                        Uri.tryParse(widget.userAvatar!)
                                                ?.hasAbsolutePath !=
                                            true
                                    ? const Icon(Icons.person,
                                        color: Colors.white, size: 30)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.userName,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    widget.userEmail,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Settings',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _country,
                                decoration: InputDecoration(
                                  labelText: 'Country',
                                  labelStyle: GoogleFonts.poppins(
                                      color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.grey.shade900,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: GoogleFonts.poppins(color: Colors.white),
                                dropdownColor: Colors.grey.shade900,
                                items: [
                                  'United States',
                                  'Canada',
                                  'United Kingdom',
                                  'Australia'
                                ]
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _country = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _city,
                                decoration: InputDecoration(
                                  labelText: 'City',
                                  labelStyle: GoogleFonts.poppins(
                                      color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.grey.shade900,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: GoogleFonts.poppins(color: Colors.white),
                                dropdownColor: Colors.grey.shade900,
                                items: [
                                  'New York',
                                  'Toronto',
                                  'London',
                                  'Sydney'
                                ]
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _city = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _paymentMethod,
                                decoration: InputDecoration(
                                  labelText: 'Payment Method',
                                  labelStyle: GoogleFonts.poppins(
                                      color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.grey.shade900,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: GoogleFonts.poppins(color: Colors.white),
                                dropdownColor: Colors.grey.shade900,
                                items: ['Credit Card', 'PayPal', 'Crypto']
                                    .map((p) => DropdownMenuItem(
                                        value: p, child: Text(p)))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _paymentMethod = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _currency,
                                decoration: InputDecoration(
                                  labelText: 'Currency',
                                  labelStyle: GoogleFonts.poppins(
                                      color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.grey.shade900,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: GoogleFonts.poppins(color: Colors.white),
                                dropdownColor: Colors.grey.shade900,
                                items: ['USD', 'EUR', 'GBP', 'AUD']
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _currency = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                title: Text(
                                  'Email Notifications',
                                  style:
                                      GoogleFonts.poppins(color: Colors.white),
                                ),
                                value: _emailNotifications,
                                activeColor: accent,
                                onChanged: (value) {
                                  setState(() {
                                    _emailNotifications = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _saveSettings,
                                child: Text(
                                  'Save Settings',
                                  style:
                                      GoogleFonts.poppins(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Posts',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.blueAccent))
                                  : _posts.isEmpty
                                      ? Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color.fromARGB(
                                                160, 17, 25, 40),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.12)),
                                          ),
                                          child: Text(
                                            'No posts available yet',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white70,
                                              fontSize: 16,
                                            ),
                                          ),
                                        )
                                      : GridView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            mainAxisSpacing: 12,
                                            crossAxisSpacing: 12,
                                            childAspectRatio: 0.75,
                                          ),
                                          itemCount: _posts.length,
                                          itemBuilder: (context, index) {
                                            final post = _posts[index];
                                            return _PostCard(
                                              post: post,
                                              accent: accent,
                                              onToggleVisibility: () =>
                                                  _toggleVisibility(post),
                                              onDelete: () => _deletePost(post),
                                              onUpdate: () => _updatePost(post),
                                            );
                                          },
                                        ),
                            ],
                          ),
                        ),
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
}

class _PostCard extends StatelessWidget {
  final MarketplaceItem post;
  final Color accent;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  const _PostCard({
    required this.post,
    required this.accent,
    required this.onToggleVisibility,
    required this.onDelete,
    required this.onUpdate,
  });

  // Helper to get display title
  String _getTitle() {
    if (post is MarketplaceTicket) {
      return (post as MarketplaceTicket).movieTitle;
    } else if (post is MarketplacePremiere) {
      return (post as MarketplacePremiere).movieTitle;
    } else if (post is MarketplaceCollectible) {
      return (post as MarketplaceCollectible).name;
    } else if (post is MarketplaceAuction) {
      return (post as MarketplaceAuction).name;
    } else if (post is MarketplaceRental) {
      return (post as MarketplaceRental).name;
    } else if (post is MarketplaceIndieFilm) {
      return (post as MarketplaceIndieFilm).title;
    }
    return 'Untitled';
  }

  // Helper to get display price
  String _getPrice() {
    if (post is MarketplaceTicket) {
      return '\$${(post as MarketplaceTicket).price.toStringAsFixed(2)}';
    } else if (post is MarketplaceCollectible) {
      return '\$${(post as MarketplaceCollectible).price.toStringAsFixed(2)}';
    } else if (post is MarketplaceAuction) {
      return '\$${(post as MarketplaceAuction).startingPrice.toStringAsFixed(2)}';
    } else if (post is MarketplaceRental) {
      return '\$${(post as MarketplaceRental).pricePerDay.toStringAsFixed(2)}/day';
    } else if (post is MarketplaceIndieFilm) {
      return 'Goal: \$${(post as MarketplaceIndieFilm).fundingGoal.toStringAsFixed(2)}';
    } else if (post is MarketplacePremiere) {
      return 'N/A'; // Premiere does not have a price
    }
    return 'N/A';
  }

  // Helper to get image source
  Widget _getImage() {
    String? imageBase64;
    String? fallbackUrl;

    if (post is MarketplaceTicket) {
      imageBase64 = (post as MarketplaceTicket).imageBase64;
      fallbackUrl = (post as MarketplaceTicket).moviePoster;
    } else if (post is MarketplaceCollectible) {
      imageBase64 = (post as MarketplaceCollectible).imageBase64;
    } else if (post is MarketplaceAuction) {
      imageBase64 = (post as MarketplaceAuction).imageBase64;
    } else if (post is MarketplaceRental) {
      imageBase64 = (post as MarketplaceRental).imageBase64;
    }
    // MarketplacePremiere and MarketplaceIndieFilm do not have imageBase64 or moviePoster

    if (imageBase64 != null) {
      try {
        return Image.memory(
          base64Decode(imageBase64),
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 120,
            color: Colors.grey.shade800,
            child: const Icon(Icons.image_not_supported, color: Colors.white70),
          ),
        );
      } catch (e) {
        // Fallback to network image or placeholder
      }
    }

    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      return Image.network(
        fallbackUrl,
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: Colors.grey.shade800,
          child: const Icon(Icons.image_not_supported, color: Colors.white70),
        ),
      );
    }

    return Container(
      height: 120,
      color: Colors.grey.shade800,
      child: const Icon(Icons.image_not_supported, color: Colors.white70),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: _getImage(),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitle(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getPrice(),
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
                    IconButton(
                      icon: Icon(
                        post.isHidden ? Icons.visibility_off : Icons.visibility,
                        color: accent,
                        size: 20,
                      ),
                      onPressed: onToggleVisibility,
                      tooltip: post.isHidden ? 'Show Post' : 'Hide Post',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.white70, size: 20),
                      onPressed: onUpdate,
                      tooltip: 'Edit Post',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete,
                          color: Colors.redAccent, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: Colors.grey.shade900,
                            title: Text(
                              'Delete Post',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                            content: Text(
                              'Are you sure you want to delete this post?',
                              style: GoogleFonts.poppins(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Cancel',
                                  style:
                                      GoogleFonts.poppins(color: Colors.white),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  onDelete();
                                },
                                child: Text(
                                  'Delete',
                                  style: GoogleFonts.poppins(
                                      color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      tooltip: 'Delete Post',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
