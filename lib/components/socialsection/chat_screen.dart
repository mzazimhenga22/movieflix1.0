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
import 'package:connectivity_plus/connectivity_plus.dart';

class IndividualChatScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final Map<String, dynamic> otherUser;
  final List<Map<String, dynamic>> storyInteractions;

  const IndividualChatScreen({
    super.key,
    required this.currentUser,
    required this.otherUser,
    this.storyInteractions = const [],
  });

  @override
  _IndividualChatScreenState createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _messages = [];
  late List<Map<String, dynamic>> _interactions;
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

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  StreamSubscription<QuerySnapshot>? _callsSubscription;
  StreamSubscription<DocumentSnapshot>? _callSubscription;
  StreamSubscription<QuerySnapshot>? _candidatesSubscription;
  String? _currentCallId;
  bool _isInCall = false;
  bool _isVideoCall = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  StreamSubscription<DocumentSnapshot>? _typingSubscription;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _showEmojiPicker = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isOtherTyping = false;
  late encrypt.Key _encryptionKey;
  late encrypt.Encrypter _encrypter;
  Database? _localDb;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String? _draftMessage;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _interactions = List<Map<String, dynamic>>.from(widget.storyInteractions);
    _initializeRecorder();
    _initializeAnimation();
    _initializeEncryption();
    _initializeLocalDatabase();
    _initializeNotifications();

    _loadMessages().then((_) {
      _markAllMessagesAsRead();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
    _loadBackgroundSettings();

    _setupListeners();
    _monitorConnectivity();

    _loadDraft();

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() => _currentlyPlayingId = null);
      }
    });
  }

  Future<void> _setupListeners() async {
    final conversationId = await _getConversationId();

    _typingSubscription = _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .listen((doc) {
      final typingUsers = (doc.data()?['typing_users'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      setState(() => _isOtherTyping =
          typingUsers.contains(widget.otherUser['id'].toString()));
    });

    _messagesSubscription = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docChanges
          .where((change) => change.type == DocumentChangeType.added)) {
        final data = doc.doc.data()!;
        final messageData = _normalizeMessageData({
          ...data,
          'id': doc.doc.id,
          'firestore_id': doc.doc.id,
          'conversation_id': conversationId,
        });

        await AuthDatabase.instance.createMessage(messageData);

        String messageText = messageData['message'];
        if (messageData['type'] == 'text' && messageData['iv'] != null) {
          try {
            final iv = encrypt.IV.fromBase64(messageData['iv']);
            messageText = _encrypter.decrypt64(messageText, iv: iv);
          } catch (e) {
            messageText = '[Decryption Failed]';
          }
        }

        final decryptedMessage = {...messageData, 'message': messageText};
        final existingIndex =
            _messages.indexWhere((m) => m['id'] == decryptedMessage['id']);
        if (existingIndex != -1) {
          setState(() => _messages[existingIndex] = decryptedMessage);
        } else {
          setState(() {
            _messages.add(decryptedMessage);
            if (decryptedMessage['sender_id'] == widget.otherUser['id'].toString() &&
                decryptedMessage['is_read'] == false) {
              final index = _messages.indexOf(decryptedMessage);
              if (index != -1) {
                _markMessageAsRead(index);
              }
            }
          });
        }
      }
      _scrollToBottom();
    }, onError: (e) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error listening to messages: $e'))));

    _callsSubscription = _firestore
        .collection('calls')
        .where('receiver_id', isEqualTo: widget.currentUser['id'].toString())
        .where('answer', isNull: true)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data() as Map<String, dynamic>;
          _showCallDialog(doc.doc.id, data);
        }
      }
    });
  }

