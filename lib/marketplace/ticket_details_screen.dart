import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'marketplace_item_model.dart';

class TicketDetailsScreen extends StatelessWidget {
  final MarketplaceTicket ticket;

  const TicketDetailsScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    const accent = Colors.blueAccent; // Fallback accent color

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ticket.movieTitle,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: ticket.imageBase64 != null
                      ? MemoryImage(base64Decode(ticket.imageBase64!))
                      : NetworkImage(ticket.moviePoster) as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.movieTitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.monetization_on, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Price: \$${ticket.price.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(color: accent, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Location: ${ticket.location}',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.date_range, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Date: ${DateTime.parse(ticket.date).toLocal().toString().split('.')[0]}',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.event_seat, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Seats: ${ticket.seats}',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Seat Details: ${ticket.seatDetails ?? "Not specified"}',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Genre: Thriller',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SeatSelectionWidget(
              onSeatsSelected: print,
            ),
          ],
        ),
      ),
    );
  }
}

class SeatSelectionWidget extends StatefulWidget {
  final Function(List<String>) onSeatsSelected;

  const SeatSelectionWidget({super.key, required this.onSeatsSelected});

  @override
  State<SeatSelectionWidget> createState() => _SeatSelectionWidgetState();
}

class _SeatSelectionWidgetState extends State<SeatSelectionWidget> {
  final List<List<bool>> _seats = List.generate(
    5,
    (_) => List.generate(8, (_) => false),
  );
  final List<String> _selectedSeats = [];

  void _toggleSeat(int row, int col) {
    setState(() {
      _seats[row][col] = !_seats[row][col];
      final seat = '${String.fromCharCode(65 + row)}${col + 1}';
      if (_seats[row][col]) {
        _selectedSeats.add(seat);
      } else {
        _selectedSeats.remove(seat);
      }
      widget.onSeatsSelected(_selectedSeats);
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = Colors.blueAccent; // Fallback accent color

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Your Seats',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 50,
            color: Colors.grey.shade800,
            child: Center(
              child: Text(
                'SCREEN',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: 40,
            itemBuilder: (context, index) {
              final row = index ~/ 8;
              final col = index % 8;
              return GestureDetector(
                onTap: () => _toggleSeat(row, col),
                child: Container(
                  decoration: BoxDecoration(
                    color: _seats[row][col] ? accent : Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${String.fromCharCode(65 + row)}${col + 1}',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Selected Seats: ${_selectedSeats.join(", ")}',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
