import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'marketplace_item_model.dart';
import 'marketplace_item_db.dart';

class TicketPostScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final MarketplaceTicket? existingTicket;
  final VoidCallback? onPosted; // Added onPosted callback

  const TicketPostScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.existingTicket,
    this.onPosted,
  });

  @override
  State<TicketPostScreen> createState() => _TicketPostScreenState();
}

class _TicketPostScreenState extends State<TicketPostScreen> {
  final _locCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController();
  final _seatDetailsCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Uint8List? _imageBytes;
  File? _imageFile;
  Uint8List? _ticketFileBytes;
  String? _ticketFileName;
  Map<String, dynamic>? _selMovie;
  final _picker = ImagePicker();
  final String _apiKey = '1ba41bda48d0f1c90954f4811637b6d6';

  @override
  void initState() {
    super.initState();
    if (widget.existingTicket != null) {
      final ticket = widget.existingTicket!;
      _locCtrl.text = ticket.location;
      _priceCtrl.text = ticket.price.toString();
      _seatsCtrl.text = ticket.seats.toString();
      _seatDetailsCtrl.text = ticket.seatDetails ?? '';
      _selectedDate = DateTime.parse(ticket.date);
      _selectedTime = TimeOfDay.fromDateTime(DateTime.parse(ticket.date));
      _imageBytes =
          ticket.imageBase64 != null ? base64Decode(ticket.imageBase64!) : null;
      _ticketFileBytes = ticket.ticketFileBase64 != null
          ? base64Decode(ticket.ticketFileBase64!)
          : null;
      _ticketFileName = ticket.ticketFileBase64 != null ? 'ticket_file' : null;
      _selMovie = {
        'id': ticket.movieId,
        'title': ticket.movieTitle,
        'poster_path': ticket.moviePoster
            .replaceFirst('https://image.tmdb.org/t/p/w300', ''),
      };
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
    } catch (e) {}
  }