Future<String> _getConversationId() async {
  final currentUserId = widget.currentUser['id']?.toString();
  final otherUserId = widget.otherUser['id']?.toString();
  print('Current user ID: $currentUserId');
  print('Other user ID: $otherUserId');
  if (currentUserId == null || otherUserId == null || 
      currentUserId.isEmpty || otherUserId.isEmpty) {
    throw Exception('Invalid user IDs: current=$currentUserId, other=$otherUserId');
  }
  final sortedIds = [currentUserId, otherUserId]..sort();
  final conversationId = sortedIds.join('_');
  print('Conversation ID: $conversationId');
  final exists = await AuthDatabase.instance.conversationExists(conversationId);
  if (!exists) {
    await _ensureConversationExists();
  }
  return conversationId;
}

  Future<void> _ensureConversationExists() async {
    final conversationId = await _getConversationId();
    final conversation = {
      'id': conversationId,
      'participants': [
        widget.currentUser['id'].toString(),
        widget.otherUser['id'].toString(),
      ],
      'last_message': '',
      'timestamp': DateTime.now().toIso8601String(),
    };
    try {
      await AuthDatabase.instance.insertConversation(conversation);
      await _firestore.collection('conversations').doc(conversationId).set(
        conversation,
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('Failed to ensure conversation exists: $e');
    }
  }

  Map<String, dynamic> _normalizeMessageData(Map<String, dynamic> data) {
    return {
      'id': data['id']?.toString() ?? '',
      'firestore_id': data['firestore_id']?.toString() ?? data['id']?.toString() ?? '',
      'conversation_id': data['conversation_id']?.toString() ?? '',
      'sender_id': data['sender_id']?.toString() ?? '',
      'receiver_id': data['receiver_id']?.toString() ?? '',
      'message': data['message']?.toString() ?? '',
      'iv': data['iv']?.toString(),
      'type': data['type']?.toString() ?? 'text',
      'is_read': data['is_read'] == true ? 1 : 0,
      'is_pinned': data['is_pinned'] == true ? 1 : 0,
      'replied_to': data['replied_to']?.toString(),
      'reactions': data['reactions'] ?? {},
      'status': data['status']?.toString() ?? 'sent',
      'created_at': data['timestamp']?.toDate()?.toIso8601String() ?? data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'delivered_at': data['delivered_at']?.toString(),
      'read_at': data['read_at']?.toString(),
      'scheduled_at': data['scheduled_at']?.toString(),
      'delete_after': data['delete_after']?.toString(),
    };
  }

  void _initializeEncryption() {
    final keyString = "${widget.currentUser['id']}_${widget.otherUser['id']}";
    final keyBytes = sha256.convert(utf8.encode(keyString)).bytes;
    _encryptionKey = encrypt.Key(Uint8List.fromList(keyBytes));
    _encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
  }

  Future<void> _initializeLocalDatabase() async {
    _localDb = await openDatabase('chat.db', version: 1, onCreate: (db, version) {
      db.execute('CREATE TABLE offline_messages (id TEXT PRIMARY KEY, data TEXT)');
      db.execute('CREATE TABLE drafts (conversation_id TEXT PRIMARY KEY, content TEXT)');
      db.execute('CREATE TABLE chat_settings (conversation_id TEXT PRIMARY KEY, bg_color INTEGER, bg_image TEXT, cinematic_theme TEXT)');
    });
  }

  Future<Database> getLocalDb() async {
    if (_localDb == null) {
      await _initializeLocalDatabase();
    }
    return _localDb!;
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

void _monitorConnectivity() {
  _connectivitySubscription = Connectivity()
      .onConnectivityChanged
      .listen((List<ConnectivityResult> results) async {
    if (results.any((result) => result != ConnectivityResult.none)) {
      await _syncOfflineMessages();
    }
  });
}

  Future<void> _handleStoryInteraction(String type, Map<String, dynamic> data) async {
    if (type == 'reply') {
      final replyText = data['content'];
      final storyId = data['storyId'];
      final iv = encrypt.IV.fromSecureRandom(16);
      final encryptedText = _encrypter.encrypt(replyText, iv: iv).base64;
      final newMessage = {
        'id': const Uuid().v4(),
        'sender_id': widget.currentUser['id'].toString(),
        'receiver_id': data['storyUserId'].toString(),
        'conversation_id': await _getConversationId(),
        'message': encryptedText,
        'iv': base64Encode(iv.bytes),
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'is_pinned': false,
        'replied_to': null,
        'type': 'text',
        'reactions': {},
        'is_story_reply': true,
        'story_id': storyId,
        'status': 'pending',
        'delivered_at': null,
        'read_at': null,
        'isPending': true,
      };
      _sendMessageToBoth(newMessage);
    } else {
      setState(() {
        _interactions.add({
          'type': type,
          'storyUser': data['storyUser'],
          'content': data['content'],
          'timestamp': data['timestamp'],
        });
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadMessages() async {
    try {
      List<Map<String, dynamic>> messages = await AuthDatabase.instance
          .getMessagesByConversationId(await _getConversationId());
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
              'is_story_reply': message['is_story_reply'] ?? false,
              'story_id': message['story_id'],
            };
          } catch (e) {
            return {
              ...message,
              'message': '[Decryption Failed]',
              'reactions': reactions,
            };
          }
        }
        return {
          ...message,
          'reactions': reactions,
        };
      }).toList();
      if (mounted) setState(() => _messages = decryptedMessages);
      _syncOfflineMessages();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading messages: $e')));
    }
  }

  Future<void> _loadDraft() async {
    final db = await getLocalDb();
    final conversationId = await _getConversationId();
    final drafts = await db.query('drafts',
        where: 'conversation_id = ?', whereArgs: [conversationId]);
    if (drafts.isNotEmpty) {
      setState(() => _draftMessage = drafts.first['content'] as String?);
      _controller.text = _draftMessage ?? '';
    }
  }

  void _saveDraft(String text) async {
    final db = await getLocalDb();
    final conversationId = await _getConversationId();
    await db.insert(
        'drafts', {'conversation_id': conversationId, 'content': text},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _draftMessage = text;
  }

void _sendMessage() async {
  if (_isSending) return;
  _isSending = true;
  final plaintext = _controller.text.trim();
  if (plaintext.isEmpty) {
    _isSending = false;
    return;
  }

  await _ensureConversationExists();
  final iv = encrypt.IV.fromSecureRandom(16);
  final encryptedText = _encrypter.encrypt(plaintext, iv: iv).base64;

  final message = {
    'id': const Uuid().v4(),
    'sender_id': widget.currentUser['id'].toString(),
    'receiver_id': widget.otherUser['id'].toString(),
    'conversation_id': await _getConversationId(),
    'message': encryptedText,
    'iv': base64Encode(iv.bytes),
    'created_at': DateTime.now().toIso8601String(),
    'is_read': false,
    'is_pinned': false,
    'replied_to': _replyingToMessageId,
    'type': 'text',
    'reactions': {},
    'status': 'pending',
    'delivered_at': null,
    'read_at': null,
    'isPending': true,
  };

  setState(() {
    _messages.add({...message, 'message': plaintext, 'status': 'pending'});
    _scrollToBottom();
  });

  try {
    await _sendMessageToBoth(message);
    setState(() {
      final index = _messages.indexWhere((m) => m['id'] == message['id']);
      if (index != -1) _messages[index]['status'] = 'sent';
    });
    _controller.clear();
    _saveDraft('');
    setState(() => _replyingToMessageId = null);
  } catch (e) {
    setState(() {
      final index = _messages.indexWhere((m) => m['id'] == message['id']);
      if (index != -1) _messages[index]['status'] = 'failed';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to send message: $e')),
    );
  } finally {
    _isSending = false;
  }
}

Future<void> _sendMessageToBoth(Map<String, dynamic> message) async {
  final connectivityResult = await Connectivity().checkConnectivity();
  bool isOffline = !connectivityResult.contains(ConnectivityResult.wifi) &&
      !connectivityResult.contains(ConnectivityResult.mobile);

  // Ensure conversation_id is valid
  if (message['conversation_id'] == null || message['conversation_id'].isEmpty) {
    message['conversation_id'] = await _getConversationId();
  }

  if (isOffline) {
    final db = await getLocalDb();
    await db.insert(
      'offline_messages',
      {
        'id': message['id'],
        'data': jsonEncode(message),
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // Overwrite duplicates
    );
    setState(() {
      final index = _messages.indexWhere((m) => m['id'] == message['id']);
      if (index != -1) _messages[index]['status'] = 'queued';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message queued due to no internet')),
    );
    return;
  }

  try {
    final conversationId = message['conversation_id'];
    if (conversationId.isEmpty) {
      throw Exception('Conversation ID cannot be empty');
    }

    final batch = _firestore.batch();
    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(message['id']);
    final convoRef = _firestore.collection('conversations').doc(conversationId);

    batch.set(messageRef, {
      'id': message['id'],
      'sender_id': message['sender_id'],
      'receiver_id': message['receiver_id'],
      'conversation_id': conversationId,
      'message': message['message'],
      'iv': message['iv'],
      'timestamp': FieldValue.serverTimestamp(),
      'is_read': message['is_read'] == true,
      'is_pinned': message['is_pinned'] == true,
      'replied_to': message['replied_to'],
      'type': message['type'],
      'reactions': message['reactions'] ?? {},
      'delivered_at': message['delivered_at'],
      'read_at': message['read_at'],
      'scheduled_at': message['scheduled_at'],
      'delete_after': message['delete_after'],
      'is_story_reply': message['is_story_reply'] ?? false,
      'story_id': message['story_id'],
    });

    batch.set(
      convoRef,
      {
        'participants': [
          widget.currentUser['id'].toString(),
          widget.otherUser['id'].toString(),
        ],
        'last_message': message['type'] == 'text' ? '[Encrypted]' : message['type'],
        'timestamp': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    await AuthDatabase.instance.createMessage(message);
    await AuthDatabase.instance.updateMessage({
      'id': message['id'],
      'conversation_id': message['conversation_id'],
      'firestore_id': message['id'],
      'delivered_at': DateTime.now().toIso8601String(),
      'status': 'sent',
    });

    setState(() {
      final index = _messages.indexWhere((m) => m['id'] == message['id']);
      if (index != -1) {
        _messages[index] = {
          ..._messages[index],
          'firestore_id': message['id'],
          'isPending': false,
          'status': 'sent',
          'is_story_reply': message['is_story_reply'] ?? false,
          'story_id': message['story_id'],
        };
      }
    });

    _showNotification(message);
  } catch (e) {
    final db = await getLocalDb();
    await db.insert(
      'offline_messages',
      {
        'id': message['id'],
        'data': jsonEncode(message),
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // Overwrite duplicates
    );
    setState(() {
      final index = _messages.indexWhere((m) => m['id'] == message['id']);
      if (index != -1) _messages[index]['status'] = 'queued';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Message queued for sending: $e')),
    );
  }
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
          const SnackBar(content: Text('Microphone permission denied')));
    }
  }

  Future<void> _stopRecording() async {
    await _recorder!.stopRecorder();
    setState(() => _isRecording = false);
    _animationController?.reset();
    if (_audioPath != null) {
      final audioUrl = await _uploadFile(File(_audioPath!), 'audio');
      final message = {
        'id': const Uuid().v4(),
        'sender_id': widget.currentUser['id'].toString(),
        'receiver_id': widget.otherUser['id'].toString(),
        'conversation_id': await _getConversationId(),
        'message': audioUrl,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'is_pinned': false,
        'replied_to': _replyingToMessageId,
        'type': 'audio',
        'reactions': {},
        'status': 'pending',
        'delivered_at': null,
        'read_at': null,
        'isPending': true,
      };
      await _ensureConversationExists();
      _sendMessageToBoth(message);
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
      final message = {
        'id': const Uuid().v4(),
        'sender_id': widget.currentUser['id'].toString(),
        'receiver_id': widget.otherUser['id'].toString(),
        'conversation_id': await _getConversationId(),
        'message': fileUrl,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'is_pinned': false,
        'replied_to': _replyingToMessageId,
        'type': fileType,
        'reactions': {},
        'status': 'pending',
        'delivered_at': null,
        'read_at': null,
        'isPending': true,
      };
      await _ensureConversationExists();
      _sendMessageToBoth(message);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
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

      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'url': 'stun:stun.l.google.com:19302'},
        ]
      });

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideo,
      });

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      final callId = const Uuid().v4();
      _currentCallId = callId;
      await _firestore.collection('calls').doc(callId).set({
        'caller_id': widget.currentUser['id'].toString(),
        'receiver_id': widget.otherUser['id'].toString(),
        'offer': offer.toMap(),
        'is_video': isVideo,
        'status': 'ringing',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _callSubscription = _firestore
          .collection('calls')
          .doc(callId)
          .snapshots()
          .listen((snapshot) async {
        final data = snapshot.data();
        if (data != null) {
          if (data['answer'] != null) {
            RTCSessionDescription answer = RTCSessionDescription(
              data['answer']['sdp'],
              data['answer']['type'],
            );
            await _peerConnection!.setRemoteDescription(answer);
          } else if (data['status'] == 'ended') {
            _endCall();
          }
        }
      });

      _peerConnection!.onIceCandidate = (candidate) {
        _firestore
            .collection('calls')
            .doc(callId)
            .collection('candidates')
            .add({
          'candidate': candidate.toMap(),
          'is_caller': true,
        });
      };

      _candidatesSubscription = _firestore
          .collection('calls')
          .doc(callId)
          .collection('candidates')
          .where('is_caller', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        for (var doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            RTCIceCandidate candidate = RTCIceCandidate(
              doc.doc['candidate']['candidate'],
              doc.doc['candidate']['sdpMid'],
              doc.doc['candidate']['sdpMLineIndex'],
            );
            _peerConnection!.addCandidate(candidate);
          }
        }
      });

      _peerConnection!.onAddStream = (stream) {
        setState(() => _remoteStream = stream);
      };
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions denied for call')));
    }
  }

  void _showCallDialog(String callId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Incoming ${data['is_video'] ? 'Video' : 'Audio'} Call'),
        content: Text('From ${widget.otherUser['username']}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _firestore
                  .collection('calls')
                  .doc(callId)
                  .update({'status': 'ended'});
            },
            child: const Text('Reject'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _acceptCall(callId, data['offer'], data['is_video']);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptCall(
      String callId, Map<String, dynamic> offerData, bool isVideo) async {
    setState(() {
      _isInCall = true;
      _isVideoCall = isVideo;
      _currentCallId = callId;
    });

    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ]
    });

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo,
    });

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    RTCSessionDescription offer = RTCSessionDescription(
      offerData['sdp'],
      offerData['type'],
    );
    await _peerConnection!.setRemoteDescription(offer);

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _firestore.collection('calls').doc(callId).update({
      'answer': answer.toMap(),
      'status': 'connected',
    });

    _peerConnection!.onIceCandidate = (candidate) {
      _firestore.collection('calls').doc(callId).collection('candidates').add({
        'candidate': candidate.toMap(),
        'is_caller': false,
      });
    };

    _candidatesSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .collection('candidates')
        .where('is_caller', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          RTCIceCandidate candidate = RTCIceCandidate(
            doc.doc['candidate']['candidate'],
            doc.doc['candidate']['sdpMid'],
            doc.doc['candidate']['sdpMLineIndex'],
          );
          _peerConnection!.addCandidate(candidate);
        }
      }
    });

    _peerConnection!.onAddStream = (stream) {
      setState(() => _remoteStream = stream);
    };

    _callSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data != null && data['status'] == 'ended') {
        _endCall();
      }
    });
  }

  void _endCall() async {
    await _peerConnection?.close();
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    if (_currentCallId != null) {
      await _firestore.collection('calls').doc(_currentCallId).update({
        'status': 'ended',
      });
    }
    _callSubscription?.cancel();
    _candidatesSubscription?.cancel();
    setState(() {
      _isInCall = false;
      _localStream = null;
      _remoteStream = null;
      _currentCallId = null;
    });
  }

  void _markMessageAsRead(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final message = Map<String, dynamic>.from(_messages[index]);
    if (message['is_read'] == true) return;
    final updatedMessage = {
      'id': message['id'].toString(),
      'conversation_id': message['conversation_id'].toString(),
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    };
    try {
      await AuthDatabase.instance.updateMessage(updatedMessage);
      if (message['firestore_id'] != null) {
        final conversationId = await _getConversationId();
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(message['firestore_id'])
            .update({
          'is_read': true,
          'read_at': FieldValue.serverTimestamp(),
        });
      }
      setState(() {
        _messages[index]['is_read'] = true;
        _messages[index]['read_at'] = DateTime.now().toIso8601String();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking message as read: $e')));
    }
  }

  void _markAllMessagesAsRead() {
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i]['sender_id'] == widget.otherUser['id'].toString() &&
          _messages[i]['is_read'] == false) {
        _markMessageAsRead(i);
      }
    }
  }

