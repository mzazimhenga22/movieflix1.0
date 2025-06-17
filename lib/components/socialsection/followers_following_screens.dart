import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show File;
import 'dart:ui';
import 'user_profile_screen.dart';
import '../../utils/extensions.dart';

class FollowersScreen extends StatefulWidget {
  final String userId;
  final Color accentColor;

  const FollowersScreen({
    super.key,
    required this.userId,
    required this.accentColor,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  List<Map<String, dynamic>> _followers = [];

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('followers')
        .get();
    final followerIds = snapshot.docs.map((doc) => doc.id).toList();
    final followers = <Map<String, dynamic>>[];
    for (var id in followerIds) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (userDoc.exists) {
        followers.add(_sanitizeUserData({...userDoc.data()!, 'id': id}));
      }
    }
    setState(() {
      _followers = followers;
    });
  }

  Map<String, dynamic> _sanitizeUserData(Map<String, dynamic> user) {
    final email = user['email']?.toString() ?? '';
    final username = user['username']?.toString() ??
        user['name']?.toString() ??
        _extractFirstName(email);
    return {
      'id': user['id']?.toString() ?? '',
      'username': username,
      'email': email,
      'avatar': user['avatar']?.toString() ?? '',
      'bio': user['bio']?.toString() ?? 'No bio available.',
      'followers_count': user['followers_count'] ?? 0,
      'following_count': user['following_count'] ?? 0,
    };
  }

  String _extractFirstName(String email) {
    final parts = email.split('@').first.split('.');
    return parts.isNotEmpty ? parts.first.capitalize() : 'Guest';
  }

  ImageProvider _buildAvatarImage(String avatarUrl) {
    if (avatarUrl.isNotEmpty) {
      if (kIsWeb || avatarUrl.startsWith("http")) {
        return NetworkImage(avatarUrl);
      } else {
        return FileImage(File(avatarUrl));
      }
    }
    return const NetworkImage("https://via.placeholder.com/200");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Followers',
            style: TextStyle(color: Colors.white, fontSize: 20)),
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFF111927)),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.1, -0.4),
                radius: 1.2,
                colors: [widget.accentColor.withOpacity(0.4), Colors.black],
                stops: const [0.0, 0.6],
              ),
            ),
          ),
          Positioned.fill(
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.6,
                    colors: [
                      widget.accentColor.withOpacity(0.2),
                      Colors.transparent
                    ],
                    stops: const [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(180, 17, 19, 40),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Followers",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black45,
                                        offset: Offset(1, 1),
                                        blurRadius: 2)
                                  ]),
                            ),
                            const SizedBox(height: 12),
                            if (_followers.isEmpty)
                              const Text("No followers yet.",
                                  style: TextStyle(color: Colors.white70))
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _followers.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(color: Colors.white54),
                                itemBuilder: (context, index) {
                                  final user = _followers[index];
                                  final currentUser =
                                      FirebaseAuth.instance.currentUser;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: widget.accentColor,
                                      backgroundImage: user['avatar']
                                                  ?.isNotEmpty ==
                                              true
                                          ? _buildAvatarImage(user['avatar'])
                                          : null,
                                      child: user['avatar']?.isNotEmpty != true
                                          ? Text(
                                              user['username'].isNotEmpty
                                                  ? user['username'][0]
                                                      .trim()
                                                      .toUpperCase()
                                                  : "G",
                                              style: const TextStyle(
                                                  color: Colors.black),
                                            )
                                          : null,
                                    ),
                                    title: Text(user['username'],
                                        style: const TextStyle(
                                            color: Colors.black, fontSize: 16)),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UserProfileScreen(
                                          user: user,
                                          showAppBar: true,
                                          accentColor: widget.accentColor,
                                        ),
                                      ),
                                    ),
                                    trailing: currentUser != null &&
                                            currentUser.uid != user['id']
                                        ? StreamBuilder<DocumentSnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(currentUser.uid)
                                                .collection('following')
                                                .doc(user['id'])
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2));
                                              }
                                              final isFollowing =
                                                  snapshot.data?.exists ??
                                                      false;
                                              return ElevatedButton(
                                                onPressed: () async {
                                                  if (isFollowing) {
                                                    await _unfollowUser(
                                                        currentUser.uid,
                                                        user['id']);
                                                  } else {
                                                    await _followUser(
                                                        currentUser.uid,
                                                        user['id']);
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isFollowing
                                                      ? Colors.grey[700]
                                                      : widget.accentColor,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                          .symmetric(
                                                      horizontal: 12),
                                                  minimumSize:
                                                      const Size(80, 32),
                                                ),
                                                child: Text(
                                                  isFollowing
                                                      ? 'Unfollow'
                                                      : 'Follow',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                              );
                                            },
                                          )
                                        : null,
                                  );
                                },
                              ),
                          ],
                        ),
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

  Future<void> _followUser(String currentUserId, String targetUserId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(targetUserId),
        {'timestamp': DateTime.now().toIso8601String()});
    batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .collection('followers')
            .doc(currentUserId),
        {'timestamp': DateTime.now().toIso8601String()});
    batch.update(
        FirebaseFirestore.instance.collection('users').doc(targetUserId),
        {'followers_count': FieldValue.increment(1)});
    batch.update(
        FirebaseFirestore.instance.collection('users').doc(currentUserId),
        {'following_count': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> _unfollowUser(String currentUserId, String targetUserId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId));
    batch.delete(FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId));
    batch.update(
        FirebaseFirestore.instance.collection('users').doc(targetUserId),
        {'followers_count': FieldValue.increment(-1)});
    batch.update(
        FirebaseFirestore.instance.collection('users').doc(currentUserId),
        {'following_count': FieldValue.increment(-1)});
    await batch.commit();
  }
}

