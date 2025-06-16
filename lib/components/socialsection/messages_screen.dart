import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/database/auth_database.dart';
import 'package:movie_app/settings_provider.dart';
import 'chat_screen.dart';
import 'GroupChatScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';

class MessagesScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<Map<String, dynamic>> otherUsers;

  const MessagesScreen({
    super.key,
    required this.currentUser,
    required this.otherUsers,
  });

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _conversations = [];
  StreamSubscription<QuerySnapshot>? _convoSubscription;
  String? _errorMessage;
  late Map<String, Map<String, dynamic>> _userMap;

  @override
  void initState() {
    super.initState();
    _userMap = {
      for (var user in widget.otherUsers) user['id'].toString(): user
    };
    _loadConversations();
    _setupFirestoreListener();
  }

  @override
  void dispose() {
    _convoSubscription?.cancel();
    super.dispose();
  }

  // Helper method to safely check if a user is in a list
  bool _isUserInList(dynamic list, String userId) {
    return list is List && list.contains(userId);
  }

  // Helper method to generate an encrypter for a specific conversation ID
  encrypt.Encrypter _getEncrypter(String conversationId) {
    final keyBytes = sha256.convert(utf8.encode(conversationId)).bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    return encrypt.Encrypter(encrypt.AES(key));
  }

  Future<void> _loadConversations() async {
    try {
      final convos = await AuthDatabase.instance
          .getConversationsForUser(widget.currentUser['id']);
      final userMap = <String, Map<String, dynamic>>{};

      final allParticipantIds = <String>{};
      for (var convo in convos) {
        final participantIds = (convo['participants'] as List?)
                ?.map((id) => id.toString())
                .toList() ??
            [];
        allParticipantIds.addAll(participantIds);
      }

      for (var id in allParticipantIds) {
        if (!userMap.containsKey(id)) {
          final user = await AuthDatabase.instance.getUserById(id);
          userMap[id] = user ?? {'id': id, 'username': 'Unknown'};
        }
      }

      final convosWithDetails = await Future.wait(convos.map((convo) async {
        final participantIds = (convo['participants'] as List?)
                ?.map((id) => id.toString())
                .toList() ??
            [];
        final participantsData =
            participantIds.map((id) => userMap[id]!).toList();
        final unreadCount = await AuthDatabase.instance
            .getUnreadCount(convo['id'], widget.currentUser['id']);
        if (unreadCount > 0) {
          await AuthDatabase.instance.syncMessagesForConversation(convo['id']);
        }
        final lastMessageData = await _getLastMessage(convo['id']);
        return {
          ...convo,
          'unread_count': unreadCount,
          'participantsData': participantsData,
          'last_message': lastMessageData['message'] ?? 'No messages yet',
          'last_message_sender': lastMessageData['sender_username'] ?? '',
          'last_message_is_read': lastMessageData['is_read'] ?? false,
          'last_message_timestamp':
              lastMessageData['timestamp'] ?? DateTime.now(),
        };
      }).toList());

      if (mounted) {
        setState(() {
          _conversations = convosWithDetails;
          _userMap = userMap;
          _errorMessage = null;

          final pinnedConvos = _conversations
              .where((convo) => _isUserInList(
                  convo['pinned_users'], widget.currentUser['id']))
              .toList();
          final nonPinnedConvos = _conversations
              .where((convo) => !_isUserInList(
                  convo['pinned_users'], widget.currentUser['id']))
              .toList();

          pinnedConvos.sort((a, b) => b['last_message_timestamp']
              .compareTo(a['last_message_timestamp']));
          nonPinnedConvos.sort((a, b) => b['last_message_timestamp']
              .compareTo(a['last_message_timestamp']));

          _conversations = [...pinnedConvos, ...nonPinnedConvos];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load conversations: $e';
        });
      }
    }
  }

  Future<Map<String, dynamic>> _getLastMessage(String convoId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(convoId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final messageData = snapshot.docs.first.data();
        String messageText = messageData['message'];
        if (messageData['type'] == 'text' && messageData['iv'] != null) {
          try {
            final iv = encrypt.IV.fromBase64(messageData['iv']);
            final encrypter = _getEncrypter(convoId);
            messageText = encrypter.decrypt64(messageText, iv: iv);
          } catch (e) {
            debugPrint('Error decrypting message: $e');
            messageText = '[Decryption Failed]';
          }
        }
        final senderId = messageData['sender_id'].toString();
        final senderUsername = _userMap[senderId]?['username'] ?? 'Unknown';
        final isRead = messageData['is_read'] ?? false;
        return {
          'message': messageText,
          'sender_username': senderUsername,
          'is_read': isRead,
          'timestamp': (messageData['timestamp'] as Timestamp).toDate(),
        };
      }
      return {};
    } catch (e) {
      debugPrint('Error fetching last message: $e');
      return {};
    }
  }

  void _setupFirestoreListener() {
    try {
      String userId = widget.currentUser['id'].toString();
      _convoSubscription = FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .snapshots()
          .listen((snapshot) async {
        if (!snapshot.metadata.hasPendingWrites) {
          final convos = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'type': data['type'] ?? 'direct',
              'group_name': data['group_name'],
              'participants': (data['participants'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
              'username': data['username'],
              'user_id': data['user_id'],
              'last_message': data['last_message'],
              'timestamp': (data['timestamp'] as Timestamp?)
                      ?.toDate()
                      .toIso8601String() ??
                  '',
              'muted_users': (data['muted_users'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
              'blocked_users': (data['blocked_users'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
              'pinned_users': (data['pinned_users'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
            };
          }).toList();
          await _updateLocalDatabase(convos);
          _loadConversations();
          if (mounted) {
            setState(() => _errorMessage = null);
          }
        }
      }, onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Firestore error: $error';
          });
          _loadConversations();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to set up listener: $e';
        });
        _loadConversations();
      }
    }
  }

  Future<void> _updateLocalDatabase(List<Map<String, dynamic>> convos) async {
    try {
      await AuthDatabase.instance
          .clearConversationsForUser(widget.currentUser['id']);
      for (var convo in convos) {
        await AuthDatabase.instance.insertConversation({
          'id': convo['id'],
          'type': convo['type'],
          'group_name': convo['group_name'],
          'participants': convo['participants'] is List
              ? List.from(convo['participants'])
              : [],
          'username': convo['username'],
          'user_id': convo['user_id'],
          'last_message': convo['last_message'],
          'timestamp': convo['timestamp'],
          'muted_users': convo['muted_users'] is List
              ? List.from(convo['muted_users'])
              : [],
          'blocked_users': convo['blocked_users'] is List
              ? List.from(convo['blocked_users'])
              : [],
          'pinned_users': convo['pinned_users'] is List
              ? List.from(convo['pinned_users'])
              : [],
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to update local database: $e');
      }
    }
  }

  Future<String> _getConversationName(Map<String, dynamic> convo) async {
    if (convo['type'] == 'group') {
      return convo['group_name'] ?? 'Group Chat';
    }
    final userId = convo['user_id']?.toString();
    if (userId == null) return 'Unknown';
    final user =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return user.exists ? (user.data()?['username'] ?? 'Unknown') : 'Unknown';
  }

  void _showConversationOptions(
      BuildContext context, Map<String, dynamic> convo) {
    final isPinned =
        _isUserInList(convo['pinned_users'], widget.currentUser['id']);
    final isMuted =
        _isUserInList(convo['muted_users'], widget.currentUser['id']);
    final isBlocked =
        _isUserInList(convo['blocked_users'], widget.currentUser['id']);

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(isPinned ? 'Unpin' : 'Pin'),
            onTap: () {
              Navigator.pop(context);
              _togglePinConversation(convo);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              _deleteConversation(convo);
            },
          ),
          ListTile(
            leading: Icon(
                isMuted ? Icons.notifications_active : Icons.notifications_off),
            title:
                Text(isMuted ? 'Unmute Notifications' : 'Mute Notifications'),
            onTap: () {
              Navigator.pop(context);
              _toggleMuteConversation(convo);
            },
          ),
          if (convo['type'] == 'direct')
            ListTile(
              leading: Icon(isBlocked ? Icons.lock_open : Icons.block),
              title: Text(isBlocked ? 'Unblock' : 'Block'),
              onTap: () {
                Navigator.pop(context);
                _toggleBlockConversation(convo);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _togglePinConversation(Map<String, dynamic> convo) async {
    try {
      final userId = widget.currentUser['id'].toString();
      final pinnedUsers = List<String>.from(convo['pinned_users'] ?? []);
      if (pinnedUsers.contains(userId)) {
        pinnedUsers.remove(userId);
      } else {
        pinnedUsers.add(userId);
      }
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(convo['id'])
          .update({'pinned_users': pinnedUsers});
      await AuthDatabase.instance
          .updateConversation({'id': convo['id'], 'pinned_users': pinnedUsers});
      _loadConversations();
    } catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to pin/unpin: $error')));
    }
  }

  Future<void> _deleteConversation(Map<String, dynamic> convo) async {
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(convo['id'])
          .delete();
      await AuthDatabase.instance.deleteConversation(convo['id']);
      _loadConversations();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> _toggleMuteConversation(Map<String, dynamic> convo) async {
    try {
      final userId = widget.currentUser['id'].toString();
      final mutedUsers = List<String>.from(convo['muted_users'] ?? []);
      if (mutedUsers.contains(userId)) {
        mutedUsers.remove(userId);
      } else {
        mutedUsers.add(userId);
      }
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(convo['id'])
          .update({'muted_users': mutedUsers});
      await AuthDatabase.instance.muteConversation(convo['id'], mutedUsers);
      _loadConversations();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to mute/unmute: $e')));
    }
  }

  Future<void> _toggleBlockConversation(Map<String, dynamic> convo) async {
    try {
      final userId = widget.currentUser['id'].toString();
      final blockedUsers = List<String>.from(convo['blocked_users'] ?? []);
      if (blockedUsers.contains(userId)) {
        blockedUsers.remove(userId);
      } else {
        blockedUsers.add(userId);
      }
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(convo['id'])
          .update({'blocked_users': blockedUsers});
      await AuthDatabase.instance.blockConversation(convo['id'], blockedUsers);
      _loadConversations();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to block/unblock: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Provider.of<SettingsProvider>(context).accentColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: accentColor.withOpacity(0.1),
        elevation: 0,
        title: const Text("Messages",
            style: TextStyle(color: Colors.white, shadows: [
              Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 4)
            ])),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewChatScreen(
                    currentUser: widget.currentUser,
                    otherUsers: widget.otherUsers,
                    accentColor: accentColor,
                  ),
                ),
              ).then((_) => _loadConversations());
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.redAccent, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.06, -0.34),
                  radius: 1.0,
                  colors: [
                    accentColor.withOpacity(0.5),
                    const Color.fromARGB(255, 0, 0, 0)
                  ],
                  stops: const [0.0, 0.59],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.64, 0.3),
                  radius: 1.0,
                  colors: [accentColor.withOpacity(0.3), Colors.transparent],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [accentColor.withOpacity(0.3), Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(160, 17, 19, 40),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        border: Border(
                          top: BorderSide(
                              color: Color.fromRGBO(255, 255, 255, 0.125)),
                          bottom: BorderSide(
                              color: Color.fromRGBO(255, 255, 255, 0.125)),
                          left: BorderSide(
                              color: Color.fromRGBO(255, 255, 255, 0.125)),
                          right: BorderSide(
                              color: Color.fromRGBO(255, 255, 255, 0.125)),
                        ),
                      ),
                      child: _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 16,
                                        shadows: [
                                          Shadow(
                                              color: Colors.black54,
                                              offset: Offset(2, 2),
                                              blurRadius: 4)
                                        ]),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () {
                                      _loadConversations();
                                      _setupFirestoreListener();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    child: const Text("Retry",
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            )
                          : _conversations.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "No conversations yet.",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            shadows: [
                                              Shadow(
                                                  color: Colors.black54,
                                                  offset: Offset(2, 2),
                                                  blurRadius: 4)
                                            ]),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  NewChatScreen(
                                                currentUser: widget.currentUser,
                                                otherUsers: widget.otherUsers,
                                                accentColor: accentColor,
                                              ),
                                            ),
                                          ).then((_) => _loadConversations());
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentColor,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text("Start a Chat",
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16.0),
                                  itemCount: _conversations.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final convo = _conversations[index];
                                    final isMuted = _isUserInList(
                                        convo['muted_users'],
                                        widget.currentUser['id']);
                                    final isPinned = _isUserInList(
                                        convo['pinned_users'],
                                        widget.currentUser['id']);
                                    final isBlocked = _isUserInList(
                                        convo['blocked_users'],
                                        widget.currentUser['id']);
                                    final unreadCount =
                                        convo['unread_count'] ?? 0;
                                    final timestampString =
                                        convo['timestamp']?.toString() ?? '';
                                    String formattedTime = '';
                                    if (timestampString.isNotEmpty) {
                                      try {
                                        final timestamp =
                                            DateTime.parse(timestampString);
                                        final now = DateTime.now();
                                        if (timestamp.day == now.day &&
                                            timestamp.month == now.month &&
                                            timestamp.year == now.year) {
                                          formattedTime = DateFormat('h:mm a')
                                              .format(timestamp);
                                        } else {
                                          formattedTime = DateFormat('MMM d')
                                              .format(timestamp);
                                        }
                                      } catch (e) {
                                        formattedTime = '';
                                      }
                                    }

                                    return GestureDetector(
                                      onLongPress: () =>
                                          _showConversationOptions(
                                              context, convo),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          gradient: LinearGradient(
                                            colors: [
                                              accentColor.withOpacity(
                                                  isBlocked ? 0.1 : 0.2),
                                              accentColor.withOpacity(
                                                  isBlocked ? 0.2 : 0.4),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: accentColor.withOpacity(
                                                  isBlocked ? 0.3 : 0.6),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 8, horizontal: 12),
                                          leading: Stack(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: accentColor,
                                                radius: 24,
                                                child: Text(
                                                  convo['type'] == 'group'
                                                      ? (convo['group_name']
                                                                  ?.isNotEmpty ??
                                                              false
                                                          ? convo['group_name']
                                                                  [0]
                                                              .toUpperCase()
                                                          : 'G')
                                                      : (convo['username']
                                                                  ?.isNotEmpty ??
                                                              false
                                                          ? convo['username'][0]
                                                              .toUpperCase()
                                                          : '?'),
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 20),
                                                ),
                                              ),
                                              if (isPinned)
                                                const Positioned(
                                                  top: 0,
                                                  right: 0,
                                                  child: Icon(Icons.push_pin,
                                                      size: 16,
                                                      color: Colors.yellow),
                                                ),
                                            ],
                                          ),
                                          title: FutureBuilder<String>(
                                            future: _getConversationName(convo),
                                            builder: (context, snapshot) {
                                              final name = snapshot.data ??
                                                  (convo['username'] ??
                                                      'Unknown');
                                              return Row(
                                                children: [
                                                  if (isMuted)
                                                    const Icon(
                                                        Icons.notifications_off,
                                                        size: 16,
                                                        color: Colors.white70),
                                                  if (isMuted)
                                                    const SizedBox(width: 4),
                                                  if (isBlocked)
                                                    const Icon(Icons.block,
                                                        size: 16,
                                                        color: Colors.red),
                                                  if (isBlocked)
                                                    const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        shadows: [
                                                          Shadow(
                                                              color: Colors
                                                                  .black54,
                                                              offset:
                                                                  Offset(2, 2),
                                                              blurRadius: 4)
                                                        ],
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          subtitle: Row(
                                            children: [
                                              if (convo['last_message'] !=
                                                  'No messages yet')
                                                Icon(
                                                  convo['last_message_is_read']
                                                      ? Icons.done_all
                                                      : Icons.done,
                                                  size: 16,
                                                  color: convo[
                                                          'last_message_is_read']
                                                      ? Colors.blue
                                                      : Colors.grey,
                                                ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  convo['type'] == 'group'
                                                      ? '${convo['last_message_sender']}: ${convo['last_message']}'
                                                      : convo['last_message']
                                                              ?.toString() ??
                                                          'No messages yet',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 14,
                                                    fontWeight: unreadCount > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    shadows: const [
                                                      Shadow(
                                                          color: Colors.black54,
                                                          offset: Offset(2, 2),
                                                          blurRadius: 4)
                                                    ],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (formattedTime.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 8.0),
                                                  child: Text(
                                                    formattedTime,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white70,
                                                        shadows: [
                                                          Shadow(
                                                              color: Colors
                                                                  .black54,
                                                              offset:
                                                                  Offset(2, 2),
                                                              blurRadius: 4)
                                                        ]),
                                                  ),
                                                ),
                                              if (unreadCount > 0)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Text(
                                                    unreadCount.toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          onTap: () {
                                            if (!isBlocked) {
                                              if (convo['type'] == 'group') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        GroupChatScreen(
                                                      currentUser:
                                                          widget.currentUser,
                                                      conversation: convo,
                                                      participants: convo[
                                                          'participantsData'],
                                                    ),
                                                  ),
                                                ).then((_) =>
                                                    _loadConversations());
                                              } else {
                                                final otherUserId =
                                                    convo['user_id']
                                                            ?.toString() ??
                                                        '';
                                                final otherUserName =
                                                    convo['username']
                                                            ?.toString() ??
                                                        'Unknown';
                                                final otherUser = {
                                                  'id': otherUserId,
                                                  'username': otherUserName
                                                };
                                                debugPrint(
                                                    'Navigating with otherUserId: $otherUserId, username: $otherUserName');
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        IndividualChatScreen(
                                                      currentUser:
                                                          widget.currentUser,
                                                      otherUser: otherUser,
                                                      storyInteractions: [],
                                                    ),
                                                  ),
                                                ).then((_) =>
                                                    _loadConversations());
                                              }
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'This conversation is blocked')),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentColor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewChatScreen(
                currentUser: widget.currentUser,
                otherUsers: widget.otherUsers,
                accentColor: accentColor,
              ),
            ),
          ).then((_) => _loadConversations());
        },
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }
}

class NewChatScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<Map<String, dynamic>> otherUsers;
  final Color accentColor;

  const NewChatScreen({
    super.key,
    required this.currentUser,
    required this.otherUsers,
    required this.accentColor,
  });

  @override
  _NewChatScreenState createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _selectedUsers = [];
  String _groupName = '';
  bool _isGroupChat = false;
  final TextEditingController _groupNameController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _startChat() async {
    try {
      if (_isGroupChat) {
        if (_selectedUsers.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Select at least 2 users for a group chat')),
          );
          return;
        }
        if (_groupName.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a group name')),
          );
          return;
        }
        String convoId = DateTime.now().millisecondsSinceEpoch.toString();
        final participants = [
          widget.currentUser['id'].toString(),
          ..._selectedUsers.map((u) => u['id'].toString())
        ];
        final participantsData = [
          {
            'id': widget.currentUser['id'].toString(),
            'username': widget.currentUser['username'] ?? 'Unknown'
          },
          ..._selectedUsers.map((u) => {
                'id': u['id'].toString(),
                'username': u['username'] ?? 'Unknown'
              })
        ];
        Map<String, dynamic> convoData = {
          'id': convoId,
          'type': 'group',
          'group_name': _groupName,
          'participants': participants,
          'timestamp': FieldValue.serverTimestamp(),
          'muted_users': [],
          'blocked_users': [],
          'pinned_users': [],
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatScreen(
              currentUser: widget.currentUser,
              conversation: convoData,
              participants: participantsData,
            ),
          ),
        );
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(convoId)
            .set(convoData, SetOptions(merge: true));
        await AuthDatabase.instance.insertConversation(
            {...convoData, 'timestamp': DateTime.now().toIso8601String()});
      } else {
        if (_selectedUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select a user to start a chat')),
          );
          return;
        }
        final otherUser = _selectedUser!;
        final otherUserId = otherUser['id'].toString();
        final sortedIds = [widget.currentUser['id'].toString(), otherUserId]
          ..sort();
        String convoId = sortedIds.join('_');
        Map<String, dynamic> convoData = {
          'id': convoId,
          'type': 'direct',
          'participants': [widget.currentUser['id'].toString(), otherUserId],
          'username': otherUser['username'],
          'user_id': otherUserId,
          'timestamp': FieldValue.serverTimestamp(),
          'muted_users': [],
          'blocked_users': [],
          'pinned_users': [],
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IndividualChatScreen(
              currentUser: widget.currentUser,
              otherUser: otherUser,
              storyInteractions: [],
            ),
          ),
        );
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(convoId)
            .set(convoData, SetOptions(merge: true));
        await AuthDatabase.instance.insertConversation(
            {...convoData, 'timestamp': DateTime.now().toIso8601String()});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: widget.accentColor.withOpacity(0.1),
        elevation: 0,
        title: const Text("New Chat",
            style: TextStyle(color: Colors.white, shadows: [
              Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 4)
            ])),
        actions: [
          IconButton(
            icon: Icon(_isGroupChat ? Icons.person : Icons.group,
                color: Colors.white),
            onPressed: () {
              setState(() {
                _isGroupChat = !_isGroupChat;
                _selectedUser = null;
                _selectedUsers.clear();
                _groupName = '';
                _groupNameController.clear();
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.redAccent, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.06, -0.34),
                  radius: 1.0,
                  colors: [
                    widget.accentColor.withOpacity(0.5),
                    const Color.fromARGB(255, 0, 0, 0)
                  ],
                  stops: const [0.0, 0.59],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.64, 0.3),
                  radius: 1.0,
                  colors: [
                    widget.accentColor.withOpacity(0.3),
                    Colors.transparent
                  ],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [
                      widget.accentColor.withOpacity(0.3),
                      Colors.transparent
                    ],
                    stops: const [0.0, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(160, 17, 19, 40),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        border: Border(
                          top: BorderSide(
                              color: Color.fromRGBO(255, 255, 255, 0.125)),
                          bottom: BorderSide(
                              color: Color.fromRGBO(255, 255, 255, 0.125)),
                          left: BorderSide(
                              color: Color.fromRGBO(255, 255, 255, 0.125)),
                          right: BorderSide(
                              color: Color.fromRGBO(255, 255, 255, 0.125)),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_isGroupChat)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: TextField(
                                controller: _groupNameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Group Name',
                                  labelStyle:
                                      const TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (value) => _groupName = value,
                              ),
                            ),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Error fetching users: ${snapshot.error}',
                                      style: const TextStyle(
                                          color: Colors.red,
                                          shadows: [
                                            Shadow(
                                                color: Colors.black54,
                                                offset: Offset(2, 2),
                                                blurRadius: 4)
                                          ]),
                                    ),
                                  );
                                }
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.white));
                                }
                                final users = snapshot.data!.docs
                                    .map((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      return {
                                        'id': doc.id,
                                        'username':
                                            data['username'] ?? 'Unknown'
                                      };
                                    })
                                    .where((user) =>
                                        user['id'] != widget.currentUser['id'])
                                    .toList();
                                if (users.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'No other users found.',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          shadows: [
                                            Shadow(
                                                color: Colors.black54,
                                                offset: Offset(2, 2),
                                                blurRadius: 4)
                                          ]),
                                    ),
                                  );
                                }
                                return ListView.separated(
                                  padding: const EdgeInsets.all(16.0),
                                  itemCount: users.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(color: Colors.white54),
                                  itemBuilder: (context, index) {
                                    final user = users[index];
                                    final userId = user['id'].toString();
                                    final isSelected = _isGroupChat
                                        ? _selectedUsers
                                            .any((u) => u['id'] == userId)
                                        : _selectedUser != null &&
                                            _selectedUser!['id'] == userId;
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: LinearGradient(
                                          colors: [
                                            widget.accentColor.withOpacity(
                                                isSelected ? 0.4 : 0.2),
                                            widget.accentColor.withOpacity(
                                                isSelected ? 0.6 : 0.4),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: widget.accentColor
                                                .withOpacity(0.6),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: widget.accentColor,
                                          child: Text(
                                            user['username']?.isNotEmpty ??
                                                    false
                                                ? user['username'][0]
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                        title: Text(
                                          user['username'],
                                          style: const TextStyle(
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                    color: Colors.black,
                                                    offset: Offset(2, 2),
                                                    blurRadius: 4)
                                              ]),
                                        ),
                                        trailing: _isGroupChat
                                            ? Checkbox(
                                                value: _selectedUsers.any(
                                                    (u) => u['id'] == userId),
                                                onChanged: (bool? value) {
                                                  setState(() {
                                                    if (value == true) {
                                                      _selectedUsers.add(user);
                                                    } else {
                                                      _selectedUsers
                                                          .removeWhere((u) =>
                                                              u['id'] ==
                                                              userId);
                                                    }
                                                  });
                                                },
                                                activeColor: widget.accentColor,
                                              )
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            if (_isGroupChat) {
                                              if (_selectedUsers.any(
                                                  (u) => u['id'] == userId)) {
                                                _selectedUsers.removeWhere(
                                                    (u) => u['id'] == userId);
                                              } else {
                                                _selectedUsers.add(user);
                                              }
                                            } else {
                                              _selectedUser = user;
                                              _startChat();
                                            }
                                          });
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          if (_isGroupChat)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ElevatedButton(
                                onPressed: _startChat,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.accentColor,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 24),
                                ),
                                child: const Text('Create Group Chat',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