Future<void> _syncOfflineMessages() async {
  final db = await getLocalDb();
  final offlineMessages = await db.query('offline_messages');
  if (offlineMessages.isEmpty) return;

  // Wait for network stability (optional, adjust as needed)
  await Future.delayed(const Duration(seconds: 1));

  for (var msg in offlineMessages) {
    final message = jsonDecode(msg['data'] as String) as Map<String, dynamic>;
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        await _sendMessageToBoth(message);
        await db.delete('offline_messages',
            where: 'id = ?', whereArgs: [msg['id']]);
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == message['id']);
          if (index != -1) _messages[index]['status'] = 'sent';
        });
      }
    } catch (e) {
      debugPrint('Failed to sync offline message ${msg['id']}: $e');
      // Leave message in queue for next sync attempt
    }
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

  Future<void> _loadBackgroundSettings() async {
    final db = await getLocalDb();
    final conversationId = await _getConversationId();
    final settings = await db.query('chat_settings',
        where: 'conversation_id = ?', whereArgs: [conversationId]);
    if (settings.isNotEmpty) {
      final setting = settings.first;
      setState(() {
        if (setting['bg_color'] != null) {
          _chatBgColor = Color(setting['bg_color'] as int);
        }
        _chatBgImage = setting['bg_image'] as String?;
        _cinematicTheme = setting['cinematic_theme'] as String?;
      });
    }
  }

  void _updateChatBackground(
      {Color? color, String? imageUrl, String? cinematicTheme}) async {
    final db = await getLocalDb();
    final conversationId = await _getConversationId();
    final currentSettings = await db.query('chat_settings',
        where: 'conversation_id = ?', whereArgs: [conversationId]);

    Map<String, dynamic> settings = currentSettings.isNotEmpty
        ? currentSettings.first
        : {'conversation_id': conversationId};

    if (color != null) {
      settings['bg_color'] = color.value;
      setState(() => _chatBgColor = color);
    }
    if (imageUrl != null) {
      settings['bg_image'] = imageUrl;
      setState(() => _chatBgImage = imageUrl);
    }
    if (cinematicTheme != null) {
      settings['cinematic_theme'] = cinematicTheme;
      setState(() => _cinematicTheme = cinematicTheme);
    }

    await db.insert(
      'chat_settings',
      settings,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void _deleteMessage(int index) async {
    final message = _messages[index];
    final messageId = message['id'].toString();
    try {
      await AuthDatabase.instance.deleteMessage(messageId);
      if (message['firestore_id'] != null) {
        final conversationId = await _getConversationId();
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(message['firestore_id'])
            .delete();
      }
      setState(() => _messages.removeAt(index));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting message: $e')));
    }
  }

  void _toggleReadStatus(int index) async {
    final message = Map<String, dynamic>.from(_messages[index]);
    final isRead = message['is_read'] == true;
    final updatedMessage = {
      'id': message['id'].toString(),
      'conversation_id': message['conversation_id'].toString(),
      'is_read': !isRead,
      'read_at': !isRead ? DateTime.now().toIso8601String() : null,
    };
    try {
      await AuthDatabase.instance.updateMessage(updatedMessage);
      if (message['firestore_id'] != null) {
        final conversationId = await _getConversationId();
        await _firestore
            .collection('conversations')
            .doc(conversationId)
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating read status: $e')));
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
      'conversation_id': message['conversation_id'].toString(),
      'is_pinned': !isPinned
    };
    try {
      await AuthDatabase.instance.updateMessage(updatedMessage);
      if (message['firestore_id'] != null) {
        final conversationId = await _getConversationId();
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(message['firestore_id'])
            .update({'is_pinned': !isPinned});
      }
      setState(() => _messages[index]['is_pinned'] = !isPinned);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error pinning message: $e')));
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
     await AuthDatabase.instance.updateMessage({
  'id': messageId,
  'conversation_id': message['conversation_id'].toString(),  // Add this
  'reactions': reactions
});
      if (message['firestore_id'] != null) {
        final conversationId = await _getConversationId();
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(message['firestore_id'])
            .update({'reactions': reactions});
      }
      setState(() => message['reactions'] = reactions);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error adding reaction: $e')));
    }
  }

  void _forwardMessage(Map<String, dynamic> message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forwarding message: ${message['message']}')));
  }

  void _scheduleMessage(String text, DateTime time) async {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encryptedText = _encrypter.encrypt(text, iv: iv).base64;
    final message = {
      'id': const Uuid().v4(),
      'sender_id': widget.currentUser['id'].toString(),
      'receiver_id': widget.otherUser['id'].toString(),
      'conversation_id': await _getConversationId(),
      'message': encryptedText,
      'iv': base64Encode(iv.bytes),
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
      'is_pinned': false,
      'replied_to': _replyingToMessageId,
      'type': 'text',
      'reactions': {},
      'scheduled_at': time.toIso8601String(),
      'status': 'pending',
      'delivered_at': null,
      'read_at': null,
      'isPending': true,
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
        final conversationId = await _getConversationId();
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(message['firestore_id'])
            .update({'delete_after': deleteTime.toIso8601String()});
      }
      setState(() => message['delete_after'] = deleteTime.toIso8601String());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting auto-delete: $e')));
    }
  }

  List<Map<String, dynamic>> _searchMessages() {
    if (_searchTerm.isEmpty) return _messages;
    return _messages.where((message) {
      final msgText = message['message'].toString().toLowerCase();
      return msgText.contains(_searchTerm.toLowerCase());
    }).toList();
  }

  void _openStoryScreen() {
    final otherUserStories = [
      {
        'id': const Uuid().v4(),
        'user': widget.otherUser['username']?.toString() ?? 'Unknown',
        'userId': widget.otherUser['id'].toString(),
        'type': 'image',
        'media': 'https://via.placeholder.com/300',
        'timestamp': DateTime.now().toIso8601String(),
      },
    ];
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => StoryScreen(
                stories: otherUserStories,
                currentUserId: widget.currentUser['id'].toString(),
                onStoryInteraction: _handleStoryInteraction)));
  }

  void _showNotification(Map<String, dynamic> message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails('chat_channel', 'Chat Notifications',
            importance: Importance.max, priority: Priority.high);
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);
    String notificationText = 'New ${message['type']} message';
    String title = 'New Message from ${widget.otherUser['username']}';
    await _notificationsPlugin.show(
      0,
      title,
      notificationText,
      notificationDetails,
    );
  }

  void _updateTypingStatus(bool isTyping) async {
    final conversationId = await _getConversationId();
    final userId = widget.currentUser['id'].toString();
    if (isTyping) {
      await _firestore.collection('conversations').doc(conversationId).set({
        'typing_users': FieldValue.arrayUnion([userId])
      }, SetOptions(merge: true));
    } else {
      await _firestore.collection('conversations').doc(conversationId).update({
        'typing_users': FieldValue.arrayRemove([userId])
      });
    }
  }

  @override
  void dispose() {
    _typingSubscription?.cancel();
    _messagesSubscription?.cancel();
    _recorder?.closeRecorder();
    _connectivitySubscription?.cancel();
    _callsSubscription?.cancel();
    _callSubscription?.cancel();
    _candidatesSubscription?.cancel();
    _peerConnection?.close();
    _localStream?.dispose();
    _remoteStream?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _animationController?.dispose();
    _audioPlayer.dispose();
    _typingTimer?.cancel();
    _localDb?.close();
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

  Widget _buildProfileAvatar() {
    final profilePicture = widget.otherUser['profile_picture']?.toString();
    final username = widget.otherUser['username']?.toString() ?? '';
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : 'U';

    if (profilePicture != null && profilePicture.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: profilePicture,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => CircleAvatar(
          backgroundColor: Colors.deepPurple,
          child: Text(firstLetter, style: const TextStyle(color: Colors.white)),
        ),
        imageBuilder: (context, imageProvider) =>
            CircleAvatar(backgroundImage: imageProvider),
      );
    } else {
      return CircleAvatar(
        backgroundColor: Colors.deepPurple,
        child: Text(firstLetter, style: const TextStyle(color: Colors.white)),
      );
    }
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
    if (isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return "Yesterday";
    }
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(date);
  }

  Color _getTextColor() {
    if (_chatBgImage != null || _cinematicTheme != null) {
      return Colors.white;
    }
    final luminance = _chatBgColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
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
      ..._interactions.map((i) => {
            'type': 'interaction',
            'data': i,
            'timestamp': i['timestamp'] is DateTime
                ? i['timestamp']
                : DateTime.parse(i['timestamp'].toString()),
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
                  style: TextStyle(
                      color: _getTextColor(), fontWeight: FontWeight.bold))));
        }
        listWidgets.add(MessageWidget(
          message: item['data'],
          isMe: item['data']['sender_id'] == widget.currentUser['id'],
          repliedToText: item['replied_to_text'],
          onReply: () => _replyToMessage(_messages.indexOf(item['data'])),
          onShare: () => _forwardMessage(item['data']),
          onLongPress: () => _showMessageOptions(context, item['data']),
          onTapOriginal: () {
            final originalMessage = _messages.firstWhere(
                (m) => m['id'] == item['data']['replied_to'],
                orElse: () => {});
            if (originalMessage.isNotEmpty) {
              final index = _messages.indexOf(originalMessage);
              if (index != -1) {
                _scrollController.animateTo(index * 100.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut);
              }
            }
          },
          onDelete: () => _deleteMessage(_messages.indexOf(item['data'])),
          audioPlayer: _audioPlayer,
          setCurrentlyPlaying: (id) => setState(() => _currentlyPlayingId = id),
          currentlyPlayingId: _currentlyPlayingId,
          encrypter: _encrypter,
          isRead: item['data']['is_read'] == true,
          isStoryReply: item['data']['is_story_reply'] == true,
        ));
      } else {
        listWidgets.add(ListTile(
          leading: const Icon(Icons.notifications, color: Colors.deepPurple),
          title: Text(
              item['data']['type'] == 'like'
                  ? "You liked their story"
                  : item['data']['type'] == 'share'
                      ? "You shared their story"
                      : "Unknown interaction",
              style: TextStyle(color: _getTextColor())),
          subtitle: Text(
              DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
                  .add_jm()
                  .format(item['timestamp']),
              style: TextStyle(color: _getTextColor().withOpacity(0.7))),
        ));
      }
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: Row(
          children: [
            IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              height: 40,
              child: _buildProfileAvatar(),
            ),
          ],
        ),
        leadingWidth: 100,
        title: Text(widget.otherUser['username']?.toString() ?? 'User'),
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
              } else if (value == 'stories') {
                _openStoryScreen();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                  value: 'change_background', child: Text('Change Background')),
              PopupMenuItem<String>(
                  value: 'search', child: Text('Search Messages')),
              PopupMenuItem<String>(
                  value: 'stories', child: Text('View Stories')),
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
              remoteStream: _remoteStream,
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
                        Text('Pinned Messages',
                            style: TextStyle(
                                color: _getTextColor(),
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
                            pinnedText = '[Decryption Failed]';
                          }
                          return ListTile(
                            title: Text(pinnedText,
                                style: TextStyle(color: _getTextColor())),
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
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: listWidgets.length,
                    itemBuilder: (context, index) => listWidgets[index],
                    cacheExtent: 1000.0,
                  ),
                ),
                if (_isOtherTyping)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(children: [
                      const SizedBox(width: 8),
                      const CircularProgressIndicator(),
                      const SizedBox(width: 8),
                      Text('${widget.otherUser['username']} is typing...',
                          style: TextStyle(color: _getTextColor()))
                    ]),
                  ),
                Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
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
                                decoration: InputDecoration(
                                  hintText: "Type a message...",
                                  hintStyle:
                                      const TextStyle(color: Colors.white54),
                                  border: const OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(20)),
                                      borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: Colors.black26,
                                  suffixIcon: _isSending
                                      ? const CircularProgressIndicator()
                                      : null,
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
                                    onPressed:
                                        _isSending ? null : _sendMessage),
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
                              config: const Config(
                                emojiViewConfig: EmojiViewConfig(
                                  backgroundColor: Colors.white,
                                ),
                                categoryViewConfig: CategoryViewConfig(
                                  iconColorSelected: Colors.deepPurple,
                                ),
                              ),
                            ),
                          )
                      ],
                    ),
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
  final MediaStream? remoteStream;
  final bool isVideo;
  final VoidCallback onEnd;

  const WebRTCCallWidget({
    super.key,
    required this.localStream,
    required this.remoteStream,
    required this.isVideo,
    required this.onEnd,
  });

  @override
  _WebRTCCallWidgetState createState() => _WebRTCCallWidgetState();
}