  Future<void> _pickTicketFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _ticketFileBytes = result.files.single.bytes;
          _ticketFileName = result.files.single.name;
        });
      }
    } catch (e) {}
  }

  Future<void> _save() async {
    final currentContext = context;
    if (_selMovie == null ||
        _locCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null ||
        _seatsCtrl.text.isEmpty) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields')),
        );
      }
      return;
    }

    try {
      final price =
          double.parse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''));
      final seats = int.parse(_seatsCtrl.text.trim());
      if (price <= 0 || seats <= 0) {
        throw Exception('Price and seats must be greater than 0');
      }

      final dateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      String? imageBase64;
      if (_imageBytes != null) {
        imageBase64 = base64Encode(_imageBytes!);
      } else if (_imageFile != null) {
        imageBase64 = base64Encode(await _imageFile!.readAsBytes());
      }

      String? ticketFileBase64;
      if (_ticketFileBytes != null) {
        ticketFileBase64 = base64Encode(_ticketFileBytes!);
      }

      final ticket = MarketplaceTicket(
        id: widget.existingTicket?.id,
        movieId: _selMovie!['id'],
        movieTitle: _selMovie!['title'],
        moviePoster:
            'https://image.tmdb.org/t/p/w300${_selMovie!['poster_path']}',
        location: _locCtrl.text,
        price: price,
        date: dateTime.toIso8601String(),
        seats: seats,
        imageBase64: imageBase64,
        seatDetails:
            _seatDetailsCtrl.text.isNotEmpty ? _seatDetailsCtrl.text : null,
        ticketFileBase64: ticketFileBase64,
        isLocked: widget.existingTicket?.isLocked ?? false,
        sellerName: widget.userName,
        sellerEmail: widget.userEmail,
        isHidden: widget.existingTicket?.isHidden ?? false,
      );

      final result = await Navigator.push<bool>(
        currentContext,
        MaterialPageRoute(builder: (_) => TicketReviewScreen(ticket: ticket)),
      );

      if (result == true && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
              content: Text(
                  'Ticket ${widget.existingTicket != null ? 'updated' : 'posted'} successfully')),
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

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF111927),
        gradient: RadialGradient(
          center: Alignment(0.0, -0.6),
          radius: 1.2,
          colors: [Colors.blueAccent.withOpacity(0.2), Colors.transparent],
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
                    'Post a Movie Ticket',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selMovie != null
                              ? _selMovie!['title']
                              : 'No movie selected',
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.white),
                        ),
                      ),
                      ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(backgroundColor: accent),
                        onPressed: () async {
                          final currentContext = context;
                          final selectedMovie = await Navigator.push(
                            currentContext,
                            MaterialPageRoute(
                                builder: (_) =>
                                    MovieSelectionScreen(apiKey: _apiKey)),
                          );
                          if (selectedMovie != null && currentContext.mounted) {
                            setState(() {
                              _selMovie = selectedMovie;
                            });
                          }
                        },
                        child: Text(
                          _selMovie != null ? 'Change Movie' : 'Select Movie',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _locCtrl,
                    decoration: InputDecoration(
                      labelText: 'Theater Location',
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
                    onTap: () async {
                      final currentContext = context;
                      final date = await showDatePicker(
                        context: currentContext,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null && currentContext.mounted) {
                        setState(() {
                          _selectedDate = date;
                        });
                        final time = await showTimePicker(
                          context: currentContext,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null && currentContext.mounted) {
                          setState(() {
                            _selectedTime = time;
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: Text(
                        _selectedDate != null && _selectedTime != null
                            ? '${_selectedDate!.toLocal().toString().split(' ')[0]} ${_selectedTime!.format(context)}'
                            : 'Select Date and Time',
                        style: GoogleFonts.poppins(
                            color: _selectedDate != null
                                ? Colors.white
                                : Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _seatsCtrl,
                    decoration: InputDecoration(
                      labelText: 'Number of Seats',
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
                  TextField(
                    controller: _seatDetailsCtrl,
                    decoration: InputDecoration(
                      labelText: 'Seat Details (e.g., A1, A2)',
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
                  GestureDetector(
                    onTap: () {
                      showDialog(
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
                                    'Tap to add ticket image',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70),
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _pickTicketFile,
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
                          _ticketFileName != null
                              ? 'File: $_ticketFileName'
                              : 'Tap to upload ticket file',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: _ticketFileName != null
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
                      widget.existingTicket != null ? 'Update' : 'Save',
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

class MovieSelectionScreen extends StatefulWidget {
  final String apiKey;

  const MovieSelectionScreen({super.key, required this.apiKey});

  @override
  State<MovieSelectionScreen> createState() => _MovieSelectionScreenState();
}

class _MovieSelectionScreenState extends State<MovieSelectionScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _movies = [];
  bool _isLoading = false;

  void _searchMovies(String query) async {
    final currentContext = context;
    if (query.isEmpty) {
      setState(() {
        _movies = [];
      });
      return;
    }
    setState(() {
      _isLoading = true;
    });
    final url = Uri.parse(
        'https://api.themoviedb.org/3/search/movie?api_key=${widget.apiKey}&query=$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _movies = List<Map<String, dynamic>>.from(data['results']);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch movies');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Failed to fetch movies')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Colors.blueAccent;
    return Scaffold(
      appBar: AppBar(
        title: Text('Select a Movie',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.black.withOpacity(0.8),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Search for a movie',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search, color: accent),
                  onPressed: () => _searchMovies(_searchCtrl.text),
                ),
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
              onSubmitted: _searchMovies,
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: accent))
                : _movies.isEmpty
                    ? Center(
                        child: Text('No movies found',
                            style: GoogleFonts.poppins(color: Colors.white70)))
                    : ListView.builder(
                        itemCount: _movies.length,
                        itemBuilder: (context, index) {
                          final movie = _movies[index];
                          return ListTile(
                            leading: movie['poster_path'] != null
                                ? Image.network(
                                    'https://image.tmdb.org/t/p/w200${movie['poster_path']}',
                                    width: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.movie,
                                        color: Colors.white70),
                                  )
                                : const Icon(Icons.movie,
                                    color: Colors.white70),
                            title: Text(movie['title'] ?? 'Untitled',
                                style:
                                    GoogleFonts.poppins(color: Colors.white)),
                            onTap: () => Navigator.pop(context, movie),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class TicketReviewScreen extends StatelessWidget {
  final MarketplaceTicket ticket;

  const TicketReviewScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    const accent = Colors.blueAccent;
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview Ticket',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.black.withOpacity(0.8),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Color(0xFF111927),
          gradient: RadialGradient(
            center: Alignment(0.0, -0.6),
            radius: 1.2,
            colors: [Colors.blueAccent.withOpacity(0.2), Colors.transparent],
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
                    Text('Movie: ${ticket.movieTitle}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Location: ${ticket.location}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Price: \$${ticket.price.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                        'Date: ${DateTime.parse(ticket.date).toLocal().toString().split('.')[0]}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                        'Seats: ${ticket.seatDetails ?? ticket.seats.toString()}',
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 16),
                    if (ticket.imageBase64 != null)
                      SizedBox(
                        height: 150,
                        child: Image.memory(base64Decode(ticket.imageBase64!),
                            fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 16),
                    if (ticket.ticketFileBase64 != null)
                      Text('Uploaded File: (File attached)',
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
                          if (ticket.id != null) {
                            await MarketplaceItemDb.instance.update(ticket);
                          } else {
                            await MarketplaceItemDb.instance.insert(ticket);
                          }
                          if (currentContext.mounted) {
                            Navigator.pop(currentContext, true);
                          }
                        } catch (e) {
                          if (currentContext.mounted) {
                            ScaffoldMessenger.of(currentContext).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to save ticket: $e')),
                            );
                          }
                        }
                      },
                      child: Text(
                        ticket.id != null ? 'Update Ticket' : 'Post Ticket',
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
