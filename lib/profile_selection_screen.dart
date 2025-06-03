import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database/auth_database.dart';
import 'package:movie_app/home_screen_main.dart';
import 'package:movie_app/signin_screen.dart';
import 'user_manager.dart';
import 'session_manager.dart';
import 'dart:ui';

class AnimatedBorder extends StatefulWidget {
  const AnimatedBorder({
    super.key,
    required this.child,
    required this.colors,
    this.borderWidth = 4,
    this.duration = const Duration(seconds: 2),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final Widget child;
  final List<Color> colors;
  final double borderWidth;
  final Duration duration;
  final BorderRadius borderRadius;

  @override
  State<AnimatedBorder> createState() => _AnimatedBorderState();
}

class _AnimatedBorderState extends State<AnimatedBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: SweepGradient(
              startAngle: 0.0,
              endAngle: 2 * pi,
              colors: widget.colors,
              transform: GradientRotation(_controller.value * 2 * pi),
            ),
          ),
          padding: EdgeInsets.all(widget.borderWidth),
          child: ClipRRect(
            borderRadius: widget.borderRadius.subtract(
              BorderRadius.all(Radius.circular(widget.borderWidth)),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class AnimatedBorderBox extends StatelessWidget {
  const AnimatedBorderBox({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = (index % 2 == 0)
        ? const [Colors.cyan, Colors.purple]
        : const [Colors.purple, Colors.cyan];
    return AnimatedBorder(
      colors: colors,
      child: child,
    );
  }
}

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  bool isEditing = false;
  final StreamController<List<Map<String, dynamic>>> _profilesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  List<Map<String, dynamic>> _profiles = [];
  int get maxProfiles => 5;

  static const List<String> defaultAvatars = [
    "assets/profile1.jpg",
    "assets/profile2.jpg",
    "assets/profile3.webp",
    "assets/profile4.jpg",
    "assets/profile5.jpg",
  ];

  static const List<String> defaultBackgrounds = [
    "assets/background1.jpg",
    "assets/background2.jpg",
    "assets/background3.webp",
    "assets/background4.jpg",
    "assets/background5.jpg",
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndProfiles();
  }

  @override
  void dispose() {
    _profilesController.close();
    super.dispose();
  }

  Future<void> _loadCurrentUserAndProfiles() async {
    try {
      await AuthDatabase.instance
          .initialize(); // Ensure database is initialized
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('ℹ️ No user signed in');
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const SignInScreen()));
        }
        return;
      }

      debugPrint('🔍 Checking session for user: ${user.uid}');
      final sessionDoc =
          await _firestore.collection('sessions').doc(user.uid).get();
      if (!sessionDoc.exists) {
        debugPrint('❌ No Firestore session found for user: ${user.uid}');
        final token = await user.getIdToken();
        if (token == null) {
          debugPrint('❌ Failed to get ID token');
          if (mounted) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const SignInScreen()));
          }
          return;
        }
        await _firestore.collection('sessions').doc(user.uid).set({
          'userId': user.uid,
          'token': token,
          'expiresAt':
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 5))),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await SessionManager.saveAuthToken(token);
        await SessionManager.saveSessionUserId(user.uid);
        debugPrint('✅ Created new session for user: ${user.uid}');
      } else {
        final sessionData = sessionDoc.data();
        final expiresAt = sessionData?['expiresAt'] as Timestamp?;
        if (expiresAt == null || DateTime.now().isAfter(expiresAt.toDate())) {
          debugPrint('❌ Session expired or invalid');
          if (!mounted) return;
          await SessionManager.clearAuthToken();
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const SignInScreen()));
          return;
        }
        debugPrint('✅ Valid session found');
      }

      await _refreshProfiles();
    } catch (e) {
      debugPrint('❌ Error in _loadCurrentUserAndProfiles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error loading profiles')));
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const SignInScreen()));
      }
    }
  }

  Future<void> _refreshProfiles() async {
    final user = UserManager.instance.currentUser.value;
    if (user == null) {
      debugPrint('❌ No user, clearing profiles');
      _profilesController.add([]);
      _profiles = [];
      setState(() {});
      return;
    }
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) {
      debugPrint('❌ Invalid user ID');
      _profilesController.add([]);
      _profiles = [];
      setState(() {});
      return;
    }
    try {
      final profiles = await AuthDatabase.instance.getProfilesByUserId(userId);
      debugPrint(
          '🔄 Refreshed ${profiles.length} profiles: ${profiles.map((p) => p['name'])}');
      _profiles = List.from(profiles);
      _profilesController.add(_profiles);
      setState(() {});
    } catch (e) {
      debugPrint('❌ Error refreshing profiles: $e');
      _profilesController.add([]);
      _profiles = [];
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error refreshing profiles')));
      }
    }
  }

  String _processUrl(String url) {
    url = url.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  void _showAddProfileDialog() {
    final user = UserManager.instance.currentUser.value;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("No user logged in.")));
      }
      return;
    }
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Invalid user ID.")));
      }
      return;
    }
    if (_profiles.length >= maxProfiles) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Maximum 5 profiles allowed.")));
      }
      return;
    }
    final nameController = TextEditingController();
    final avatarController = TextEditingController();
    final pinController = TextEditingController();

    if (mounted) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Add Profile"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: avatarController,
                decoration:
                    const InputDecoration(labelText: "Avatar URL (optional)"),
              ),
              TextField(
                controller: pinController,
                decoration: const InputDecoration(labelText: "PIN (optional)"),
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Add"),
              onPressed: () async {
                if (!mounted) return;
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                if (nameController.text.trim().isEmpty) {
                  scaffoldMessenger.showSnackBar(const SnackBar(
                      content: Text("Profile name is required.")));
                  return;
                }
                try {
                  String avatarUrl = avatarController.text.trim();
                  String backgroundUrl;
                  if (avatarUrl.isEmpty) {
                    final usedAvatars = _profiles
                        .map((p) => p['avatar'] as String)
                        .where((a) => defaultAvatars.contains(a))
                        .toList();
                    final availableAvatars = defaultAvatars
                        .where((a) => !usedAvatars.contains(a))
                        .toList();
                    avatarUrl = availableAvatars.isNotEmpty
                        ? availableAvatars[
                            Random().nextInt(availableAvatars.length)]
                        : defaultAvatars[
                            Random().nextInt(defaultAvatars.length)];
                    backgroundUrl = defaultBackgrounds[
                        Random().nextInt(defaultBackgrounds.length)];
                  } else {
                    avatarUrl = _processUrl(avatarUrl);
                    backgroundUrl = defaultBackgrounds[
                        Random().nextInt(defaultBackgrounds.length)];
                  }
                  final newProfile = {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'user_id': userId,
                    'name': nameController.text.trim(),
                    'avatar': avatarUrl,
                    'backgroundImage': backgroundUrl,
                    'pin': pinController.text.trim().isEmpty
                        ? null
                        : pinController.text.trim(),
                    'locked': pinController.text.trim().isEmpty ? 0 : 1,
                    'created_at': DateTime.now().toIso8601String(),
                    'updated_at': DateTime.now().toIso8601String(),
                  };
                  debugPrint('📝 Creating profile: $newProfile');
                  await AuthDatabase.instance.createProfile(newProfile);
                  await _firestore
                      .collection('profiles')
                      .doc(newProfile['id'] as String)
                      .set(newProfile, SetOptions(merge: true));
                  Navigator.pop(context);
                  await _refreshProfiles();
                  scaffoldMessenger.showSnackBar(SnackBar(
                      content:
                          Text("Profile '${newProfile['name']}' created.")));
                } catch (e) {
                  debugPrint('❌ Error creating profile: $e');
                  scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Error creating profile')));
                }
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> _updateAvatar(Map<String, dynamic> profile) async {
    final currentAvatar = profile['avatar'] as String? ?? "";
    final avatarController = TextEditingController(text: currentAvatar);

    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Update Avatar URL"),
          content: TextField(
            controller: avatarController,
            decoration: const InputDecoration(labelText: "New Avatar URL"),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Update"),
              onPressed: () async {
                if (!mounted) return;
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final newUrl = _processUrl(avatarController.text.trim());
                if (newUrl.isEmpty) {
                  scaffoldMessenger.showSnackBar(const SnackBar(
                      content: Text("Avatar URL cannot be empty.")));
                  return;
                }
                if (newUrl == currentAvatar) {
                  Navigator.pop(context);
                  return;
                }
                profile['avatar'] = newUrl;
                try {
                  await AuthDatabase.instance.updateProfile(profile);
                  await _firestore
                      .collection('profiles')
                      .doc(profile['id'] as String)
                      .update({'avatar': newUrl});
                  Navigator.pop(context);
                  await _refreshProfiles();
                  scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text("Avatar updated.")));
                } catch (e) {
                  debugPrint('❌ Error updating avatar: $e');
                  scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Error updating avatar')));
                }
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deleteProfile(Map<String, dynamic> profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text(
            "Are you sure you want to delete profile '${profile['name']}'?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text("Delete"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final profileId = profile['id']?.toString() ?? '';
    if (profileId.isEmpty) {
      scaffoldMessenger
          .showSnackBar(const SnackBar(content: Text("Invalid profile ID.")));
      return;
    }
    try {
      await AuthDatabase.instance.deleteProfile(profileId);
      await _firestore.collection('profiles').doc(profileId).delete();
      await _refreshProfiles();
      scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("Profile '${profile['name']}' deleted.")));
    } catch (e) {
      debugPrint('❌ Error deleting profile: $e');
      scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Error deleting profile')));
    }
  }

  void _onProfileTapped(Map<String, dynamic> profile) {
    if (isEditing) return;
    if ((profile['pin'] as String?)?.isNotEmpty ?? false) {
      _showPinDialog(profile);
    } else {
      _selectProfile(profile);
    }
  }

  void _showPinDialog(Map<String, dynamic> profile) {
    final pinController = TextEditingController();
    if (mounted) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Enter PIN"),
          content: TextField(
            controller: pinController,
            decoration: const InputDecoration(labelText: "PIN"),
            keyboardType: TextInputType.number,
            obscureText: true,
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Submit"),
              onPressed: () {
                if (!mounted) return;
                if (pinController.text.trim() == profile['pin']) {
                  Navigator.pop(context);
                  _selectProfile(profile);
                } else {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            "Incorrect PIN for profile '${profile['name']}'.")),
                  );
                }
              },
            ),
          ],
        ),
      );
    }
  }

  void _selectProfile(Map<String, dynamic> profile) {
    debugPrint(
        '🚀 Navigating to HomeScreenMain with profile: ${profile['name']}');
    UserManager.instance.updateProfile(profile);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (context, animation, secondaryAnimation) =>
              HomeScreenMain(
            profileName: profile['name'] as String,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = 0.0;
            const end = 1.0;
            final scaleTween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: Curves.easeInOut));
            final fadeTween = Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeIn));
            return ScaleTransition(
              scale: animation.drive(scaleTween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  Widget _buildAddProfileTile() {
    return GestureDetector(
      onTap: _showAddProfileDialog,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: const Center(
          child: Icon(Icons.add, color: Colors.white, size: 40),
        ),
      ),
    );
  }

  Widget _buildProfileTile(Map<String, dynamic> profile, int index) {
    final name = profile['name'] as String? ?? "Unknown Profile";
    var avatar = profile['avatar'] as String? ?? "";
    final locked = (profile['locked'] as int?) == 1;

    if (avatar.isEmpty || !avatar.startsWith("http")) {
      avatar = defaultAvatars[Random().nextInt(defaultAvatars.length)];
    } else {
      avatar = _processUrl(avatar);
    }

    debugPrint('🔍 Building profile tile for: $name');

    return GestureDetector(
      onTap: () => _onProfileTapped(profile),
      child: AnimatedBorderBox(
        index: index,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: avatar.startsWith("assets/")
                          ? Image.asset(
                              avatar,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : CachedNetworkImage(
                              imageUrl: avatar,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => const Icon(
                                  Icons.error,
                                  color: Colors.redAccent),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (locked)
                      const Icon(Icons.lock, color: Colors.white, size: 20),
                    if (isEditing)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () => _updateAvatar(profile),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () => _deleteProfile(profile),
                          ),
                        ],
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                "Select Your Profile",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _profilesController.stream,
                  initialData: const [],
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      debugPrint('❌ StreamBuilder error: ${snapshot.error}');
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Error loading profiles.',
                              style: TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _refreshProfiles,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    final profiles = snapshot.data ?? [];
                    debugPrint('🔍 Profiles count: ${profiles.length}');
                    final itemCount = profiles.length < maxProfiles
                        ? profiles.length + 1
                        : profiles.length;
                    debugPrint('🔍 GridView item count: $itemCount');
                    return GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        debugPrint('🔍 Building item at index: $index');
                        if (index == profiles.length &&
                            profiles.length < maxProfiles) {
                          return _buildAddProfileTile();
                        }
                        return _buildProfileTile(profiles[index], index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            isEditing = !isEditing;
          });
        },
        backgroundColor: Colors.cyan,
        child: Icon(isEditing ? Icons.check : Icons.edit),
      ),
    );
  }
}
