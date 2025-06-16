import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:movie_app/database/auth_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:async';
import 'chat_settings_screen.dart';
import 'stories.dart';
import 'package:just_audio/just_audio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'chat_widgets.dart';
import 'package:crypto/crypto.dart';
import 'group_settings_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final Map<String, dynamic> conversation;
  final List<Map<String, dynamic>> participants;

  const GroupChatScreen({
    Key? key,
    required this.currentUser,
    required this.conversation,
    required this.participants,
  }) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _replyingToMessageId;
  Color _chatBgColor = Colors.white;
  String? _chatBgImage;
  String? _cinematicTheme;
  String _searchTerm = "";
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _audioPath;
  AnimationController? _animationController;
  Animation<double>? _pulseAnimation;
  Map<String, RTCPeerConnection> _peerConnections = {};
  Map<String, MediaStream> _remoteStreams = {};
  MediaStream? _localStream;
  String? _currentCallId;
  StreamSubscription<DocumentSnapshot>? _callSubscription;
  StreamSubscription<QuerySnapshot>? _offersSubscription;
  StreamSubscription<QuerySnapshot>? _answersSubscription;
  StreamSubscription<QuerySnapshot>? _candidatesSubscription;
  bool _isInCall = false;
  bool _isVideoCall = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<DocumentSnapshot>? _typingSubscription;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  bool _showEmojiPicker = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  Timer? _typingTimer;
  bool _isTyping = false;
  List<String> _typingUsers = [];
  late encrypt.Encrypter _encrypter;
  Database? _localDb;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String? _draftMessage;
  Map<String, String> _userNames = {};
  late List<String> _participantIds;

  @override
  void initState() {
    super.initState();
    _participantIds =
        widget.participants.map((p) => p['id'].toString()).toList();
    _userNames = {
      for (var participant in widget.participants)
        participant['id'].toString(): participant['username'] ?? 'Unknown'
    };
    _initializeRecorder();
    _initializeAnimation();
    _initializeEncryption();
    _initializeLocalDatabase();
    _initializeNotifications();
    _loadMessages();
    _listenToFirestoreMessages();
    _loadDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() => _currentlyPlayingId = null);
      }
    });
    final conversationId = widget.conversation['id'];
    _typingSubscription = _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .listen((doc) {
      final typingUsers = (doc.data()?['typing_users'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      setState(() => _typingUsers = typingUsers
          .where((id) => id != widget.currentUser['id'].toString())
          .toList());
    });
    _firestore
        .collection('calls')
        .where('conversation_id',
            isEqualTo: widget.conversation['id'].toString())
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && !_isInCall) {
        final callDoc = snapshot.docs.first;
        final callId = callDoc.id;
        final isVideo = callDoc['is_video'];
        _joinCall(callId, isVideo);
      }
    });
  }

  void _initializeEncryption() {
    final conversationId = widget.conversation['id'].toString();
    final keyBytes = sha256.convert(utf8.encode(conversationId)).bytes;
    final encryptionKey = encrypt.Key(Uint8List.fromList(keyBytes));
    _encrypter = encrypt.Encrypter(encrypt.AES(encryptionKey));
  }

  Future<void> _initializeLocalDatabase() async {
    _localDb =
        await openDatabase('chat.db', version: 1, onCreate: (db, version) {
      db.execute(
          'CREATE TABLE offline_messages (id TEXT PRIMARY KEY, data TEXT)');
      db.execute(
          'CREATE TABLE drafts (conversation_id TEXT PRIMARY KEY, content TEXT)');
    });
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    await Permission.microphone.request();
  }

  Future<void> _loadMessages() async {
    try {
      final conversationId = widget.conversation['id'].toString();
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();
      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'sender_id': data['sender_id']?.toString() ?? '',
          'receiver_id': data['receiver_id']?.toString(),
          'conversation_id': conversationId,
          'message': data['message']?.toString() ?? '',
          'iv': data['iv']?.toString(),
          'created_at':
              (data['timestamp'] as Timestamp?)?.toDate().toIso8601String() ??
                  DateTime.now().toIso8601String(),
          'is_read': data['is_read'] == true,
          'is_pinned': data['is_pinned'] == true,
          'replied_to': data['replied_to']?.toString(),
          'type': data['type']?.toString() ?? 'text',
          'firestore_id': doc.id,
          'reactions': data['reactions'] is Map
              ? data['reactions']
              : (data['reactions'] is String
                  ? (data['reactions'].isEmpty
                      ? {}
                      : jsonDecode(data['reactions']))
                  : {}),
          'delivered_to': (data['delivered_to'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [widget.currentUser['id'].toString()],
          'read_by':
              (data['read_by'] as List?)?.map((e) => e.toString()).toList() ??
                  [],
          'delivered_at':
              (data['delivered_at'] as Timestamp?)?.toDate().toIso8601String(),
          'read_at':
              (data['read_at'] as Timestamp?)?.toDate().toIso8601String(),
          'scheduled_at': data['scheduled_at']?.toString(),
          'delete_after': data['delete_after']?.toString(),
        };
      }).toList();

      for (var message in messages) {
        final senderId = message['sender_id'].toString();
        if (!_userNames.containsKey(senderId)) {
          final user = await AuthDatabase.instance.getUserById(senderId);
          _userNames[senderId] = user?['username']?.toString() ?? 'Unknown';
        }
        message['sender_username'] = _userNames[senderId];
      }

      final decryptedMessages = messages.map((message) {
        final reactions = message['reactions'] is String
            ? (message['reactions'].isEmpty
                ? {}
                : jsonDecode(message['reactions']))
            : (message['reactions'] ?? {});
        if (message['type'] == 'text' && message['iv'] != null) {
          try {
            final iv = encrypt.IV.fromBase64(message['iv']);
            final decryptedText =
                _encrypter.decrypt64(message['message'], iv: iv);
            return {
              ...message,
              'message': decryptedText,
              'reactions': reactions,
            };
          } catch (e) {
            debugPrint('Error decrypting message ${message['id']}: $e');
            return {
              ...message,
              'message': '[Decryption Failed]',
              'reactions': reactions,
            };
          }
        }
        return {...message, 'reactions': reactions};
      }).toList();

      if (mounted) {
        setState(() {
          _messages = decryptedMessages
              .where((m) =>
                  !_messages.any((existing) => existing['id'] == m['id']))
              .toList();
        });
      }
      _syncOfflineMessages();
      await _markMessagesAsDeliveredAndRead();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load messages: $e')),
      );
    }
  }

  Future<void> _markMessagesAsDeliveredAndRead() async {
    final conversationId = widget.conversation['id'].toString();
    final currentUserId = widget.currentUser['id'].toString();
    for (var message in _messages) {
      if (!message['delivered_to'].contains(currentUserId)) {
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(message['firestore_id'])
            .update({
          'delivered_to': FieldValue.arrayUnion([currentUserId]),
        });
        message['delivered_to'].add(currentUserId);
      }
      if (!message['read_by'].contains(currentUserId)) {
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(message['firestore_id'])
            .update({
          'read_by': FieldValue.arrayUnion([currentUserId]),
        });
        message['read_by'].add(currentUserId);
      }
    }
  }

  Future<void> _loadDraft() async {
    final conversationId = widget.conversation['id'];
    final drafts = await _localDb!.query('drafts',
        where: 'conversation_id = ?', whereArgs: [conversationId]);
    if (drafts.isNotEmpty) {
      setState(() => _draftMessage = drafts.first['content'] as String?);
      _controller.text = _draftMessage ?? '';
    }
  }

  void _saveDraft(String text) async {
    final conversationId = widget.conversation['id'];
    await _localDb!.insert(
        'drafts', {'conversation_id': conversationId, 'content': text},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _draftMessage = text;
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final iv = encrypt.IV.fromSecureRandom(16);
    final encryptedText = _encrypter.encrypt(text, iv: iv).base64;
    final messageId = const Uuid().v4();

    final message = {
      'id': messageId,
      'sender_id': widget.currentUser['id'].toString(),
      'receiver_id': widget.conversation['id'].toString(),
      'conversation_id': widget.conversation['id'].toString(),
      'message': encryptedText,
      'iv': base64Encode(iv.bytes),
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
      'is_pinned': false,
      'replied_to': _replyingToMessageId,
      'type': 'text',
      'reactions': {},
      'delivered_to': [widget.currentUser['id'].toString()],
      'read_by': [],
      'delivered_at': DateTime.now().toIso8601String(),
      'read_at': null,
    };

    await _sendMessageToBoth(message);
    _controller.clear();
    setState(() => _replyingToMessageId = null);
    _saveDraft('');
    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    if (await Permission.microphone.isGranted) {
      final dir = await getTemporaryDirectory();
      _audioPath = '${dir.path}/${const Uuid().v4()}.aac';
      await _recorder!.startRecorder(toFile: _audioPath);
      setState(() => _isRecording = true);
      _animationController?.forward();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
    }
  }

  Future<void> _stopRecording() async {
    await _recorder!.stopRecorder();
    setState(() => _isRecording = false);
    _animationController?.reset();
    if (_audioPath != null) {
      final audioUrl = await _uploadFile(File(_audioPath!), 'audio');
      if (audioUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload audio')),
        );
        return;
      }
      final messageId = const Uuid().v4();
      final message = {
        'id': messageId,
        'sender_id': widget.currentUser['id'].toString(),
        'receiver_id': widget.conversation['id'].toString(),
        'conversation_id': widget.conversation['id'].toString(),
        'message': audioUrl,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'is_pinned': false,
        'replied_to': _replyingToMessageId,
        'type': 'audio',
        'reactions': {},
        'delivered_to': [widget.currentUser['id'].toString()],
        'read_by': [],
      };
      await _sendMessageToBoth(message);
      _scrollToBottom();
    }
  }

  Future<void> _uploadAttachment() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['jpg', 'png', 'mp4', 'pdf']);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      String fileUrl;
      final fileType = file.extension == 'jpg' || file.extension == 'png'
          ? 'image'
          : file.extension == 'mp4'
              ? 'video'
              : 'document';
      if (kIsWeb && file.bytes != null) {
        fileUrl = await _uploadFile(file.bytes!, fileType, isBytes: true);
      } else if (file.path != null) {
        fileUrl = await _uploadFile(File(file.path!), fileType);
      } else {
        return;
      }
      if (fileUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload attachment')),
        );
        return;
      }
      final messageId = const Uuid().v4();
      final message = {
        'id': messageId,
        'sender_id': widget.currentUser['id'].toString(),
        'receiver_id': widget.conversation['id'].toString(),
        'conversation_id': widget.conversation['id'].toString(),
        'message': fileUrl,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'is_pinned': false,
        'replied_to': _replyingToMessageId,
        'type': fileType,
        'reactions': {},
        'delivered_to': [widget.currentUser['id'].toString()],
        'read_by': [],
      };
      await _sendMessageToBoth(message);
      _scrollToBottom();
    }
  }

  Future<String> _uploadFile(dynamic file, String type,
      {bool isBytes = false}) async {
    try {
      final fileId = const Uuid().v4();
      final filePath =
          'chat_media/$fileId.${type == 'image' ? 'jpg' : type == 'video' ? 'mp4' : type == 'audio' ? 'aac' : 'pdf'}';
      if (isBytes) {
        await _supabase.storage
            .from('media-bucket')
            .uploadBinary(filePath, file as Uint8List);
      } else {
        await _supabase.storage
            .from('media-bucket')
            .upload(filePath, file as File);
      }
      return _supabase.storage.from('media-bucket').getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return '';
    }
  }

  Future<void> _startCall({required bool isVideo}) async {
    if (await Permission.microphone.isGranted &&
        (!isVideo || await Permission.camera.isGranted)) {
      setState(() {
        _isInCall = true;
        _isVideoCall = isVideo;
      });

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideo,
      });

      final callId = const Uuid().v4();
      _currentCallId = callId;
      await _firestore.collection('calls').doc(callId).set({
        'conversation_id': widget.conversation['id'].toString(),
        'initiator_id': widget.currentUser['id'].toString(),
        'is_video': isVideo,
        'participants': [widget.currentUser['id'].toString()],
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _setupCallListeners(callId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Required permissions denied')),
      );
    }
  }

  Future<void> _joinCall(String callId, bool isVideo) async {
    setState(() {
      _isInCall = true;
      _isVideoCall = isVideo;
      _currentCallId = callId;
    });

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo,
    });

    await _firestore.collection('calls').doc(callId).update({
      'participants':
          FieldValue.arrayUnion([widget.currentUser['id'].toString()])
    });

    _setupCallListeners(callId);
  }

  void _setupCallListeners(String callId) {
    _offersSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .collection('offers')
        .where('to', isEqualTo: widget.currentUser['id'].toString())
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data()!;
          final from = data['from'].toString();
          final offer = RTCSessionDescription(
            data['offer']['sdp'],
            data['offer']['type'],
          );

          final pc = await _createPeerConnection(from);
          await pc.setRemoteDescription(offer);
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);

          await _firestore
              .collection('calls')
              .doc(callId)
              .collection('answers')
              .add({
            'from': widget.currentUser['id'].toString(),
            'to': from,
            'answer': {'sdp': answer.sdp, 'type': answer.type},
          });

          _listenForCandidates(callId, from);
        }
      }
    });

    _answersSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .collection('answers')
        .where('to', isEqualTo: widget.currentUser['id'].toString())
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data()!;
          final from = data['from'].toString();
          final answer = RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          );
          final pc = _peerConnections[from];
          if (pc != null) {
            await pc.setRemoteDescription(answer);
          }
        }
      }
    });

    _callSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snapshot) async {
      final data = snapshot.data();
      if (data != null) {
        final participants = (data['participants'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final myId = widget.currentUser['id'].toString();
        for (var participant in participants) {
          if (participant != myId &&
              !_peerConnections.containsKey(participant)) {
            await _sendOffer(callId, participant);
          }
        }
      }
    });
  }

  Future<RTCPeerConnection> _createPeerConnection(String peerId) async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'}
      ]
    });

    pc.onIceCandidate = (candidate) {
      _firestore
          .collection('calls')
          .doc(_currentCallId)
          .collection('candidates')
          .add({
        'from': widget.currentUser['id'].toString(),
        'to': peerId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    pc.onAddStream = (stream) {
      setState(() {
        _remoteStreams[peerId] = stream;
      });
    };

    _localStream!.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    _peerConnections[peerId] = pc;
    return pc;
  }

  Future<void> _sendOffer(String callId, String to) async {
    final pc = await _createPeerConnection(to);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _firestore.collection('calls').doc(callId).collection('offers').add({
      'from': widget.currentUser['id'].toString(),
      'to': to,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  void _listenForCandidates(String callId, String from) {
    _firestore
        .collection('calls')
        .doc(callId)
        .collection('candidates')
        .where('to', isEqualTo: widget.currentUser['id'].toString())
        .where('from', isEqualTo: from)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data()!;
          final candidate = RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          );
          final pc = _peerConnections[from];
          if (pc != null) {
            pc.addCandidate(candidate);
          }
        }
      }
    });
  }

  Future<void> _endCall() async {
    _peerConnections.forEach((key, pc) async {
      await pc.close();
    });
    _peerConnections.clear();
    _remoteStreams.clear();
    await _localStream?.dispose();
    if (_currentCallId != null) {
      await _firestore.collection('calls').doc(_currentCallId).update({
        'status': 'ended',
      });
      _currentCallId = null;
    }
    _callSubscription?.cancel();
    _offersSubscription?.cancel();
    _answersSubscription?.cancel();
    _candidatesSubscription?.cancel();
    setState(() => _isInCall = false);
  }

  Future<void> _sendMessageToBoth(Map<String, dynamic> message) async {
    try {
      final messageId = message['id'];
      final conversationId = widget.conversation['id'].toString();

      final convoDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      if (!convoDoc.exists || convoDoc.data()?['type'] != 'group') {
        throw Exception('Invalid group conversation');
      }

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .set({
        'sender_id': message['sender_id'],
        'receiver_id': message['receiver_id'],
        'conversation_id': message['conversation_id'],
        'message': message['message'],
        'iv': message['iv'],
        'timestamp': FieldValue.serverTimestamp(),
        'is_read': message['is_read'],
        'is_pinned': message['is_pinned'],
        'replied_to': message['replied_to'],
        'type': message['type'],
        'reactions': message['reactions'] ?? {},
        'delivered_to': message['delivered_to'],
        'read_by': message['read_by'],
        'delivered_at': FieldValue.serverTimestamp(),
        'read_at': null,
        'scheduled_at': message['scheduled_at'],
        'delete_after': message['delete_after'],
      });

      await AuthDatabase.instance
          .createMessage({...message, 'firestore_id': messageId});

      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': widget.conversation['participants'],
        'group_name': widget.conversation['group_name'],
        'type': 'group',
        'last_message': message['type'] == 'text'
            ? _encrypter.decrypt64(message['message'],
                iv: encrypt.IV.fromBase64(message['iv']))
            : message['type'],
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m['id'] == messageId)) {
            final newMessage = {
              ...message,
              'firestore_id': messageId,
              'delivered_at': DateTime.now().toIso8601String(),
              'sender_username': _userNames[message['sender_id']] ??
                  widget.currentUser['username'],
            };
            _messages.add(newMessage);
          }
        });
      }
      _showNotification(message);
    } catch (e) {
      debugPrint('Error sending message: $e');
      await _localDb!.insert('offline_messages',
          {'id': message['id'], 'data': jsonEncode(message)});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message failed to send: $e')),
      );
    }
  }

  Future<void> _syncOfflineMessages() async {
    final offlineMessages = await _localDb!.query('offline_messages');
    for (var msg in offlineMessages) {
      final message = jsonDecode(msg['data'] as String) as Map<String, dynamic>;
      await _sendMessageToBoth(message);
      await _localDb!
          .delete('offline_messages', where: 'id = ?', whereArgs: [msg['id']]);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _updateChatBackground(
      {Color? color, String? imageUrl, String? cinematicTheme}) {
    setState(() {
      if (color != null) _chatBgColor = color;
      if (imageUrl != null) _chatBgImage = imageUrl;
      if (cinematicTheme != null) _cinematicTheme = cinematicTheme;
    });
  }

  void _deleteMessage(int index) async {
    final message = _messages[index];
    try {
      await AuthDatabase.instance.deleteMessage(message['id']);
      if (message['firestore_id'] != null) {
        await _firestore
            .collection('conversations')
            .doc(widget.conversation['id'])
            .collection('messages')
            .doc(message['firestore_id'])
            .delete();
      }
      setState(() => _messages.removeAt(index));
    } catch (e) {
      debugPrint('Error deleting message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $e')),
      );
    }
  }

  void _toggleReadStatus(int index) async {
    final message = Map<String, dynamic>.from(_messages[index]);
    final isRead = message['is_read'] == true;
    final updatedMessage = {
      'id': message['id'].toString(),
      'is_read': !isRead,
      'read_at': !isRead ? DateTime.now().toIso8601String() : null,
    };
    try {
      await AuthDatabase.instance.updateMessage(updatedMessage);
      if (message['firestore_id'] != null) {
        await _firestore
            .collection('conversations')
            .doc(widget.conversation['id'])
            .collection('messages')
            .doc(message['firestore_id'])
            .update({
          'is_read': !isRead,
          'read_at': !isRead ? FieldValue.serverTimestamp() : null,
        });
      }
      setState(() {
        _messages[index]['is_read'] = !isRead;
        _messages[index]['read_at'] =
            !isRead ? DateTime.now().toIso8601String() : null;
      });
    } catch (e) {
      debugPrint('Error updating read status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update read status: $e')),
      );
    }
  }

  void _replyToMessage(int index) {
    if (index < 0 || index >= _messages.length) return;
    setState(() => _replyingToMessageId = _messages[index]['id'].toString());
  }

  void _pinMessage(int index) async {
    final message = Map<String, dynamic>.from(_messages[index]);
    final isPinned = message['is_pinned'] == true;
    final updatedMessage = {
      'id': message['id'].toString(),
      'is_pinned': !isPinned
    };
    try {
      await AuthDatabase.instance.updateMessage(updatedMessage);
      if (message['firestore_id'] != null) {
        await _firestore
            .collection('conversations')
            .doc(widget.conversation['id'])
            .collection('messages')
            .doc(message['firestore_id'])
            .update({'is_pinned': !isPinned});
      }
      setState(() => _messages[index]['is_pinned'] = !isPinned);
    } catch (e) {
      debugPrint('Error pinning message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pin message: $e')),
      );
    }
  }

  void _addReaction(String messageId, String reaction) async {
    final userId = widget.currentUser['id'].toString();
    final message = _messages.firstWhere((m) => m['id'] == messageId);
    final reactions =
        Map<String, List<String>>.from(message['reactions'] ?? {});
    reactions[reaction] = reactions[reaction] ?? [];
    if (!reactions[reaction]!.contains(userId)) {
      reactions[reaction]!.add(userId);
    } else {
      reactions[reaction]!.remove(userId);
    }
    try {
      await AuthDatabase.instance
          .updateMessage({'id': messageId, 'reactions': reactions});
      if (message['firestore_id'] != null) {
        await _firestore
            .collection('conversations')
            .doc(widget.conversation['id'])
            .collection('messages')
            .doc(message['firestore_id'])
            .update({'reactions': reactions});
      }
      setState(() => message['reactions'] = reactions);
    } catch (e) {
      debugPrint('Error adding reaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add reaction: $e')),
      );
    }
  }

  void _forwardMessage(Map<String, dynamic> message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Forwarding message: ${message['message']}')),
    );
  }

  void _scheduleMessage(String text, DateTime time) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encryptedText = _encrypter.encrypt(text, iv: iv).base64;
    final messageId = const Uuid().v4();
    final message = {
      'id': messageId,
      'sender_id': widget.currentUser['id'].toString(),
      'receiver_id': widget.conversation['id'].toString(),
      'conversation_id': widget.conversation['id'].toString(),
      'message': encryptedText,
      'iv': base64Encode(iv.bytes),
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
      'is_pinned': false,
      'replied_to': _replyingToMessageId,
      'type': 'text',
      'reactions': {},
      'scheduled_at': time.toIso8601String(),
      'delivered_to': [widget.currentUser['id'].toString()],
      'read_by': [],
    };
    _sendMessageToBoth(message);
  }

  void _setAutoDelete(String messageId, Duration duration) async {
    final message = _messages.firstWhere((m) => m['id'] == messageId);
    final deleteTime = DateTime.now().add(duration);
    try {
      await AuthDatabase.instance.updateMessage(
          {'id': messageId, 'delete_after': deleteTime.toIso8601String()});
      if (message['firestore_id'] != null) {
        await _firestore
            .collection('conversations')
            .doc(widget.conversation['id'])
            .collection('messages')
            .doc(message['firestore_id'])
            .update({'delete_after': deleteTime.toIso8601String()});
      }
      setState(() => message['delete_after'] = deleteTime.toIso8601String());
    } catch (e) {
      debugPrint('Error setting auto-delete: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set auto-delete: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _searchMessages() {
    if (_searchTerm.isEmpty) return _messages;
    return _messages.where((message) {
      try {
        final iv = message['iv'] != null
            ? encrypt.IV.fromBase64(message['iv'])
            : encrypt.IV.fromLength(16);
        final msgText = message['type'] == 'text' && message['iv'] != null
            ? _encrypter.decrypt64(message['message'], iv: iv)
            : message['message'].toString().toLowerCase();
        return msgText.contains(_searchTerm.toLowerCase());
      } catch (e) {
        debugPrint('Error decrypting message for search: $e');
        return false;
      }
    }).toList();
  }

  void _showNotification(Map<String, dynamic> message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails('chat_channel', 'Chat Notifications',
            importance: Importance.max, priority: Priority.high);
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);
    String notificationText;
    try {
      if (message['type'] == 'text' && message['iv'] != null) {
        final iv = encrypt.IV.fromBase64(message['iv']);
        notificationText = _encrypter.decrypt64(message['message'], iv: iv);
      } else {
        notificationText = message['type'];
      }
    } catch (e) {
      debugPrint('Error decrypting notification: $e');
      notificationText = '[Decryption Failed]';
    }
    await _notificationsPlugin.show(
      0,
      'New Message in ${widget.conversation['group_name']}',
      notificationText,
      notificationDetails,
    );
  }

  void _updateTypingStatus(bool isTyping) async {
    try {
      final conversationId = widget.conversation['id'];
      final userId = widget.currentUser['id'].toString();
      if (isTyping) {
        await _firestore.collection('conversations').doc(conversationId).set({
          'typing_users': FieldValue.arrayUnion([userId])
        }, SetOptions(merge: true));
      } else {
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .update({
          'typing_users': FieldValue.arrayRemove([userId])
        });
      }
    } catch (e) {
      debugPrint('Error updating typing status: $e');
    }
  }

  void _listenToFirestoreMessages() {
    final conversationId = widget.conversation['id'];
    _messagesSubscription = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) async {
      final newMessages = <Map<String, dynamic>>[];
      for (var doc in snapshot.docChanges
          .where((change) => change.type == DocumentChangeType.added)) {
        final data = doc.doc.data()!;
        final messageId = doc.doc.id;
        if (_messages.any((m) => m['id'] == messageId)) continue;

        String messageText = data['message'].toString();
        final reactions = data['reactions'] is String
            ? (data['reactions'].isEmpty ? {} : jsonDecode(data['reactions']))
            : (data['reactions'] ?? {});
        if (data['type'] == 'text' && data['iv'] != null) {
          try {
            final iv = encrypt.IV.fromBase64(data['iv']);
            messageText = _encrypter.decrypt64(messageText, iv: iv);
          } catch (e) {
            debugPrint('Error decrypting Firestore message $messageId: $e');
            messageText = '[Decryption Failed]';
          }
        }
        final senderId = data['sender_id'].toString();
        String? senderUsername = _userNames[senderId] ?? 'Unknown';
        final message = {
          'id': messageId,
          'sender_id': senderId,
          'receiver_id': data['receiver_id']?.toString(),
          'conversation_id': data['conversation_id']?.toString(),
          'message': messageText,
          'iv': data['iv']?.toString(),
          'created_at':
              (data['timestamp'] as Timestamp?)?.toDate().toIso8601String() ??
                  DateTime.now().toIso8601String(),
          'is_read': data['is_read'] == true,
          'is_pinned': data['is_pinned'] == true,
          'replied_to': data['replied_to']?.toString(),
          'type': data['type']?.toString() ?? 'text',
          'firestore_id': messageId,
          'reactions': reactions,
          'delivered_to': (data['delivered_to'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          'read_by':
              (data['read_by'] as List?)?.map((e) => e.toString()).toList() ??
                  [],
          'delivered_at':
              (data['delivered_at'] as Timestamp?)?.toDate().toIso8601String(),
          'read_at':
              (data['read_at'] as Timestamp?)?.toDate().toIso8601String(),
          'scheduled_at': data['scheduled_at']?.toString(),
          'delete_after': data['delete_after']?.toString(),
          'sender_username': senderUsername,
        };
        newMessages.add(message);
      }
      if (newMessages.isNotEmpty && mounted) {
        setState(() {
          _messages.addAll(newMessages);
          _messages.sort((a, b) => DateTime.parse(a['created_at'])
              .compareTo(DateTime.parse(b['created_at'])));
        });
        _scrollToBottom();
      }
    }, onError: (e) => debugPrint('Error listening to messages: $e'));
  }

  void _setCurrentlyPlaying(String? id) {
    setState(() => _currentlyPlayingId = id);
  }

  @override
  void dispose() {
    _typingSubscription?.cancel();
    _messagesSubscription?.cancel();
    _recorder?.closeRecorder();
    _recorder = null;
    _controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _animationController?.dispose();
    _audioPlayer.dispose();
    _typingTimer?.cancel();
    _localDb?.close();
    _endCall();
    super.dispose();
  }

  BoxDecoration _buildChatDecoration() {
    if (_chatBgImage != null && _chatBgImage!.isNotEmpty) {
      return BoxDecoration(
          image: DecorationImage(
              image: NetworkImage(_chatBgImage!), fit: BoxFit.cover));
    } else if (_cinematicTheme != null) {
      switch (_cinematicTheme) {
        case "Classic Film":
          return const BoxDecoration(color: Colors.black87);
        case "Modern Blockbuster":
          return const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.blueGrey, Colors.black],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight));
        case "Indie Vibes":
          return BoxDecoration(color: Colors.brown.shade200);
        case "Sci-Fi Adventure":
          return const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.black],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight));
        case "Noir":
          return BoxDecoration(color: Colors.grey.shade900);
      }
    }
    return BoxDecoration(color: _chatBgColor);
  }

  void _showMessageOptions(BuildContext context, Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _replyToMessage(_messages.indexOf(message));
              }),
          ListTile(
              leading: Icon(message['is_read'] == true
                  ? Icons.check_circle
                  : Icons.check_circle_outline),
              title: Text(message['is_read'] == true
                  ? 'Mark as unread'
                  : 'Mark as read'),
              onTap: () {
                Navigator.pop(context);
                _toggleReadStatus(_messages.indexOf(message));
              }),
          ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(_messages.indexOf(message));
              }),
          ListTile(
              leading: Icon(message['is_pinned'] == true
                  ? Icons.push_pin
                  : Icons.push_pin_outlined),
              title: Text(message['is_pinned'] == true ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(context);
                _pinMessage(_messages.indexOf(message));
              }),
          ListTile(
              leading: const Icon(Icons.add_reaction),
              title: const Text('Add Reaction'),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(message['id']);
              }),
          ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                _forwardMessage(message);
              }),
        ],
      ),
    );
  }

  void _showReactionPicker(String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
              leading: const Icon(Icons.thumb_up),
              title: const Text('Like'),
              onTap: () {
                _addReaction(messageId, 'like');
                Navigator.pop(context);
              }),
          ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Heart'),
              onTap: () {
                _addReaction(messageId, 'heart');
                Navigator.pop(context);
              }),
        ],
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String getHeaderText(DateTime date) {
    final now = DateTime.now();
    if (isSameDay(date, now)) return "Today";
    if (isSameDay(date, now.subtract(const Duration(days: 1))))
      return "Yesterday";
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredMessages = _searchMessages();
    List<Map<String, dynamic>> combinedItems = [
      ...filteredMessages.map((m) {
        String? repliedToText;
        if (m['replied_to'] != null) {
          final repliedMsg = _messages.firstWhere(
            (msg) => msg['id'] == m['replied_to'],
            orElse: () => {'message': 'Original message not found'},
          );
          try {
            repliedToText =
                repliedMsg['type'] == 'text' && repliedMsg['iv'] != null
                    ? _encrypter.decrypt64(repliedMsg['message'],
                        iv: encrypt.IV.fromBase64(repliedMsg['iv']))
                    : repliedMsg['message'].toString();
          } catch (e) {
            debugPrint(
                'Error decrypting replied message ${m['replied_to']}: $e');
            repliedToText = '[Decryption Failed]';
          }
        }
        return {
          'type': 'message',
          'data': m,
          'timestamp': DateTime.parse(m['created_at'].toString()),
          'replied_to_text': repliedToText,
        };
      }),
    ];
    combinedItems.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

    List<Widget> listWidgets = [];
    for (int i = 0; i < combinedItems.length; i++) {
      final item = combinedItems[i];
      if (item['type'] == 'message') {
        final DateTime currentDate = item['timestamp'];
        if (i == 0 ||
            (combinedItems[i - 1]['type'] == 'message' &&
                !isSameDay(currentDate, combinedItems[i - 1]['timestamp']))) {
          listWidgets.add(Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(getHeaderText(currentDate),
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold))));
        }
        final message = item['data'];
        final isMe = message['sender_id'] == widget.currentUser['id'];
        listWidgets.add(MessageWidget(
          message: message,
          isMe: isMe,
          repliedToText: item['replied_to_text'],
          onReply: () => _replyToMessage(_messages.indexOf(message)),
          onShare: () => _forwardMessage(message),
          onLongPress: () => _showMessageOptions(context, message),
          onTapOriginal: () {
            if (message['replied_to'] != null) {
              final index =
                  _messages.indexWhere((m) => m['id'] == message['replied_to']);
              if (index != -1) {
                _scrollController.animateTo(
                  index * 100.0, // Adjust based on actual message height
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            }
          },
          onDelete: () => _deleteMessage(_messages.indexOf(message)),
          audioPlayer: _audioPlayer,
          setCurrentlyPlaying: _setCurrentlyPlaying,
          currentlyPlayingId: _currentlyPlayingId,
          encrypter: _encrypter,
          isRead:
              message['read_by'].contains(widget.currentUser['id'].toString()),
          isStoryReply: false,
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: Row(
          children: [
            IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupSettingsScreen(
                      conversation: widget.conversation,
                      participants: widget.participants,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.group, color: Colors.white),
            ),
          ],
        ),
        leadingWidth: 80,
        title: Text(widget.conversation['group_name'] ?? 'Group Chat'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
              icon: const Icon(Icons.call),
              onPressed: () => _startCall(isVideo: false)),
          IconButton(
              icon: const Icon(Icons.video_call),
              onPressed: () => _startCall(isVideo: true)),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'change_background') {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ChatSettingsScreen(
                            currentColor: _chatBgColor,
                            currentImage: _chatBgImage)));
                if (result != null && result is Map<String, dynamic>) {
                  _updateChatBackground(
                      color: result['color'],
                      imageUrl: result['image'],
                      cinematicTheme: result['cinematicTheme']);
                }
              } else if (value == 'search') {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchTerm = "";
                    _searchController.clear();
                  }
                });
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                  value: 'change_background', child: Text('Change Background')),
              PopupMenuItem<String>(
                  value: 'search', child: Text('Search Messages')),
            ],
          ),
        ],
        bottom: _showSearch
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchTerm = value),
                    decoration: const InputDecoration(
                      hintText: "Search messages...",
                      fillColor: Colors.white,
                      filled: true,
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          Container(decoration: _buildChatDecoration()),
          if (_isInCall)
            WebRTCCallWidget(
              localStream: _localStream,
              remoteStreams: _remoteStreams,
              isVideo: _isVideoCall,
              onEnd: _endCall,
            ),
          SafeArea(
            child: Column(
              children: [
                if (_messages.any((m) => m['is_pinned'] == true))
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.deepPurple.withOpacity(0.2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pinned Messages',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        ..._messages
                            .where((m) => m['is_pinned'] == true)
                            .map((m) {
                          String pinnedText;
                          try {
                            pinnedText = m['type'] == 'text' && m['iv'] != null
                                ? _encrypter.decrypt64(m['message'],
                                    iv: encrypt.IV.fromBase64(m['iv']))
                                : m['type'];
                          } catch (e) {
                            debugPrint(
                                'Error decrypting pinned message ${m['id']}: $e');
                            pinnedText = '[Decryption Failed]';
                          }
                          return ListTile(
                            title: Text(pinnedText,
                                style: const TextStyle(color: Colors.white)),
                            onTap: () {
                              final index = _messages.indexOf(m);
                              _scrollController.animateTo(index * 100.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                Expanded(
                    child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        children: listWidgets)),
                if (_typingUsers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(children: [
                      const SizedBox(width: 8),
                      const CircularProgressIndicator(),
                      const SizedBox(width: 8),
                      Text(
                        _typingUsers.length == 1
                            ? '${_userNames[_typingUsers.first] ?? 'User'} is typing...'
                            : '${_typingUsers.length} users are typing...',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ]),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  color: Colors.red[900],
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions,
                                color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _showEmojiPicker = !_showEmojiPicker;
                                if (_showEmojiPicker) {
                                  FocusScope.of(context).unfocus();
                                } else {
                                  FocusScope.of(context)
                                      .requestFocus(FocusNode());
                                }
                              });
                            },
                          ),
                          IconButton(
                              icon: const Icon(Icons.attach_file,
                                  color: Colors.white),
                              onPressed: _uploadAttachment),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "Type a message...",
                                hintStyle: TextStyle(color: Colors.white54),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(20)),
                                    borderSide: BorderSide.none),
                                filled: true,
                                fillColor: Colors.black26,
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              onChanged: (text) {
                                _saveDraft(text);
                                if (!_isTyping) {
                                  setState(() => _isTyping = true);
                                  _updateTypingStatus(true);
                                }
                                _typingTimer?.cancel();
                                _typingTimer =
                                    Timer(const Duration(seconds: 2), () {
                                  setState(() => _isTyping = false);
                                  _updateTypingStatus(false);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _controller.text.isEmpty
                              ? AnimatedBuilder(
                                  animation: _pulseAnimation!,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _isRecording
                                          ? _pulseAnimation!.value
                                          : 1.0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _isRecording
                                                ? Colors.red.withOpacity(0.3)
                                                : Colors.transparent),
                                        child: IconButton(
                                            icon: Icon(
                                                _isRecording
                                                    ? Icons.stop
                                                    : Icons.mic,
                                                color: Colors.white),
                                            onPressed: _isRecording
                                                ? _stopRecording
                                                : _startRecording),
                                      ),
                                    );
                                  },
                                )
                              : IconButton(
                                  icon: const Icon(Icons.send,
                                      color: Colors.white),
                                  onPressed: _sendMessage),
                        ],
                      ),
                      if (_showEmojiPicker)
                        SizedBox(
                          height: 250,
                          child: EmojiPicker(
                            onEmojiSelected: (category, emoji) {
                              _controller.text += emoji.emoji;
                              _saveDraft(_controller.text);
                            },
                            config: Config(
                              emojiViewConfig: EmojiViewConfig(
                                  backgroundColor: Colors.white),
                              categoryViewConfig: CategoryViewConfig(
                                  iconColorSelected: Colors.deepPurple),
                            ),
                          ),
                        )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WebRTCCallWidget extends StatefulWidget {
  final MediaStream? localStream;
  final Map<String, MediaStream> remoteStreams;
  final bool isVideo;
  final VoidCallback onEnd;

  const WebRTCCallWidget({
    Key? key,
    required this.localStream,
    required this.remoteStreams,
    required this.isVideo,
    required this.onEnd,
  }) : super(key: key);

  @override
  _WebRTCCallWidgetState createState() => _WebRTCCallWidgetState();
}

class _WebRTCCallWidgetState extends State<WebRTCCallWidget> {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  Map<String, RTCVideoRenderer> _remoteRenderers = {};

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    if (widget.localStream != null) {
      _localRenderer.srcObject = widget.localStream;
    }
    for (var entry in widget.remoteStreams.entries) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = entry.value;
      _remoteRenderers[entry.key] = renderer;
    }
  }

  @override
  void didUpdateWidget(covariant WebRTCCallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.localStream != oldWidget.localStream) {
      _localRenderer.srcObject = widget.localStream;
    }
    for (var key in widget.remoteStreams.keys) {
      if (!oldWidget.remoteStreams.containsKey(key)) {
        final renderer = RTCVideoRenderer();
        renderer.initialize().then((_) {
          renderer.srcObject = widget.remoteStreams[key];
          setState(() {
            _remoteRenderers[key] = renderer;
          });
        });
      } else if (widget.remoteStreams[key] != oldWidget.remoteStreams[key]) {
        _remoteRenderers[key]?.srcObject = widget.remoteStreams[key];
      }
    }
    for (var key in oldWidget.remoteStreams.keys) {
      if (!widget.remoteStreams.containsKey(key)) {
        _remoteRenderers[key]?.dispose();
        _remoteRenderers.remove(key);
      }
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderers.values.forEach((renderer) => renderer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          if (widget.isVideo) ...[
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2),
              itemCount: _remoteRenderers.length,
              itemBuilder: (context, index) {
                final renderer = _remoteRenderers.values.elementAt(index);
                return RTCVideoView(
                  renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                );
              },
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 120,
                height: 160,
                margin: const EdgeInsets.all(16),
                child: RTCVideoView(
                  _localRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: widget.onEnd,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('End Call',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
