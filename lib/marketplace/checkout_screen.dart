import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'marketplace_item_model.dart';
import 'marketplace_item_db.dart';

class CheckoutScreen extends StatelessWidget {
  final Map<int, int> cart;
  final List<MarketplaceTicket> tickets;

  const CheckoutScreen({super.key, required this.cart, required this.tickets});

  @override
  Widget build(BuildContext context) {
    const accent = Colors.blueAccent; // Fallback accent color
    double total = 0;
    for (var ticket in tickets) {
      total += ticket.price * (cart[ticket.id!] ?? 0);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  final quantity = cart[ticket.id!] ?? 0;
                  return Card(
                    color: Colors.grey.shade900,
                    child: ListTile(
                      leading: ticket.imageBase64 != null
                          ? Image.memory(
                              base64Decode(ticket.imageBase64!),
                              width: 50,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              ticket.moviePoster,
                              width: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.movie),
                            ),
                      title: Text(
                        ticket.movieTitle,
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Quantity: $quantity | Price: \$${ticket.price.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.grey),
            Text(
              'Total: \$${total.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                color: accent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TicketConfirmationScreen(
                        tickets: tickets,
                        cart: cart,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  'Confirm Purchase',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TicketConfirmationScreen extends StatelessWidget {
  final List<MarketplaceTicket> tickets;
  final Map<int, int> cart;

  const TicketConfirmationScreen({
    super.key,
    required this.tickets,
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Colors.blueAccent; // Fallback accent color

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ticket Confirmation',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Purchase Successful!',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  final quantity = cart[ticket.id!] ?? 0;
                  return Card(
                    color: Colors.grey.shade900,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.movieTitle,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Location: ${ticket.location}',
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            'Date: ${DateTime.parse(ticket.date).toLocal().toString().split('.')[0]}',
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            'Seats: ${ticket.seatDetails ?? ticket.seats.toString()}',
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            'Quantity: $quantity',
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          if (ticket.imageBase64 != null)
                            Image.memory(
                              base64Decode(ticket.imageBase64!),
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final currentContext = context; // Store context before async
                  for (var ticket in tickets) {
                    ticket.isLocked = false;
                    await MarketplaceItemDb.instance.update(ticket);
                  }
                  if (currentContext.mounted) {
                    Navigator.popUntil(
                        currentContext, (route) => route.isFirst);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  'Back to Home',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