class _WebRTCCallWidgetState extends State<WebRTCCallWidget> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isMuted = false;
  bool _isCameraOn = true;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (widget.localStream != null) {
      _localRenderer.srcObject = widget.localStream;
    }
    if (widget.remoteStream != null) {
      _remoteRenderer.srcObject = widget.remoteStream;
    }
  }

  @override
  void didUpdateWidget(covariant WebRTCCallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.localStream != oldWidget.localStream) {
      _localRenderer.srcObject = widget.localStream;
    }
    if (widget.remoteStream != oldWidget.remoteStream) {
      _remoteRenderer.srcObject = widget.remoteStream;
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      widget.localStream?.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
    });
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
      widget.localStream?.getVideoTracks().forEach((track) {
        track.enabled = _isCameraOn;
      });
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          if (widget.isVideo && widget.remoteStream != null)
            RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          if (widget.isVideo && widget.localStream != null)
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(_isMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white),
                    onPressed: _toggleMute,
                  ),
                  if (widget.isVideo)
                    IconButton(
                      icon: Icon(
                          _isCameraOn ? Icons.videocam : Icons.videocam_off,
                          color: Colors.white),
                      onPressed: _toggleCamera,
                    ),
                  ElevatedButton(
                    onPressed: widget.onEnd,
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('End Call',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
