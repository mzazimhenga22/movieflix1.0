import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movie_app/marketplace/marketplace_item_model.dart';
import 'package:movie_app/marketplace/marketplace_item_db.dart'; // Import MarketplaceItemDb

class Premiere {
  final String? id;
  final String movieTitle;
  final String location;
  final DateTime date;
  final String organizerName;
  final String organizerEmail;

  Premiere({
    this.id,
    required this.movieTitle,
    required this.location,
    required this.date,
    required this.organizerName,
    required this.organizerEmail,
  });
}

class PremieresScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final Premiere? existingPremiere;

  const PremieresScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.existingPremiere,
  });

  @override
  State<PremieresScreen> createState() => _PremieresScreenState();
}

class _PremieresScreenState extends State<PremieresScreen> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  DateTime? _premiereDate;

  @override
  void initState() {
    super.initState();
    if (widget.existingPremiere != null) {
      final premiere = widget.existingPremiere!;
      _titleCtrl.text = premiere.movieTitle;
      _locationCtrl.text = premiere.location;
      _premiereDate = premiere.date;
    }
  }

  Future<void> _selectDate() async {
    final currentContext = context;
    final date = await showDatePicker(
      context: currentContext,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (date != null && currentContext.mounted) {
      setState(() {
        _premiereDate = date;
      });
    }
  }

  Future<void> _createPremiere() async {
    final currentContext = context;
    if (_titleCtrl.text.isEmpty ||
        _locationCtrl.text.isEmpty ||
        _premiereDate == null) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields')),
        );
      }
      return;
    }

    try {
      if (_premiereDate!.isBefore(DateTime.now())) {
        throw Exception('Premiere date must be in the future');
      }

      final premiere = Premiere(
        id: widget.existingPremiere?.id,
        movieTitle: _titleCtrl.text,
        location: _locationCtrl.text,
        date: _premiereDate!,
        organizerName: widget.userName,
        organizerEmail: widget.userEmail,
      );

      // Simulate DB save
      // await PremiereDB().savePremiere(premiere);

      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
              content: Text(
                  'Premiere ${widget.existingPremiere != null ? 'updated' : 'created'} successfully')),
        );
        Navigator.pop(currentContext, true);
      }
    } catch (e) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Colors.redAccent;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'assets/cinema_background.jpg'), // Placeholder for background
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.6), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Premiere',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Movie Title',
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _locationCtrl,
                  decoration: InputDecoration(
                    labelText: 'Location (e.g., Theater Name, City)',
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      _premiereDate == null
                          ? 'Select Premiere Date'
                          : 'Date: ${_premiereDate!.toLocal().toString().split(' ')[0]}',
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _createPremiere,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                    widget.existingPremiere != null
                        ? 'Update Premiere'
                        : 'Create Premiere',
                    style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }
}
