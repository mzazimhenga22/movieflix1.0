import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:movie_app/marketplace/models/indie_film.dart';
import 'package:movie_app/marketplace/marketplace_item_model.dart';
import 'package:movie_app/marketplace/marketplace_item_db.dart';

class IndieFilmsScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final IndieFilm? existingFilm;
  final VoidCallback? onPosted; // Added onPosted callback

  const IndieFilmsScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.existingFilm,
    this.onPosted,
  });

  @override
  State<IndieFilmsScreen> createState() => _IndieFilmsScreenState();
}

class _IndieFilmsScreenState extends State<IndieFilmsScreen> {
  final _titleCtrl = TextEditingController();
  final _synopsisCtrl = TextEditingController();
  final _fundingCtrl = TextEditingController();
  Uint8List? _videoBytes;
  File? _videoFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.existingFilm != null) {
      final film = widget.existingFilm!;
      _titleCtrl.text = film.title;
      _synopsisCtrl.text = film.synopsis;
      _fundingCtrl.text = film.fundingGoal.toString();
      _videoBytes =
          film.videoBase64.isNotEmpty ? base64Decode(film.videoBase64) : null;
    }
  }

  Future<void> _pickVideo() async {
    try {
      final p = await _picker.pickVideo(source: ImageSource.gallery);
      if (p != null) {
        if (kIsWeb) {
          final bytes = await p.readAsBytes();
          setState(() {
            _videoBytes = bytes;
            _videoFile = null;
          });
        } else {
          setState(() {
            _videoFile = File(p.path);
            _videoBytes = null;
          });
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick video: $e')),
        );
      }
    }
  }

  Future<void> _submitFilm() async {
    final currentContext = context;
    if (_titleCtrl.text.isEmpty ||
        _synopsisCtrl.text.isEmpty ||
        _fundingCtrl.text.isEmpty ||
        (_videoBytes == null && _videoFile == null)) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields')),
        );
      }
      return;
    }

    try {
      final funding =
          double.parse(_fundingCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (funding <= 0) {
        throw Exception('Funding goal must be greater than 0');
      }

      String videoBase64;
      if (_videoBytes != null) {
        videoBase64 = base64Encode(_videoBytes!);
      } else {
        videoBase64 = base64Encode(await _videoFile!.readAsBytes());
      }

      final film = MarketplaceIndieFilm(
        id: widget.existingFilm?.id,
        title: _titleCtrl.text,
        synopsis: _synopsisCtrl.text,
        fundingGoal: funding,
        videoBase64: videoBase64,
        creatorName: widget.userName,
        creatorEmail: widget.userEmail,
      );

      // Save to database
      if (widget.existingFilm != null) {
        await MarketplaceItemDb.instance.update(film);
      } else {
        await MarketplaceItemDb.instance.insert(film);
      }

      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text(
              'Film ${film.title} ${widget.existingFilm != null ? 'updated' : 'submitted'} successfully',
            ),
          ),
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
    const accent = Colors.blueAccent;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          gradient: LinearGradient(
            colors: [Colors.blueAccent.withOpacity(0.3), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submit Indie Film',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Film Title',
                        labelStyle: GoogleFonts.poppins(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: accent),
                        ),
                      ),
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _synopsisCtrl,
                      decoration: InputDecoration(
                        labelText: 'Synopsis',
                        labelStyle: GoogleFonts.poppins(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: accent),
                        ),
                      ),
                      style: GoogleFonts.poppins(color: Colors.white),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _fundingCtrl,
                      decoration: InputDecoration(
                        labelText: 'Funding Goal (\$)',
                        labelStyle: GoogleFonts.poppins(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: accent),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickVideo,
                      icon:
                          const Icon(Icons.video_library, color: Colors.white),
                      label: Text(
                        'Upload Trailer',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_videoBytes != null || _videoFile != null)
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: Center(
                          child: Text(
                            'Video Selected',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submitFilm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        widget.existingFilm != null
                            ? 'Update Film'
                            : 'Submit Film',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _synopsisCtrl.dispose();
    _fundingCtrl.dispose();
    super.dispose();
  }
}
