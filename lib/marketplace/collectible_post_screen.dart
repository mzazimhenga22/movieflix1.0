import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'marketplace_item_model.dart';
import 'marketplace_item_db.dart';

class CollectiblePostScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final MarketplaceCollectible? existingCollectible;
  final VoidCallback? onPosted; // Added onPosted callback

  const CollectiblePostScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.existingCollectible,
    this.onPosted,
  });

  @override
  State<CollectiblePostScreen> createState() => _CollectiblePostScreenState();
}

class _CollectiblePostScreenState extends State<CollectiblePostScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  Uint8List? _imageBytes;
  File? _imageFile;
  Uint8List? _docBytes;
  String? _docFileName;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.existingCollectible != null) {
      final collectible = widget.existingCollectible!;
      _nameCtrl.text = collectible.name;
      _descCtrl.text = collectible.description;
      _priceCtrl.text = collectible.price.toString();
      _imageBytes = collectible.imageBase64 != null
          ? base64Decode(collectible.imageBase64!)
          : null;
      _docBytes = collectible.authenticityDocBase64 != null
          ? base64Decode(collectible.authenticityDocBase64!)
          : null;
      _docFileName =
          collectible.authenticityDocBase64 != null ? 'authenticity_doc' : null;
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickDocFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _docBytes = result.files.single.bytes;
          _docFileName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick document: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    final currentContext = context;
    if (_nameCtrl.text.isEmpty ||
        _descCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields')),
        );
      }
      return;
    }

    try {
      final priceText = _priceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '');
      final price = double.tryParse(priceText);
      if (price == null || price <= 0) {
        throw Exception('Price must be a valid number greater than 0');
      }

      String? imageBase64;
      if (_imageBytes != null) {
        imageBase64 = base64Encode(_imageBytes!);
      } else if (_imageFile != null) {
        imageBase64 = base64Encode(await _imageFile!.readAsBytes());
      }

      String? docBase64;
      if (_docBytes != null) {
        docBase64 = base64Encode(_docBytes!);
      }

      final collectible = MarketplaceCollectible(
        id: widget.existingCollectible?.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: price,
        imageBase64: imageBase64,
        authenticityDocBase64: docBase64,
        sellerName: widget.userName,
        sellerEmail: widget.userEmail,
        isHidden: widget.existingCollectible?.isHidden ?? false,
      );

      final result = await Navigator.push<bool>(
        currentContext,
        MaterialPageRoute(
            builder: (_) => CollectibleReviewScreen(collectible: collectible)),
      );

      if (result == true && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
              content: Text(
                  'Collectible ${widget.existingCollectible != null ? 'updated' : 'posted'} successfully')),
        );
        widget.onPosted?.call(); // Call onPosted callback
        Navigator.pop(currentContext, true);
      }
    } catch (e) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Invalid input: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Colors.purpleAccent;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Post a Collectible',
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
        decoration: BoxDecoration(
          color: const Color(0xFF111927),
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.6),
            radius: 1.2,
            colors: [Colors.purpleAccent.withOpacity(0.2), Colors.transparent],
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
                      'Post a Collectible',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Collectible Name',
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
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _priceCtrl,
                      decoration: InputDecoration(
                        labelText: 'Price',
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
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: Colors.grey.shade900,
                            title: Text('Choose Image Source',
                                style:
                                    GoogleFonts.poppins(color: Colors.white)),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _pickImage(ImageSource.gallery);
                                },
                                child: Text('Gallery',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white)),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _pickImage(ImageSource.camera);
                                },
                                child: Text('Camera',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
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
                                      'Tap to add collectible image',
                                      style: GoogleFonts.poppins(
                                          color: Colors.white70),
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickDocFile,
                      child: Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.white.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: Center(
                          child: Text(
                            _docFileName != null
                                ? 'File: $_docFileName'
                                : 'Tap to upload authenticity document',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                color: _docFileName != null
                                    ? Colors.white
                                    : Colors.white70),
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
                        widget.existingCollectible != null ? 'Update' : 'Save',
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

class CollectibleReviewScreen extends StatelessWidget {
  final MarketplaceCollectible collectible;

  const CollectibleReviewScreen({super.key, required this.collectible});

  @override
  Widget build(BuildContext context) {
    const accent = Colors.purpleAccent;
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview Collectible',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111927),
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.6),
            radius: 1.2,
            colors: [Colors.purpleAccent.withOpacity(0.2), Colors.transparent],
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
                    Text('Name: ${collectible.name}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Description: ${collectible.description}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Price: \$${collectible.price.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 16),
                    if (collectible.imageBase64 != null)
                      SizedBox(
                        height: 150,
                        child: Image.memory(
                            base64Decode(collectible.imageBase64!),
                            fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 16),
                    if (collectible.authenticityDocBase64 != null)
                      Text('Authenticity Document: (File attached)',
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.white70)),
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
                        final currentContext = context;
                        try {
                          if (collectible.id != null) {
                            await MarketplaceItemDb.instance
                                .update(collectible);
                          } else {
                            await MarketplaceItemDb.instance
                                .insert(collectible);
                          }
                          if (currentContext.mounted) {
                            Navigator.pop(currentContext, true);
                          }
                        } catch (e) {
                          if (currentContext.mounted) {
                            ScaffoldMessenger.of(currentContext).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Failed to save collectible: $e')),
                            );
                          }
                        }
                      },
                      child: Text(
                        collectible.id != null
                            ? 'Update Collectible'
                            : 'Post Collectible',
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
