import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show File;
import 'dart:ui';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Color accentColor;
  final Function(Map<String, dynamic>) onProfileUpdated;

  const EditProfileScreen({
    super.key,
    required this.user,
    required this.accentColor,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late Map<String, dynamic> _user;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _usernameController.text = _user['username'] ?? _user['name'] ?? "";
    _emailController.text = _user['email'] ?? "";
    _bioController.text = _user['bio'] ?? "";
    _avatarPath = _user['avatar'];
  }

  ImageProvider _buildAvatarImage() {
    if (_avatarPath != null && _avatarPath!.isNotEmpty) {
      if (kIsWeb || _avatarPath!.startsWith("http")) {
        return NetworkImage(_avatarPath!);
      } else {
        return FileImage(File(_avatarPath!));
      }
    }
    return const NetworkImage("https://via.placeholder.com/200");
  }

  Future<String> uploadMedia(String path) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      return 'https://via.placeholder.com/400';
    } catch (e) {
      debugPrint('Error uploading media: $e');
      return 'https://via.placeholder.com/150';
    }
  }

  Future<List<String>> _fetchMovieImages() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('posts')
        .where('mediaType', isEqualTo: 'photo')
        .get();
    return snapshot.docs
        .map((doc) => doc.data()['media'] as String?)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
  }

  void _showAvatarOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 17, 25, 40),
        title: const Text("Change Profile Picture",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload, color: Colors.white70),
              title: const Text("Upload Image",
                  style: TextStyle(color: Colors.white70)),
              onTap: () async {
                Navigator.pop(context);
                final ImagePicker picker = ImagePicker();
                final XFile? image =
                    await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  setState(() => _avatarPath = image.path);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.movie, color: Colors.white70),
              title: const Text("Select from Movie Posts",
                  style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _showMovieImagesDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showMovieImagesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 17, 25, 40),
        title: const Text("Select Movie Image",
            style: TextStyle(color: Colors.white)),
        content: FutureBuilder<List<String>>(
          future: _fetchMovieImages(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Text("No movie images available.",
                  style: TextStyle(color: Colors.white70));
            }
            final images = snapshot.data!;
            return SizedBox(
              width: double.maxFinite,
              height: 300,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final imageUrl = images[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _avatarPath = imageUrl);
                      Navigator.pop(context);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Edit Profile",
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _showAvatarOptions,
                              child: CircleAvatar(
                                radius: 40,
                                backgroundImage: _buildAvatarImage(),
                                child: _avatarPath == null
                                    ? Text(
                                        (_usernameController.text.isNotEmpty
                                                ? _usernameController.text[0]
                                                : "G")
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 36, color: Colors.white),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _usernameController,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: "Username",
                                labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.6)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailController,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: "Email",
                                labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.6)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _bioController,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: "Bio",
                                labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.6)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Cancel",
                                      style: TextStyle(color: Colors.white70)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.accentColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 20),
                                  ),
                                  onPressed: () async {
                                    String? avatarUrl = _avatarPath;
                                    if (_avatarPath != null &&
                                        !_avatarPath!.startsWith("http")) {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => AlertDialog(
                                          backgroundColor: const Color.fromARGB(
                                              255, 17, 25, 40),
                                          content: const Row(
                                            children: [
                                              CircularProgressIndicator(),
                                              SizedBox(width: 16),
                                              Text("Uploading avatar...",
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ],
                                          ),
                                        ),
                                      );
                                      avatarUrl =
                                          await uploadMedia(_avatarPath!);
                                      Navigator.pop(context);
                                    }
                                    final updatedUser = {
                                      ..._user,
                                      'username':
                                          _usernameController.text.trim(),
                                      'email': _emailController.text.trim(),
                                      'bio': _bioController.text.trim(),
                                      'avatar': avatarUrl,
                                    };
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(_user['id'])
                                        .update({
                                      'username':
                                          _usernameController.text.trim(),
                                      'email': _emailController.text.trim(),
                                      'bio': _bioController.text.trim(),
                                      'avatar': avatarUrl,
                                      'updated_at':
                                          DateTime.now().toIso8601String(),
                                    });
                                    widget.onProfileUpdated(updatedUser);
                                    Navigator.pop(context);
                                  },
                                  child: const Text("Save",
                                      style: TextStyle(fontSize: 16)),
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
            ),
          ),
        ],
      ),
    );
  }
}
