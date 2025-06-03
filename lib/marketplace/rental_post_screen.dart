import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'marketplace_item_model.dart';
import 'marketplace_item_db.dart';

class RentalPostScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final MarketplaceRental? existingRental;
  final VoidCallback? onPosted; // Added onPosted callback

  const RentalPostScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.existingRental,
    this.onPosted,
  });

  @override
  State<RentalPostScreen> createState() => _RentalPostScreenState();
}

class _RentalPostScreenState extends State<RentalPostScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _minDaysCtrl = TextEditingController();
  Uint8List? _imageBytes;
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.existingRental != null) {
      final rent = widget.existingRental!;
      _nameCtrl.text = rent.name;
      _descCtrl.text = rent.description;
      _priceCtrl.text = rent.pricePerDay.toString();
      _minDaysCtrl.text = rent.minDays.toString();
      _imageBytes =
          rent.imageBase64 != null ? base64Decode(rent.imageBase64!) : null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final p = await _picker.pickImage(source: source, maxWidth: 800);
      if (p != null) {
        if (kIsWeb) {
          final bytes = await p.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _imageFile = null;
          });
        } else {
          setState(() {
            _imageFile = File(p.path);
            _imageBytes = null;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty ||
        _descCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty ||
        _minDaysCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      final price =
          double.parse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''));
      final minDays = int.parse(_minDaysCtrl.text);
      if (price <= 0 || minDays <= 0) {
        throw Exception('Values must be greater than 0');
      }

      String? imageBase64;
      if (_imageBytes != null) {
        imageBase64 = base64Encode(_imageBytes!);
      } else if (_imageFile != null) {
        imageBase64 = base64Encode(await _imageFile!.readAsBytes());
      }

      final rental = MarketplaceRental(
        id: widget.existingRental?.id,
        name: _nameCtrl.text,
        description: _descCtrl.text,
        pricePerDay: price,
        minDays: minDays,
        imageBase64: imageBase64,
        sellerName: widget.userName,
        sellerEmail: widget.userEmail,
        isHidden: widget.existingRental?.isHidden ?? false,
      );

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => RentalReviewScreen(rental: rental)),
      );

      if (result == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Rental ${widget.existingRental != null ? 'updated' : 'posted'} successfully')),
        );
        widget.onPosted?.call(); // Call onPosted callback
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid input: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Colors.orangeAccent;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111927),
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.6),
          radius: 1.2,
          colors: [accent.withOpacity(0.2), Colors.transparent],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Post a Rental',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Rental Name',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accent),
                      ),
                    ),
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accent),
                      ),
                    ),
                    style: GoogleFonts.poppins(color: Colors.white),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Price Per Day
                  TextField(
                    controller: _priceCtrl,
                    decoration: InputDecoration(
                      labelText: 'Price per Day (\$)',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accent),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Minimum Days
                  TextField(
                    controller: _minDaysCtrl,
                    decoration: InputDecoration(
                      labelText: 'Minimum Rental Days',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accent),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Image Picker
                  GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.grey.shade900,
                        title: Text('Choose Image Source',
                            style: GoogleFonts.poppins(color: Colors.white)),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _pickImage(ImageSource.gallery);
                            },
                            child: Text('Gallery',
                                style:
                                    GoogleFonts.poppins(color: Colors.white)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _pickImage(ImageSource.camera);
                            },
                            child: Text('Camera',
                                style:
                                    GoogleFonts.poppins(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: _imageBytes != null
                          ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                          : _imageFile != null
                              ? Image.file(_imageFile!, fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    'Tap to add rental image',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70),
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _save,
                    child: Text(
                      widget.existingRental != null ? 'Update' : 'Save',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RentalReviewScreen extends StatelessWidget {
  final MarketplaceRental rental;

  const RentalReviewScreen({super.key, required this.rental});

  @override
  Widget build(BuildContext context) {
    const accent = Colors.orangeAccent;
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview Rental',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.black.withOpacity(0.8),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111927),
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.6),
            radius: 1.2,
            colors: [accent.withOpacity(0.2), Colors.transparent],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${rental.name}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Description: ${rental.description}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                        'Price/Day: \$${rental.pricePerDay.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Min Days: ${rental.minDays}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 16),
                    if (rental.imageBase64 != null)
                      SizedBox(
                        height: 150,
                        child: Image.memory(base64Decode(rental.imageBase64!),
                            fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        try {
                          if (rental.id != null) {
                            await MarketplaceItemDb.instance.update(rental);
                          } else {
                            await MarketplaceItemDb.instance.insert(rental);
                          }
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Save failed: $e')),
                            );
                          }
                        }
                      },
                      child: Text(
                        rental.id != null ? 'Update Rental' : 'Post Rental',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
