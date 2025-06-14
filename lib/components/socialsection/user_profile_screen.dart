import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io' show File;
import 'dart:ui';
import 'stories.dart';
import 'edit_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool showAppBar;
  final Color accentColor;

  const UserProfileScreen({
    super.key,
    required this.user,
    this.showAppBar = true,
    required this.accentColor,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Map<String, dynamic> _user;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _stories = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _user = _sanitizeUserData(widget.user);
    _loadStories();
    _searchController.addListener(_onSearchChanged);
    _checkAndShowReminder();
  }

  Future<void> _loadStories() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('stories').get();
    setState(() {
      _stories = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return <String, dynamic>{...data, 'id': doc.id};
          })
          .where((story) =>
              DateTime.now().difference(DateTime.parse(
                  story['timestamp'] ?? DateTime.now().toIso8601String())) <
              const Duration(hours: 24))
          .toList();
    });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {});
    });
  }

  Future<void> _checkAndShowReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastVisitDate = prefs.getString('last_visit_date') ?? '';
    final visitCount = prefs.getInt('visit_count') ?? 0;

    if (lastVisitDate != today) {
      await prefs.setString('last_visit_date', today);
      await prefs.setInt('visit_count', 1);
    } else {
      await prefs.setInt('visit_count', visitCount + 1);
    }

    if (visitCount >= 1 && _user['username'] == 'Guest') {
      _showNicknameReminder();
    }
  }

  void _showNicknameReminder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 17, 25, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Personalize Your Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Hey there! It looks like you haven't set a nickname yet. Add one to make your profile stand out!",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(
                    user: _user,
                    accentColor: widget.accentColor,
                    onProfileUpdated: (updatedUser) {
                      setState(() {
                        _user = _sanitizeUserData(updatedUser);
                      });
                    },
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Set Nickname"),
          ),
        ],
      ),
    );
  }

  String extractFirstName(String email) {
    final parts = email.split('@').first.split('.');
    return parts.isNotEmpty ? parts.first.capitalize() : 'Guest';
  }

  Map<String, dynamic> _sanitizeUserData(Map<String, dynamic> user) {
    final email = user['email']?.toString() ?? '';
    final username = user['username']?.toString() ??
        user['name']?.toString() ??
        extractFirstName(email);
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

  ImageProvider _buildAvatarImage() {
    if (_user['avatar'] != null && _user['avatar'].isNotEmpty) {
      if (kIsWeb || _user['avatar'].startsWith("http")) {
        return NetworkImage(_user['avatar']);
      } else {
        return FileImage(File(_user['avatar']));
      }
    }
    return const NetworkImage("https://via.placeholder.com/200");
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
    if (mounted && _user['id'] == targetUserId) {
      setState(() {
        _user['followers_count'] = (_user['followers_count'] ?? 0) + 1;
      });
    }
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
    if (mounted && _user['id'] == targetUserId) {
      setState(() {
        _user['followers_count'] = (_user['followers_count'] ?? 1) - 1;
      });
    }
  }

  Future<void> _deletePost(String postId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(FirebaseFirestore.instance
        .collection('users')
        .doc(_user['id'])
        .collection('posts')
        .doc(postId));
    batch.delete(FirebaseFirestore.instance.collection('feeds').doc(postId));
    await batch.commit();
  }

  Future<void> _likePost(String postId, bool isLiked, String userId) async {
    final postRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('posts')
        .doc(postId);
    final feedRef = FirebaseFirestore.instance.collection('feeds').doc(postId);
    final batch = FirebaseFirestore.instance.batch();
    if (isLiked) {
      batch.update(
          postRef, {'liked': false, 'likes_count': FieldValue.increment(-1)});
      batch.update(
          feedRef, {'liked': false, 'likes_count': FieldValue.increment(-1)});
    } else {
      batch.update(
          postRef, {'liked': true, 'likes_count': FieldValue.increment(1)});
      batch.update(
          feedRef, {'liked': true, 'likes_count': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    if (query.isEmpty) {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _sanitizeUserData({...data, 'id': doc.id});
      }).toList();
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return _sanitizeUserData({...data, 'id': doc.id});
    }).toList();
  }

  bool _hasActiveStory() {
    return _stories.any((story) =>
        story['userId'] == _user['id'] &&
        DateTime.now().difference(DateTime.parse(
                story['timestamp'] ?? DateTime.now().toIso8601String())) <
            const Duration(hours: 24));
  }

  String _displayCount(dynamic count) {
    return count?.toString() ?? '0';
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user['username'];
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnProfile = _user['id'] == currentUser?.uid;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 20)),
            )
          : null,
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
            top: widget.showAppBar
                ? kToolbarHeight + MediaQuery.of(context).padding.top
                : 0,
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
                        padding: EdgeInsets.only(
                            top: widget.showAppBar ? 16 : 48,
                            left: 16,
                            right: 16,
                            bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _hasActiveStory()
                                  ? () {
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(_user['id'])
                                          .collection('stories')
                                          .get()
                                          .then((snapshot) {
                                        final userStories = snapshot.docs
                                            .map((doc) {
                                              final data = doc.data();
                                              return <String, dynamic>{
                                                ...data,
                                                'id': doc.id
                                              };
                                            })
                                            .where((story) =>
                                                DateTime.now().difference(
                                                    DateTime.parse(story[
                                                            'timestamp'] ??
                                                        DateTime.now()
                                                            .toIso8601String())) <
                                                const Duration(hours: 24))
                                            .toList();
                                        if (userStories.isNotEmpty) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => StoryScreen(
                                                stories: userStories,
                                                initialIndex: 0,
                                                currentUserId:
                                                    currentUser?.uid ?? '',
                                              ),
                                            ),
                                          );
                                        }
                                      });
                                    }
                                  : null,
                              child: Container(
                                decoration: _hasActiveStory()
                                    ? BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color:
                                                Colors.yellow.withOpacity(0.8),
                                            width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.yellow.withOpacity(0.6),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      )
                                    : null,
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: widget.accentColor,
                                  child: ClipOval(
                                    child: Image(
                                      image: _buildAvatarImage(),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Center(
                                        child: Text(
                                          displayName.isNotEmpty
                                              ? displayName[0].toUpperCase()
                                              : "G",
                                          style: const TextStyle(
                                              fontSize: 40,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              displayName,
                              style: const TextStyle(
                                  fontSize: 24,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                    'Followers: ${_displayCount(_user['followers_count'])}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14)),
                                const SizedBox(width: 16),
                                Text(
                                    'Following: ${_displayCount(_user['following_count'])}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(_user['email'],
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.white70)),
                            const SizedBox(height: 12),
                            Text(
                              _user['bio'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8)),
                            ),
                            const SizedBox(height: 16),
                            if (!isOwnProfile && currentUser != null)
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUser.uid)
                                    .collection('following')
                                    .doc(_user['id'])
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const CircularProgressIndicator();
                                  }
                                  final isFollowing =
                                      snapshot.data?.exists ?? false;
                                  return ElevatedButton(
                                    onPressed: () async {
                                      if (isFollowing) {
                                        await _unfollowUser(
                                            currentUser.uid, _user['id']);
                                      } else {
                                        await _followUser(
                                            currentUser.uid, _user['id']);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.accentColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 20),
                                      minimumSize:
                                          const Size(double.infinity, 48),
                                    ),
                                    child: Text(
                                        isFollowing ? 'Unfollow' : 'Follow',
                                        style: const TextStyle(fontSize: 16)),
                                  );
                                },
                              ),
                            if (isOwnProfile && currentUser != null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditProfileScreen(
                                          user: _user,
                                          accentColor: widget.accentColor,
                                          onProfileUpdated: (updatedUser) {
                                            setState(() {
                                              _user = _sanitizeUserData(
                                                  updatedUser);
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.edit, size: 20),
                                  label: const Text("Edit Profile",
                                      style: TextStyle(fontSize: 16)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.accentColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 20),
                                    minimumSize:
                                        const Size(double.infinity, 48),
                                  ),
                                ),
                              ),
                            const Divider(color: Colors.white54, thickness: 1),
                            const SizedBox(height: 16),
                            const Text(
                              "User's Posts",
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
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(_user['id'])
                                  .collection('posts')
                                  .orderBy('timestamp', descending: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}',
                                      style:
                                          const TextStyle(color: Colors.white));
                                }
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                final posts = snapshot.data!.docs.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  return <String, dynamic>{
                                    ...data,
                                    'id': doc.id
                                  };
                                }).toList();
                                if (posts.isEmpty) {
                                  return Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            widget.accentColor.withOpacity(0.1),
                                            widget.accentColor.withOpacity(0.3)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: widget.accentColor
                                                .withOpacity(0.3)),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text("No posts available.",
                                            style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.white70)),
                                      ),
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: posts.length,
                                  itemBuilder: (context, index) {
                                    final post = posts[index];
                                    return Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              widget.accentColor
                                                  .withOpacity(0.1),
                                              widget.accentColor
                                                  .withOpacity(0.3)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: widget.accentColor
                                                  .withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ListTile(
                                              title: Text(
                                                  post['user'] ?? 'Unknown',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                      shadows: [
                                                        Shadow(
                                                            color:
                                                                Colors.black45,
                                                            offset:
                                                                Offset(1, 1),
                                                            blurRadius: 2)
                                                      ])),
                                              trailing: isOwnProfile
                                                  ? IconButton(
                                                      icon: const Icon(
                                                          Icons.delete,
                                                          color: Colors.red,
                                                          size: 22),
                                                      onPressed: () async {
                                                        final confirm =
                                                            await showDialog<
                                                                bool>(
                                                          context: context,
                                                          builder: (context) =>
                                                              AlertDialog(
                                                            backgroundColor:
                                                                const Color
                                                                        .fromARGB(
                                                                    255,
                                                                    17,
                                                                    25,
                                                                    40),
                                                            title: const Text(
                                                                "Delete Post",
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white)),
                                                            content: const Text(
                                                                "Are you sure you want to delete this post?",
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white70)),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        false),
                                                                child: const Text(
                                                                    "Cancel",
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .white70)),
                                                              ),
                                                              ElevatedButton(
                                                                style: ElevatedButton.styleFrom(
                                                                    backgroundColor:
                                                                        Colors
                                                                            .red,
                                                                    foregroundColor:
                                                                        Colors
                                                                            .white),
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        true),
                                                                child: const Text(
                                                                    "Delete"),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                        if (confirm == true) {
                                                          await _deletePost(
                                                              post['id']);
                                                        }
                                                      },
                                                    )
                                                  : null,
                                            ),
                                            if (post['media']?.isNotEmpty ??
                                                false)
                                              if (post['mediaType'] == 'photo')
                                                CachedNetworkImage(
                                                  imageUrl: post['media']!,
                                                  height: 180,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      const Center(
                                                          child:
                                                              CircularProgressIndicator()),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Container(
                                                    height: 180,
                                                    color: Colors.grey[300],
                                                    child: const Center(
                                                        child: Icon(Icons.error,
                                                            size: 40)),
                                                  ),
                                                )
                                              else if (post['mediaType'] ==
                                                  'video')
                                                Container(
                                                  height: 180,
                                                  color: Colors.black,
                                                  child: const Center(
                                                      child: Text(
                                                          'Video content',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white))),
                                                )
                                              else
                                                Container(
                                                  height: 180,
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                      child: Icon(Icons.image,
                                                          size: 40)),
                                                ),
                                            Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(post['post'] ?? '',
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          color:
                                                              Colors.white70)),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                      "Movie: ${post['movie'] ?? 'Unknown'}",
                                                      style: const TextStyle(
                                                          fontStyle:
                                                              FontStyle.italic,
                                                          color:
                                                              Colors.white70)),
                                                ],
                                              ),
                                            ),
                                            const Divider(
                                                color: Colors.white54,
                                                height: 1),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    post['liked'] == true
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    color: post['liked'] == true
                                                        ? Colors.red
                                                        : Colors.white70,
                                                    size: 22,
                                                  ),
                                                  onPressed: currentUser != null
                                                      ? () async {
                                                          await _likePost(
                                                              post['id'],
                                                              post['liked'] ??
                                                                  false,
                                                              _user['id']);
                                                        }
                                                      : null,
                                                ),
                                                Text(
                                                    '${post['likes_count'] ?? 0} Likes',
                                                    style: const TextStyle(
                                                        color: Colors.white70)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white54, thickness: 1),
                            const SizedBox(height: 16),
                            const Text(
                              "Find Users",
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
                            TextField(
                              controller: _searchController,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                hintText: "Search by username",
                                hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.6)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.2),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future:
                                  _searchUsers(_searchController.text.trim()),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                }
                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}',
                                      style:
                                          const TextStyle(color: Colors.white));
                                }
                                final users = (snapshot.data ?? [])
                                    .where((u) => u['id'] != _user['id'])
                                    .toList();
                                if (users.isEmpty) {
                                  return const Text("No users found.",
                                      style: TextStyle(color: Colors.white));
                                }
                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: users.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(color: Colors.white54),
                                  itemBuilder: (context, index) {
                                    final otherUser = users[index];
                                    final otherUserName = otherUser['username'];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: widget.accentColor,
                                        backgroundImage: otherUser['avatar']
                                                    ?.isNotEmpty ==
                                                true
                                            ? NetworkImage(otherUser['avatar'])
                                            : null,
                                        child:
                                            otherUser['avatar']?.isNotEmpty !=
                                                    true
                                                ? Text(
                                                    otherUserName.isNotEmpty
                                                        ? otherUserName[0]
                                                            .toUpperCase()
                                                        : "G",
                                                    style: const TextStyle(
                                                        color: Colors.white),
                                                  )
                                                : null,
                                      ),
                                      title: Text(otherUserName,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16)),
                                      trailing: currentUser != null
                                          ? StreamBuilder<DocumentSnapshot>(
                                              stream: FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(currentUser.uid)
                                                  .collection('following')
                                                  .doc(otherUser['id'])
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
                                                          otherUser['id']);
                                                    } else {
                                                      await _followUser(
                                                          currentUser.uid,
                                                          otherUser['id']);
                                                    }
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: isFollowing
                                                        ? Colors.grey[700]
                                                        : widget.accentColor,
                                                    foregroundColor:
                                                        Colors.white,
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
                                                          fontSize: 12)),
                                                );
                                              },
                                            )
                                          : null,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              UserProfileScreen(
                                            user: otherUser,
                                            showAppBar: true,
                                            accentColor: widget.accentColor,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
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
}

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
