import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'marketplace_item_model.dart';
import 'marketplace_item_db.dart';

class AuctionPostScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final MarketplaceAuction? existingAuction;
  final VoidCallback? onPosted; // Added onPosted callback

  const AuctionPostScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.existingAuction,
    this.onPosted,
  });

  @override
  State<AuctionPostScreen> createState() => _AuctionPostScreenState();
}

class _AuctionPostScreenState extends State<AuctionPostScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _startPriceCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();
  Uint8List? _imageBytes;
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.existingAuction != null) {
      final a = widget.existingAuction!;
      _nameCtrl.text = a.name;
      _descCtrl.text = a.description;
      _startPriceCtrl.text = a.startingPrice.toString();
      _endDateCtrl.text = a.endDate;
      _imageBytes = a.imageBase64 != null ? base64Decode(a.imageBase64!) : null;
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

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.existingAuction != null
          ? DateTime.tryParse(widget.existingAuction!.endDate) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      _endDateCtrl.text = picked.toIso8601String();
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty ||
        _descCtrl.text.isEmpty ||
        _startPriceCtrl.text.isEmpty ||
        _endDateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    try {
      final startPrice =
          double.parse(_startPriceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (startPrice <= 0) throw Exception('Starting price must be > 0');

      String? imageBase64;
      if (_imageBytes != null) {
        imageBase64 = base64Encode(_imageBytes!);
      } else if (_imageFile != null) {
        imageBase64 = base64Encode(await _imageFile!.readAsBytes());
      }

      final auction = MarketplaceAuction(
        id: widget.existingAuction?.id,
        name: _nameCtrl.text,
        description: _descCtrl.text,
        startingPrice: startPrice,
        endDate: _endDateCtrl.text,
        imageBase64: imageBase64,
        sellerName: widget.userName,
        sellerEmail: widget.userEmail,
        isHidden: widget.existingAuction?.isHidden ?? false,
      );

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => AuctionReviewScreen(auction: auction)),
      );
      if (result == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Auction ${widget.existingAuction != null ? 'updated' : 'posted'} successfully'),
          ),
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
    const accent = Colors.greenAccent;
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
                  Text('Post an Auction',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Auction Name',
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startPriceCtrl,
                          decoration: InputDecoration(
                            labelText: 'Starting Price (\$)',
                            labelStyle:
                                GoogleFonts.poppins(color: Colors.white70),
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
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectEndDate,
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _endDateCtrl,
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                labelStyle:
                                    GoogleFonts.poppins(color: Colors.white70),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                                    'Tap to add auction image',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70),
                                  ),
                                ),
                    ),
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
                    onPressed: _save,
                    child: Text(
                      widget.existingAuction != null ? 'Update' : 'Save',
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

class AuctionReviewScreen extends StatelessWidget {
  final MarketplaceAuction auction;

  const AuctionReviewScreen({super.key, required this.auction});

  @override
  Widget build(BuildContext context) {
    const accent = Colors.greenAccent;
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview Auction',
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
                    Text('Name: ${auction.name}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Description: ${auction.description}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                        'Starting Price: \$${auction.startingPrice.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('End Date: ${auction.endDate}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 16),
                    if (auction.imageBase64 != null)
                      SizedBox(
                        height: 150,
                        child: Image.memory(
                          base64Decode(auction.imageBase64!),
                          fit: BoxFit.cover,
                        ),
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
                          if (auction.id != null) {
                            await MarketplaceItemDb.instance.update(auction);
                          } else {
                            await MarketplaceItemDb.instance.insert(auction);
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
                        auction.id != null ? 'Update Auction' : 'Post Auction',
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
