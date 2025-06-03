class Listing {
  final String title;
  final String imageUrl;
  final double price;
  final bool isAuction;
  final String timeRemaining;
  final bool isSaved;
  final String sellerName;
  final String sellerAvatarUrl;
  final double rating;
  final String? sellerEmail; // Added for consistency

  Listing({
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.isAuction,
    required this.timeRemaining,
    required this.isSaved,
    required this.sellerName,
    required this.sellerAvatarUrl,
    required this.rating,
    this.sellerEmail,
  });

  static List<Listing> sampleData() {
    return [
      Listing(
        title: 'Vintage Movie Poster',
        imageUrl: 'https://example.com/poster1.jpg',
        price: 49.99,
        isAuction: false,
        timeRemaining: '',
        isSaved: false,
        sellerName: 'John Doe',
        sellerAvatarUrl: 'https://example.com/avatar1.jpg',
        rating: 4.5,
        sellerEmail: 'john.doe@example.com',
      ),
      Listing(
        title: 'Rare Collectible Reel',
        imageUrl: 'https://example.com/reel1.jpg',
        price: 299.99,
        isAuction: true,
        timeRemaining: '2h 30m',
        isSaved: true,
        sellerName: 'Jane Smith',
        sellerAvatarUrl: 'https://example.com/avatar2.jpg',
        rating: 4.8,
        sellerEmail: 'jane.smith@example.com',
      ),
      // Add more sample listings as needed
    ];
  }
}