class FollowingScreen extends StatefulWidget {
  final String userId;
  final Color accentColor;

  const FollowingScreen({
    super.key,
    required this.userId,
    required this.accentColor,
  });

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  List<Map<String, dynamic>> _following = [];

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('following')
        .get();
    final followingIds = snapshot.docs.map((doc) => doc.id).toList();
    final following = <Map<String, dynamic>>[];
    for (var id in followingIds) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (userDoc.exists) {
        following.add(_sanitizeUserData({...userDoc.data()!, 'id': id}));
      }
    }
    setState(() {
      _following = following;
    });
  }

  Map<String, dynamic> _sanitizeUserData(Map<String, dynamic> user) {
    final email = user['email']?.toString() ?? '';
    final username = user['username']?.toString() ??
        user['name']?.toString() ??
        _extractFirstName(email);
    return {
      'id': user['id']?.toString() ?? '',
      'username': username,
      'email': email,
      'avatar': user['avatar']?.toString() ?? '',
      'bio': user['bio']?.toString() ?? 'No bio available.',
      'followers_count': user['followers_count'] ?? 0,
      'following_count': user['following_count'] ?? 0,
    };
  }

  String _extractFirstName(String email) {
    final parts = email.split('@').first.split('.');
    return parts.isNotEmpty ? parts.first.capitalize() : 'Guest';
  }

  ImageProvider _buildAvatarImage(String avatarUrl) {
    if (avatarUrl.isNotEmpty) {
      if (kIsWeb || avatarUrl.startsWith("http")) {
        return NetworkImage(avatarUrl);
      } else {
        return FileImage(File(avatarUrl));
      }
    }
    return const NetworkImage("https://via.placeholder.com/200");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Following',
            style: TextStyle(color: Colors.white, fontSize: 20)),
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFF111927)),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.1, -0.4),
                radius: 1.2,
                colors: [widget.accentColor.withOpacity(0.4), Colors.black],
                stops: const [0.0, 0.6],
              ),
            ),
          ),
          Positioned.fill(
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.6,
                    colors: [
                      widget.accentColor.withOpacity(0.2),
                      Colors.transparent
                    ],
                    stops: const [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(180, 17, 19, 40),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Following",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black45,
                                        offset: Offset(1, 1),
                                        blurRadius: 2)
                                  ]),
                            ),
                            const SizedBox(height: 12),
                            if (_following.isEmpty)
                              const Text("Not following anyone yet.",
                                  style: TextStyle(color: Colors.white70))
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _following.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(color: Colors.white54),
                                itemBuilder: (context, index) {
                                  final user = _following[index];
                                  final currentUser =
                                      FirebaseAuth.instance.currentUser;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: widget.accentColor,
                                      backgroundImage: user['avatar']
                                                  ?.isNotEmpty ==
                                              true
                                          ? _buildAvatarImage(user['avatar'])
                                          : null,
                                      child: user['avatar']?.isNotEmpty != true
                                          ? Text(
                                              user['username'].isNotEmpty
                                                  ? user['username'][0]
                                                      .toUpperCase()
                                                  : "G",
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            )
                                          : null,
                                    ),
                                    title: Text(user['username'],
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 16)),
                                  onTap: () => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => UserProfileScreen(
      user: user,
      showAppBar: true,
      accentColor: widget.accentColor,
    ),
  ),
),
                                    trailing: currentUser != null &&
                                            currentUser.uid != user['id']
                                        ? StreamBuilder<DocumentSnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(currentUser.uid)
                                                .collection('following')
                                                .doc(user['id'])
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2));
                                              }
                                              final isFollowing =
                                                  snapshot.data?.exists ??
                                                      false;
                                              return ElevatedButton(
                                                onPressed: () async {
                                                  if (isFollowing) {
                                                    await _unfollowUser(
                                                        currentUser.uid,
                                                        user['id']);
                                                  } else {
                                                    await _followUser(
                                                        currentUser.uid,
                                                        user['id']);
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isFollowing
                                                      ? Colors.grey[700]
                                                      : widget.accentColor,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                          .symmetric(
                                                      horizontal: 12),
                                                  minimumSize:
                                                      const Size(80, 32),
                                                ),
                                                child: Text(
                                                  isFollowing
                                                      ? 'Unfollow'
                                                      : 'Follow',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                              );
                                            },
                                          )
                                        : null,
                                  );
                                },
                              ),
                          ],
                        ),
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

  Future<void> _followUser(String currentUserId, String targetUserId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(targetUserId),
        {'timestamp': DateTime.now().toIso8601String()});
    batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .collection('followers')
            .doc(currentUserId),
        {'timestamp': DateTime.now().toIso8601String()});
    batch.update(
        FirebaseFirestore.instance.collection('users').doc(targetUserId),
        {'followers_count': FieldValue.increment(1)});
    batch.update(
        FirebaseFirestore.instance.collection('users').doc(currentUserId),
        {'following_count': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> _unfollowUser(String currentUserId, String targetUserId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId));
    batch.delete(FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId));
    batch.update(
        FirebaseFirestore.instance.collection('users').doc(targetUserId),
        {'followers_count': FieldValue.increment(-1)});
    batch.update(
        FirebaseFirestore.instance.collection('users').doc(currentUserId),
        {'following_count': FieldValue.increment(-1)});
    await batch.commit();
  }
}
