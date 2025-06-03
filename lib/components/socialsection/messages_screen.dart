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

  Future<void> _loadConversations() async {
    try {
      final convos = await AuthDatabase.instance
          .getConversationsForUser(widget.currentUser['id']);
      final userMap = <String, Map<String, dynamic>>{};

      // Collect all participant IDs across conversations
      final allParticipantIds = <String>{};
      for (var convo in convos) {
        final participantIds = (convo['participants'] as List?)
                ?.map((id) => id.toString())
                .toList() ??
            [];
        allParticipantIds.addAll(participantIds);
      }

      // Fetch user data for all participants
      for (var id in allParticipantIds) {
        if (!userMap.containsKey(id)) {
          final user = await AuthDatabase.instance.getUserById(id);
          userMap[id] = user ?? {'id': id, 'username': 'Unknown'};
        }
      }

      final convosWithUnread = await Future.wait(convos.map((convo) async {
        final participantIds = (convo['participants'] as List?)
                ?.map((id) => id.toString())
                .toList() ??
            [];
        final participantsData =
            participantIds.map((id) => userMap[id]!).toList();
        final unreadCount = await AuthDatabase.instance
            .getUnreadCount(convo['id'], widget.currentUser['id']);
        return {
          ...convo,
          'unread_count': unreadCount,
          'participantsData': participantsData, // Add participant data
        };
      }).toList());

      if (mounted) {
        setState(() {
          _conversations = convosWithUnread
            ..sort((a, b) {
              final aPinned =
                  a['pinned_users']?.contains(widget.currentUser['id']) ??
                      false;
              final bPinned =
                  b['pinned_users']?.contains(widget.currentUser['id']) ??
                      false;
              if (aPinned && !bPinned) return -1;
              if (!aPinned && bPinned) return 1;
              final aTime =
                  DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
              final bTime =
                  DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
              return bTime.compareTo(aTime);
            });
          _userMap = userMap;
          _errorMessage = null;
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

  Future<String> _getUserStatus(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return doc.exists ? (doc.data()?['status'] ?? 'Offline') : 'Offline';
    } catch (e) {
      return 'Offline';
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
        convo['pinned_users']?.contains(widget.currentUser['id']) ?? false;
    final isMuted =
        convo['muted_users']?.contains(widget.currentUser['id']) ?? false;
    final isBlocked =
        convo['blocked_users']?.contains(widget.currentUser['id']) ?? false;

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
      await AuthDatabase.instance.updateConversation({
        'id': convo['id'],
        'pinned_users': pinnedUsers,
      });
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
          SnackBar(content: Text('Failed to block/unblock this: $error')));
    }
  }

  Widget _buildStatusIndicator(String status, Color accentColor) {
    Color dotColor;
    switch (status.toLowerCase()) {
      case 'online':
        dotColor = Colors.green;
        break;
      case 'busy':
        dotColor = Colors.orange;
        break;
      case 'offline':
      default:
        dotColor = Colors.red;
        break;
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 4)
            ],
          ),
        ),
      ],
    );
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
                                    final isMuted = convo['muted_users']
                                            ?.contains(
                                                widget.currentUser['id']) ??
                                        false;
                                    final isPinned = convo['pinned_users']
                                            ?.contains(
                                                widget.currentUser['id']) ??
                                        false;
                                    final isBlocked = convo['blocked_users']
                                            ?.contains(
                                                widget.currentUser['id']) ??
                                        false;
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
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                convo['last_message']
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
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (convo['type'] == 'group')
                                                Text(
                                                  (convo['participantsData']
                                                          as List<
                                                              Map<String,
                                                                  dynamic>>)
                                                      .map((p) =>
                                                          p['username'] ??
                                                          'Unknown')
                                                      .join(', '),
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12,
                                                    shadows: [
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
                                                final otherUser =
                                                    _userMap[otherUserId] ??
                                                        {
                                                          'id': otherUserId,
                                                          'username': 'Unknown'
                                                        };
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

  Future<String> _getGroupParticipants(List<String> participantIds) async {
    try {
      final users = await Future.wait(participantIds.map((id) async {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(id).get();
        return doc.exists ? (doc.data()?['username'] ?? 'Unknown') : 'Unknown';
      }));
      return users.take(3).join(', ') + (users.length > 3 ? '...' : '');
    } catch (e) {
      return '';
    }
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
  List<String> _selectedUserIds = [];
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
      if (_isGroupChat && _selectedUserIds.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Select at least 2 users for a group chat')),
        );
        return;
      }
      if (_isGroupChat && _groupName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a group name')),
        );
        return;
      }

      String convoId;
      Map<String, dynamic> convoData;
      Map<String, dynamic> otherUserData;

      if (_isGroupChat) {
        convoId = DateTime.now().millisecondsSinceEpoch.toString();
        final participants = [
          widget.currentUser['id'].toString(),
          ..._selectedUserIds
        ];
        convoData = {
          'id': convoId,
          'type': 'group',
          'group_name': _groupName,
          'participants': participants,
          'timestamp': FieldValue.serverTimestamp(),
          'muted_users': [],
          'blocked_users': [],
          'pinned_users': [],
        };
        // Construct participantsData for GroupChatScreen
        final participantsData = participants.map((id) {
          if (id == widget.currentUser['id'].toString()) {
            return {
              'id': id,
              'username': widget.currentUser['username'] ?? 'Unknown',
            };
          }
          final user = widget.otherUsers.firstWhere(
            (user) => user['id'].toString() == id,
            orElse: () => {'id': id, 'username': 'Unknown'},
          );
          return {
            'id': id,
            'username': user['username'] ?? 'Unknown',
          };
        }).toList();

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
      } else {
        if (_selectedUserIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select a user to start a chat')),
          );
          return;
        }
        final otherUserId = _selectedUserIds.first;
        final otherUser = widget.otherUsers.firstWhere(
          (user) => user['id'].toString() == otherUserId,
          orElse: () => {},
        );
        if (otherUser.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected user not found')),
          );
          return;
        }
        final sortedIds = [widget.currentUser['id'].toString(), otherUserId]
          ..sort();
        convoId = sortedIds.join('_');
        convoData = {
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
        otherUserData = {'id': otherUserId, 'username': otherUser['username']};
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IndividualChatScreen(
              currentUser: widget.currentUser,
              otherUser: otherUserData,
              storyInteractions: [],
            ),
          ),
        );
      }

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(convoId)
          .set(convoData, SetOptions(merge: true));
      await AuthDatabase.instance.insertConversation({
        ...convoData,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: $e')),
      );
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
                _selectedUserIds.clear();
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
                                    .map((doc) =>
                                        doc.data() as Map<String, dynamic>)
                                    .where((user) =>
                                        user['id']?.toString() !=
                                        widget.currentUser['id']?.toString())
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
                                    final userId = user['id']?.toString();
                                    final username =
                                        user['username']?.toString() ??
                                            'Unknown';
                                    final isSelected =
                                        _selectedUserIds.contains(userId);
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
                                            username.isNotEmpty
                                                ? username[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                        title: Text(
                                          username,
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
                                                value: isSelected,
                                                onChanged: (bool? value) {
                                                  setState(() {
                                                    if (value == true) {
                                                      _selectedUserIds
                                                          .add(userId!);
                                                    } else {
                                                      _selectedUserIds
                                                          .remove(userId);
                                                    }
                                                  });
                                                },
                                                activeColor: widget.accentColor,
                                              )
                                            : null,
                                        onTap: userId != null
                                            ? () {
                                                setState(() {
                                                  if (_isGroupChat) {
                                                    if (_selectedUserIds
                                                        .contains(userId)) {
                                                      _selectedUserIds
                                                          .remove(userId);
                                                    } else {
                                                      _selectedUserIds
                                                          .add(userId);
                                                    }
                                                  } else {
                                                    _selectedUserIds = [userId];
                                                    _startChat();
                                                  }
                                                });
                                              }
                                            : null,
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
