import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movie_app/marketplace/marketplace_item_db.dart';

class FanEvent {
  final String? id;
  final String eventName;
  final String description;
  final DateTime date;
  final String location;
  final int maxAttendees;
  final String organizerName;
  final String organizerEmail;

  FanEvent({
    this.id,
    required this.eventName,
    required this.description,
    required this.date,
    required this.location,
    required this.maxAttendees,
    required this.organizerName,
    required this.organizerEmail,
  });

  Map<String, dynamic> toSqlMap() => {
        'id': id,
        'type': 'fan_event',
        'name': eventName,
        'description': description,
        'date': date.toIso8601String(),
        'location': location,
        'maxAttendees': maxAttendees,
        'organizerName': organizerName,
        'organizerEmail': organizerEmail,
      };

  factory FanEvent.fromSql(Map<String, dynamic> row) => FanEvent(
        id: row['id']?.toString(),
        eventName: row['name'] as String? ?? 'Unknown',
        description: row['description'] as String? ?? '',
        date: DateTime.parse(
            row['date'] as String? ?? DateTime.now().toIso8601String()),
        location: row['location'] as String? ?? '',
        maxAttendees: row['maxAttendees'] as int? ?? 0,
        organizerName: row['organizerName'] as String? ?? '',
        organizerEmail: row['organizerEmail'] as String? ?? '',
      );
}

class FanEventsScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final FanEvent? existingEvent;
  final VoidCallback? onPosted; // Added onPosted callback

  const FanEventsScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.existingEvent,
    this.onPosted,
  });

  @override
  State<FanEventsScreen> createState() => _FanEventsScreenState();
}

class _FanEventsScreenState extends State<FanEventsScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _attendeesCtrl = TextEditingController();
  DateTime? _eventDate;

  @override
  void initState() {
    super.initState();
    if (widget.existingEvent != null) {
      _nameCtrl.text = widget.existingEvent!.eventName;
      _descCtrl.text = widget.existingEvent!.description;
      _locationCtrl.text = widget.existingEvent!.location;
      _attendeesCtrl.text = widget.existingEvent!.maxAttendees.toString();
      _eventDate = widget.existingEvent!.date;
    }
  }

  Future<void> _selectDate() async {
    final currentContext = context;
    final date = await showDatePicker(
      context: currentContext,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 180)),
    );
    if (date != null && currentContext.mounted) {
      setState(() {
        _eventDate = date;
      });
    }
  }

  Future<void> _createEvent() async {
    final currentContext = context;
    if (_nameCtrl.text.isEmpty ||
        _descCtrl.text.isEmpty ||
        _locationCtrl.text.isEmpty ||
        _attendeesCtrl.text.isEmpty ||
        _eventDate == null) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields')),
        );
      }
      return;
    }

    try {
      final attendees = int.parse(_attendeesCtrl.text);
      if (attendees <= 0) {
        throw Exception('Max attendees must be greater than 0');
      }
      if (_eventDate!.isBefore(DateTime.now())) {
        throw Exception('Event date must be in the future');
      }

      final event = FanEvent(
        id: widget.existingEvent?.id,
        eventName: _nameCtrl.text,
        description: _descCtrl.text,
        date: _eventDate!,
        location: _locationCtrl.text,
        maxAttendees: attendees,
        organizerName: widget.userName,
        organizerEmail: widget.userEmail,
      );

      // Save to database
      final db = MarketplaceItemDb.instance;
      if (widget.existingEvent != null) {
        await db.updateFanEvent(event);
      } else {
        await db.insertFanEvent(event);
      }

      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
              content: Text(
                  'Event ${widget.existingEvent != null ? 'updated' : 'created'} successfully')),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [accent.withOpacity(0.3), Color(0xFF121212)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan a Fan Event',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Event Name',
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
                    labelText: 'Event Description',
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
                  controller: _locationCtrl,
                  decoration: InputDecoration(
                    labelText: 'Location',
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
                  controller: _attendeesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Max Attendees',
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
                  onTap: _selectDate,
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _eventDate == null
                          ? 'Select Event Date'
                          : 'Date: ${_eventDate!.toLocal().toString().split(' ')[0]}',
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _createEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    widget.existingEvent != null
                        ? 'Update Event'
                        : 'Create Event',
                    style: GoogleFonts.poppins(
                        color: Colors.black, fontWeight: FontWeight.bold),
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
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _attendeesCtrl.dispose();
    super.dispose();
  }
}
