import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'watch_party_components.dart';
import 'watch_party_utils.dart';
import 'watch_party_flow.dart';

class WatchPartyScreen extends StatefulWidget {
  const WatchPartyScreen({super.key});

  @override
  WatchPartyScreenState createState() => WatchPartyScreenState();
}

class WatchPartyScreenState extends State<WatchPartyScreen>
    with TickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<String> _messages = []; // Changed from final to non-final
  String _videoPath = "";
  String _title = "Watch Party Video";
  String? _subtitleUrl;
  bool _isHls = false;
  bool _isPlaying = false; // Track playback state

  bool _controlsVisible = true;
  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _hideTimer;
  Timer? _partyTimer;

  String? _partyCode;
  bool _isAuthorized = false;
  bool _isCreator = false; // Track if user is party creator
  int _inviteJoinCount = 0;
  DateTime? _partyStartTime;
  int _remainingMinutes = 0;
  bool _isDirectStreamMode = false;
  bool _secretBypass = false;
  bool _chatMuted = false;
  bool _cinemaSoundEnabled = true;

  // Trial and Premium Features
  int _trialTickets = 3;
  bool _isPremium = false;
  late AnimationController _curtainController;
  late AnimationController _doorsController;

  // Social and Engagement
  final Map<String, String> _userSeats = {};
  final List<Map<String, dynamic>> _emojiReactions = [];

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getters
  bool get isSearching => _isSearching;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get partyCode => _partyCode;
  int get inviteJoinCount => _inviteJoinCount;
  String get videoPath => _videoPath;
  String get title => _title;
  bool get isHls => _isHls;
  String? get subtitleUrl => _subtitleUrl;
  bool get controlsVisible => _controlsVisible;
  int get trialTickets => _trialTickets;
  DateTime? get partyStartTime => _partyStartTime;
  int get remainingMinutes => _remainingMinutes;
  bool get secretBypass => _secretBypass;
  bool get chatMuted => _chatMuted;
  bool get cinemaSoundEnabled => _cinemaSoundEnabled;
  bool get isDirectStreamMode => _isDirectStreamMode;
  bool get isAuthorized => _isAuthorized;
  Timer? get partyTimer => _partyTimer;
  AnimationController get curtainController => _curtainController;
  AnimationController get doorsController => _doorsController;
  bool get isPremium => _isPremium;
  List<String> get messages => _messages;
  TextEditingController get chatController => _chatController;
  Map<String, String> get userSeats => _userSeats;
  List<Map<String, dynamic>> get emojiReactions => _emojiReactions;
  bool get isPlaying => _isPlaying;
  bool get isCreator => _isCreator;

  @override
  void initState() {
    super.initState();
    _curtainController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _doorsController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => showRoleSelection(context, this));
    startControlsTimer(this);
    _listenToPlaybackState();
    _listenToParticipants();
  }

  // Save party to Firestore
  Future<void> savePartyToFirestore(
      String code, Map<String, dynamic> movie, int delayMinutes) async {
    final partyData = {
      'code': code,
      'movieTitle': movie['title'] ?? "Untitled",
      'startTime':
          DateTime.now().add(Duration(minutes: delayMinutes)).toIso8601String(),
      'participants': 1,
      'maxParticipants': 5,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'expiryTime': DateTime.now().add(Duration(hours: 24)).toIso8601String(),
    };
    await _firestore.collection('watch_parties').doc(code).set(partyData);
  }

  // Listen to participant updates and messages
  void _listenToParticipants() {
    if (_partyCode != null) {
      _firestore.collection('watch_parties').doc(_partyCode).snapshots().listen(
        (snapshot) {
          if (snapshot.exists && mounted) {
            setState(() {
              _inviteJoinCount = snapshot.data()?['participants'] ?? 0;
            });
          }
        },
        onError: (error) =>
            showError(context, "Error syncing participants: $error"),
      );
      _firestore
          .collection('watch_parties')
          .doc(_partyCode)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          if (mounted) {
            setState(() {
              _messages =
                  snapshot.docs.map((doc) => doc['message'] as String).toList();
            });
          }
        },
        onError: (error) =>
            showError(context, "Error syncing messages: $error"),
      );
    }
  }

  // Listen to playback state
  void _listenToPlaybackState() {
    if (_partyCode != null) {
      _firestore.collection('watch_parties').doc(_partyCode).snapshots().listen(
        (snapshot) {
          if (snapshot.exists && mounted) {
            final playbackState = snapshot.data()?['playbackState'];
            setState(() {
              _isPlaying = playbackState == 'playing';
              if (_isPlaying) {
                _curtainController.forward();
              } else {
                _curtainController.reverse();
              }
            });
          }
        },
        onError: (error) =>
            showError(context, "Error syncing playback: $error"),
      );
    }
  }

  void startMoviePlayback(Map<String, dynamic> movie) {
    if (_trialTickets <= 0 && !_isPremium) {
      _doorsController.forward();
      return;
    }
    setState(() {
      _trialTickets = _trialTickets > 0 ? _trialTickets - 1 : 0;
      _partyStartTime = DateTime.now();
      _remainingMinutes = 60;
      _title = movie['title'] as String? ?? "Direct Stream";
      _isSearching = false;
      _searchResults = [];
    });
    fetchStreamingLinks(movie, this).then((_) {
      if (mounted) {
        _curtainController.forward();
        _isPlaying = true;
        if (_partyCode != null) {
          _firestore.collection('watch_parties').doc(_partyCode).update({
            'playbackState': 'playing',
            'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
          });
        }
        startPartyTimer(() {
          if (mounted && _remainingMinutes <= 0) {
            endParty();
          }
        });
        showSuccess(context, "Starting $_title");
      }
    });
  }

  void addEmojiReaction(String emoji) {
    setState(() {
      _emojiReactions.add({
        'emoji': emoji,
        'offset': Offset(0, MediaQuery.of(context).size.height),
        'time': DateTime.now(),
      });
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _emojiReactions
            .removeWhere((r) => r['time'] == _emojiReactions.first['time']));
      }
    });
  }

  void sendMessage(String value) {
    if (value.isNotEmpty) {
      final userId = "User$_inviteJoinCount";
      final message = "$userId: $value";
      setState(() {
        _messages.add(message);
      });
      _chatController.clear();
      if (_partyCode != null) {
        _firestore
            .collection('watch_parties')
            .doc(_partyCode)
            .collection('messages')
            .add({
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  void playVideo() {
    if (!_isCreator) {
      showError(context, "Only the host can control playback");
      return;
    }
    setState(() {
      _isPlaying = true;
      _curtainController.forward();
    });
    if (_partyCode != null) {
      _firestore.collection('watch_parties').doc(_partyCode).update({
        'playbackState': 'playing',
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
      });
    }
  }

  void pauseVideo() {
    if (!_isCreator) {
      showError(context, "Only the host can control playback");
      return;
    }
    setState(() {
      _isPlaying = false;
      _curtainController.reverse();
    });
    if (_partyCode != null) {
      _firestore.collection('watch_parties').doc(_partyCode).update({
        'playbackState': 'paused',
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
      });
    }
  }

  void toggleChatMute() {
    setState(() {
      _chatMuted = !_chatMuted;
    });
  }

  void toggleCinemaSound() {
    setState(() {
      _cinemaSoundEnabled = !_cinemaSoundEnabled;
    });
  }

  void resetStream() {
    setState(() {
      _partyStartTime = null;
      _videoPath = "";
      _subtitleUrl = null;
      _isHls = false;
      _isPlaying = false;
    });
    _partyTimer?.cancel();
    if (_partyCode != null) {
      _firestore.collection('watch_parties').doc(_partyCode).update({
        'playbackState': 'paused',
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
      });
    }
  }

  void upgradeToPremium() {
    setState(() {
      _isPremium = true;
      _doorsController.reverse();
    });
  }

  void hideControlsTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void clearSearchResults() {
    setState(() => _searchResults = []);
  }

  void startSearching() {
    setState(() => _isSearching = true);
  }

  void stopSearching() {
    setState(() => _isSearching = false);
  }

  void updateSearchResults(List<Map<String, dynamic>> results) {
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void updateStreamInfo({
    required String videoPath,
    required String title,
    String? subtitleUrl,
    required bool isHls,
  }) {
    setState(() {
      _videoPath = videoPath;
      _title = title;
      _subtitleUrl = subtitleUrl;
      _isHls = isHls;
    });
  }

  void addTrialTicket() {
    setState(() => _trialTickets++);
  }

  void addTriviaMessage(String answer) {
    final message = "Trivia: $answer";
    setState(() => _messages.add(message));
    if (_partyCode != null) {
      _firestore
          .collection('watch_parties')
          .doc(_partyCode)
          .collection('messages')
          .add({
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  void authorizeCreator() async {
    setState(() {
      _isLoading = true;
    });
    final code = generateSecurePartyCode();
    try {
      final existingParty =
          await _firestore.collection('watch_parties').doc(code).get();
      if (existingParty.exists) {
        showError(context, "Party code already exists, try again.");
        return;
      }
      setState(() {
        _isAuthorized = true;
        _isCreator = true;
        _partyCode = code;
      });
      _listenToParticipants();
      showSuccess(context, "Party created! Code: $code");
    } catch (e) {
      showError(context, "Failed to create party: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void authorizeAdmin() {
    setState(() {
      _secretBypass = true;
      _isAuthorized = true;
      _isCreator = true;
      _isPremium = true;
    });
  }

  void authorizeDirectStream() {
    setState(() {
      _isAuthorized = true;
      _isCreator = true;
      _secretBypass = true;
      _isDirectStreamMode = true;
    });
  }

  void joinParty(String partyCode, String seat) async {
    setState(() => _isLoading = true);
    try {
      final partyDoc =
          await _firestore.collection('watch_parties').doc(partyCode).get();
      if (partyDoc.exists && partyDoc.data()?['isActive'] == true) {
        final currentParticipants = partyDoc.data()?['participants'] ?? 0;
        final maxParticipants = partyDoc.data()?['maxParticipants'] ?? 5;
        if (currentParticipants < maxParticipants) {
          await _firestore.collection('watch_parties').doc(partyCode).update({
            'participants': FieldValue.increment(1),
          });
          setState(() {
            _isAuthorized = true;
            _partyCode = partyCode;
            _userSeats["User$_inviteJoinCount"] = seat;
            _inviteJoinCount = currentParticipants + 1;
          });
          _listenToParticipants();
          showSuccess(context, "Joined party successfully!");
        } else {
          showError(context, "Party is full!");
        }
      } else {
        showError(context, "Invalid or expired party code!");
      }
    } catch (e) {
      showError(context, "Failed to join party: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void startPartyScheduling(int delayMinutes) {
    setState(() {
      _isLoading = true;
      _partyStartTime = DateTime.now().add(Duration(minutes: delayMinutes));
      _remainingMinutes = delayMinutes;
      _trialTickets = _trialTickets > 0 ? _trialTickets - 1 : 0;
    });
  }

  void stopPartyScheduling() {
    setState(() => _isLoading = false);
  }

  void startPartyTimer(VoidCallback onTick) {
    _partyTimer?.cancel();
    _partyTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() => _remainingMinutes--);
      onTick();
    });
  }

  void endParty() async {
    if (_partyCode != null) {
      await _firestore.collection('watch_parties').doc(_partyCode).update({
        'isActive': false,
        'playbackState': 'paused',
      });
    }
    setState(() {
      _partyStartTime = null;
      _videoPath = "";
      _title = "Watch Party Video";
      _subtitleUrl = null;
      _isHls = false;
      _isPlaying = false;
      _isDirectStreamMode = false;
    });
  }

  void setMovieTitle(String title) {
    setState(() => _title = title);
  }

  @override
  void dispose() {
    _chatController.dispose();
    _searchController.dispose();
    _hideTimer?.cancel();
    _partyTimer?.cancel();
    _curtainController.dispose();
    _doorsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        if (!_isAuthorized) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_isCreator && _partyStartTime == null) {
          return _isDirectStreamMode
              ? buildDirectStreamSearchView(context, this, _searchController)
              : buildCreatorSetupView(context, this, _searchController);
        }

        if (!_isCreator && _partyStartTime == null) {
          return buildInviteeWaitingView(context, this);
        }

        return buildPartyView(context, this);
      },
    );
  }
}
