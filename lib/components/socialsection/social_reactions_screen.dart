import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'feed_reel_player_screen.dart';
import '../../models/reel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:movie_app/helpers/movie_account_helper.dart';
import 'package:movie_app/components/trending_movies_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show File;
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'dart:async';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'stories.dart';
import 'messages_screen.dart';
import 'search_screen.dart';
import 'user_profile_screen.dart';
import 'realtime_feed_service.dart';
import 'streak_section.dart';
import 'notifications_section.dart';
import 'chat_screen.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:path/path.dart' as p;

class VideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final VoidCallback? onTap;

  const VideoPlayer({
    Key? key,
    required this.videoUrl,
    this.autoPlay = false,
    this.onTap,
  }) : super(key: key);

  @override
  _VideoPlayerState createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  late vp.VideoPlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller =
        vp.VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                if (widget.autoPlay) {
                  _controller.play();
                  _isPlaying = true;
                }
              });
            }
          }).catchError((error) {
            debugPrint('Error initializing video: $error');
          });
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          setState(() {
            if (_isPlaying) {
              _controller.pause();
              _isPlaying = false;
            } else {
              _controller.play();
              _isPlaying = true;
            }
          });
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: vp.VideoPlayer(_controller),
                )
              : Container(
                  color: Colors.black,
                  child: const Center(child: CircularProgressIndicator()),
                ),
          if (!_isPlaying && _controller.value.isInitialized)
            const Icon(
              Icons.play_circle_outline,
              color: Colors.white70,
              size: 50,
            ),
        ],
      ),
    );
  }
}

class SocialReactionsScreen extends StatefulWidget {
  final Color accentColor;
  const SocialReactionsScreen({super.key, required this.accentColor});

  @override
  SocialReactionsScreenState createState() => SocialReactionsScreenState();
}

class SocialReactionsScreenState extends State<SocialReactionsScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _users = [];
  List<String> _notifications = [];
  List<Map<String, dynamic>> _stories = [];
  int _movieStreak = 0;
  List<Map<String, dynamic>> _feedPosts = [];
  Map<String, dynamic>? _currentUser;
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _showRecommendations = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Pause videos when app is backgrounded
    } else if (state == AppLifecycleState.resumed) {
      // Resume video autoplay if needed
    }
  }

  Future<void> _initializeData() async {
    try {
      await Future.wait([
        _checkMovieAccount()
            .catchError((e) => debugPrint('Check movie account error: $e')),
        _loadLocalData()
            .catchError((e) => debugPrint('Load local data error: $e')),
        _loadFeedPostsFromLocal()
            .catchError((e) => debugPrint('Load feed posts error: $e')),
        _loadUsers().catchError((e) => debugPrint('Load users error: $e')),
        _loadUserData()
            .catchError((e) => debugPrint('Load user data error: $e')),
      ]);

      final sanitized = _feedPosts.map((post) {
        return post.map((key, value) {
          if (key == 'likedBy') {
            return MapEntry(
                key,
                value is List
                    ? value.map((e) => e.toString()).toList()
                    : <String>[]);
          } else if (value is List) {
            return MapEntry(key, value.map((e) => e.toString()).toList());
          } else {
            return MapEntry(key, value?.toString() ?? '');
          }
        });
      }).toList();

      RealtimeFeedService.instance.updateFeedPosts(sanitized);
      if (mounted) {
        setState(() {
          _feedPosts = sanitized;
        });
      }
    } catch (e) {
      debugPrint('Error initializing data: $e');
    }
  }

  Future<void> _checkMovieAccount() async {
    try {
      if (await MovieAccountHelper.doesMovieAccountExist()) {
        await MovieAccountHelper.getMovieAccountData();
      }
    } catch (e) {
      debugPrint('Error checking movie account: $e');
    }
  }

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storiesString = prefs.getString('stories') ?? '[]';
      final movieStreak = prefs.getInt('movieStreak') ?? 0;
      _stories = List<Map<String, dynamic>>.from(jsonDecode(storiesString));
      _movieStreak = movieStreak;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading local data: $e');
    }
  }

  Future<void> _saveLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('stories', jsonEncode(_stories));
      await prefs.setInt('movieStreak', _movieStreak);
    } catch (e) {
      debugPrint('Error saving local data: $e');
    }
  }

  Future<void> _loadFeedPostsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final feedPostsString = prefs.getString('feedPosts') ?? '[]';
      final decoded = jsonDecode(feedPostsString);
      if (decoded is List) {
        _feedPosts = decoded.map((post) {
          if (post is Map) {
            return Map<String, dynamic>.from(post);
          }
          return <String, dynamic>{};
        }).toList();
      } else {
        _feedPosts = [];
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading feed posts: $e');
      _feedPosts = [];
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveFeedPostsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('feedPosts', jsonEncode(_feedPosts));
    } catch (e) {
      debugPrint('Error saving feed posts: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (doc.exists) {
          final userData = doc.data()!;
          userData['id'] = doc.id;
          if (!mounted) return;
          setState(() {
            _currentUser = _normalizeUserData(userData);
          });
        } else {
          debugPrint('No user data found for UID: ${currentUser.uid}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User data not found")),
          );
        }
      } else {
        if (!mounted) return;
        setState(() {
          _currentUser = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please log in to view your profile")),
        );
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (!mounted) return;
      setState(() {
        _currentUser = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading profile: $e")),
      );
    }
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final rawUsers = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID
        return data;
      }).toList();
      debugPrint('Raw users: $rawUsers'); // Log raw data for inspection
      _users = rawUsers
          .map((u) => _normalizeUserData(Map<String, dynamic>.from(u)))
          .toList();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  Map<String, dynamic> _normalizeUserData(Map<String, dynamic> user) {
    return {
      'id': user['id']?.toString() ?? '',
      'username': user['username']?.toString() ?? 'Unknown',
      'email': user['email']?.toString() ?? '',
      'bio': user['bio']?.toString() ?? '',
      'password': user['password']?.toString() ?? '',
      'auth_provider': user['auth_provider']?.toString() ?? '',
      'token': user['token']?.toString() ?? '',
      'created_at': user['created_at']?.toString() ?? '',
      'updated_at':
          user['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      'followers_count': user['followers_count']?.toString() ?? '0',
      'following_count': user['following_count']?.toString() ?? '0',
      'avatar': user['avatar']?.toString() ?? 'https://via.placeholder.com/200',
    };
  }

  Future<dynamic> pickFile(String type) async {
    if (kIsWeb) {
      final html.FileUploadInputElement input = html.FileUploadInputElement();
      input.accept = type == 'photo' ? 'image/jpeg,image/png' : 'video/mp4';
      input.click();
      await input.onChange.first;
      if (input.files!.isNotEmpty) {
        return input.files!.first;
      }
    } else {
      final picker = ImagePicker();
      if (type == 'photo') {
        return await picker.pickImage(source: ImageSource.gallery);
      } else {
        return await picker.pickVideo(source: ImageSource.gallery);
      }
    }
    return null;
  }

  Future<String> uploadMedia(
      dynamic mediaFile, String type, BuildContext context) async {
    try {
      final mediaId = const Uuid().v4();
      String filePath;
      String contentType;

      if (kIsWeb) {
        if (mediaFile is html.File) {
          final fileSizeInBytes = mediaFile.size;
          if (type == 'photo' && fileSizeInBytes > 5 * 1024 * 1024) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Image too large, max 5MB allowed")));
            return 'https://via.placeholder.com/150';
          } else if (type == 'video' && fileSizeInBytes > 20 * 1024 * 1024) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Video too large, max 20MB allowed")));
            return 'https://via.placeholder.com/150';
          }
          final extension = mediaFile.name.split('.').last.toLowerCase();
          filePath = 'media/$mediaId.$extension';
          contentType = mediaFile.type;
          final reader = html.FileReader();
          reader.readAsArrayBuffer(mediaFile);
          await reader.onLoad.first;
          Uint8List bytes = reader.result as Uint8List;
          await _supabase.storage.from('feeds').uploadBinary(
                filePath,
                bytes,
                fileOptions: FileOptions(contentType: contentType),
              );
        } else {
          debugPrint('Invalid file type for web platform');
          return 'https://via.placeholder.com/150';
        }
      } else {
        if (mediaFile is XFile) {
          final file = File(mediaFile.path);
          int fileSizeInBytes = await file.length();
          if (type == 'photo' && fileSizeInBytes > 5 * 1024 * 1024) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Image too large, max 5MB allowed")));
            return 'https://via.placeholder.com/150';
          } else if (type == 'video' && fileSizeInBytes > 20 * 1024 * 1024) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Video too large, max 20MB allowed")));
            return 'https://via.placeholder.com/150';
          }
          final extension = p.extension(mediaFile.path).replaceFirst('.', '');
          filePath = 'media/$mediaId.$extension';
          contentType = getMimeType(extension);
          await _supabase.storage.from('feeds').upload(
                filePath,
                file,
                fileOptions: FileOptions(contentType: contentType),
              );
        } else {
          debugPrint('Invalid file type');
          return 'https://via.placeholder.com/150';
        }
      }

      final url = _supabase.storage.from('feeds').getPublicUrl(filePath);
      return url.isNotEmpty ? url : 'https://via.placeholder.com/150';
    } catch (e) {
      debugPrint('Error uploading media: $e');
      return 'https://via.placeholder.com/150';
    }
  }

  String getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _postStory() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.white),
              title: const Text("Upload Photo",
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text("Upload Video",
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );

    if (choice != null && mounted) {
      dynamic pickedFile = await pickFile(choice);
      if (pickedFile != null) {
        final user = _currentUser?['username'] ?? 'CurrentUser';
        final timestamp = DateTime.now().toIso8601String();
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text("Uploading..."),
              ],
            ),
          ),
        );
        try {
          final uploadedUrl = await uploadMedia(pickedFile, choice, context);
          if (!mounted) return;
          if (uploadedUrl.isNotEmpty &&
              uploadedUrl != 'https://via.placeholder.com/150') {
            final story = {
              'user': user,
              'userId': _currentUser?['id']?.toString() ?? '',
              'media': uploadedUrl,
              'type': choice,
              'timestamp': timestamp,
            };
            final docRef = await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUser?['id']?.toString())
                .collection('stories')
                .add(story);
            story['id'] = docRef.id;
            await FirebaseFirestore.instance.collection('stories').add(story);
            setState(() {
              _stories.add(story);
              final newPost = {
                'user': user,
                'userId': _currentUser?['id']?.toString() ?? '',
                'post': '$user posted a story.',
                'type': 'story',
                'likedBy': [],
                'timestamp': timestamp,
              };
              _feedPosts.add(newPost);
              RealtimeFeedService.instance.addPost(newPost);
            });
            await _saveFeedPostsToLocal();
            await _saveLocalData();
          } else {
            debugPrint('Failed to upload story media');
          }
        } catch (e) {
          debugPrint('Error posting story: $e');
        } finally {
          if (mounted) Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _postMovieReview() async {
    final movieController = TextEditingController();
    final reviewController = TextEditingController();
    final episodeController = TextEditingController();
    final seasonController = TextEditingController();
    dynamic mediaFile;
    String? mediaType;
    bool isTVShow = false;

    await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color.fromARGB(255, 17, 25, 40),
            title: const Text("Write a Review",
                style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              !isTVShow ? widget.accentColor : Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => setStateDialog(() => isTVShow = false),
                        child: const Text("Movie"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isTVShow ? widget.accentColor : Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => setStateDialog(() => isTVShow = true),
                        child: const Text("TV Show"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: movieController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Movie/TV Show Name",
                      hintStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                    ),
                  ),
                  if (isTVShow) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: seasonController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Season Name",
                        hintStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: episodeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Episode Name/Number",
                        hintStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: reviewController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Enter your review...",
                      hintStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  if (mediaFile != null)
                    kIsWeb
                        ? const Text("Media selected",
                            style: TextStyle(color: Colors.white70))
                        : mediaType == 'photo'
                            ? Image.file(File((mediaFile as XFile).path),
                                height: 150, fit: BoxFit.cover)
                            : const Text("Video selected",
                                style: TextStyle(color: Colors.white70)),
                  TextButton.icon(
                    icon: const Icon(Icons.image, color: Colors.white70),
                    label: const Text("Pick Media",
                        style: TextStyle(color: Colors.white70)),
                    onPressed: () async {
                      final choice = await showModalBottomSheet<String>(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo,
                                    color: Colors.white),
                                title: const Text("Upload Photo",
                                    style: TextStyle(color: Colors.white)),
                                onTap: () => Navigator.pop(context, 'photo'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.videocam,
                                    color: Colors.white),
                                title: const Text("Upload Video",
                                    style: TextStyle(color: Colors.white)),
                                onTap: () => Navigator.pop(context, 'video'),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (choice != null) {
                        final picked = await pickFile(choice);
                        if (picked != null) {
                          setStateDialog(() {
                            mediaFile = picked;
                            mediaType = choice;
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
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
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  if (movieController.text.trim().isEmpty ||
                      reviewController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Please fill in all fields")),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'title': movieController.text.trim(),
                    'review': reviewController.text.trim(),
                    'season': seasonController.text.trim(),
                    'episode': episodeController.text.trim(),
                    'media': mediaFile,
                    'mediaType': mediaType,
                    'isTVShow': isTVShow,
                  });
                },
                child: const Text("Post"),
              ),
            ],
          );
        });
      },
    ).then((result) async {
      if (result != null && mounted) {
        String? mediaUrl;
        try {
          if (result['media'] != null) {
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text("Uploading Review...🔥"),
                  ],
                ),
              ),
            );
            mediaUrl = await uploadMedia(
                result['media'], result['mediaType']!, context);
            if (mediaUrl == 'https://via.placeholder.com/150') {
              debugPrint('Failed to upload review media');
            }
          }
          if (!mounted) return;
          final newPost = {
            'user': _currentUser?['username'] ?? 'CurrentUser',
            'userId': _currentUser?['id']?.toString() ?? '',
            'post': result['isTVShow']
                ? "Reviewed ${result['title']} S${result['season']}: E${result['episode']} - ${result['review']}"
                : "Reviewed ${result['title']}: ${result['review']}",
            'type': 'review',
            'likedBy': [],
            'title': result['title'],
            'season': result['season'],
            'episode': result['episode'],
            'media': mediaUrl,
            'mediaType': mediaUrl != null ? result['mediaType'] ?? '' : '',
            'timestamp': DateTime.now().toIso8601String(),
          };
          final docRef = await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser?['id']?.toString())
              .collection('posts')
              .add(newPost);
          newPost['id'] = docRef.id;
          await FirebaseFirestore.instance.collection('feeds').add(newPost);
          setState(() {
            _feedPosts.add(newPost);
            RealtimeFeedService.instance.addPost(newPost);
            _notifications.add(
                "${_currentUser?['username'] ?? 'CurrentUser'} posted a review for ${result['title']}");
          });
          await _saveFeedPostsToLocal();
        } catch (e) {
          debugPrint('Error posting review: $e');
        } finally {
          if (mounted) Navigator.pop(context);
        }
      }
    });
  }

  Widget _buildFeedTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: _postMovieReview,
            icon: const Icon(Icons.rate_review, size: 20),
            label:
                const Text("Post Movie Review", style: TextStyle(fontSize: 16)),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('feeds').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Error in feed stream: ${snapshot.error}');
                return const Center(
                    child: Text('Failed to load feed.',
                        style: TextStyle(color: Colors.white)));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final posts = snapshot.data!.docs.map((doc) {
                final data = doc.data()! as Map<String, dynamic>;
                return {
                  'id': doc.id,
                  'user': (data['user'] as String?) ?? '',
                  'post': (data['post'] as String?) ?? '',
                  'type': (data['type'] as String?) ?? '',
                  'likedBy': (data['likedBy'] as List?)
                          ?.where((item) => item != null)
                          .map((item) => item.toString())
                          .toList() ??
                      [],
                  'title': (data['title'] as String?) ?? '',
                  'season': (data['season'] as String?) ?? '',
                  'episode': (data['episode'] as String?) ?? '',
                  'media': (data['media'] as String?) ?? '',
                  'mediaType': (data['mediaType'] as String?) ?? '',
                  'timestamp': (data['timestamp'] as String?) ?? '',
                  'userId': (data['userId'] as String?) ?? '',
                };
              }).toList();

              if (posts.isEmpty) {
                return const Center(
                    child: Text("No posts available.",
                        style: TextStyle(color: Colors.white)));
              }

              return ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  try {
                    return _buildPostCard(posts[index], posts);
                  } catch (e) {
                    debugPrint('Error building post card at index $index: $e');
                    debugPrint('Post data: ${posts[index]}');
                    return const SizedBox.shrink();
                  }
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recommended Movies",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                                color: Colors.black45,
                                offset: Offset(1, 1),
                                blurRadius: 2)
                          ])),
                  IconButton(
                    icon: Icon(_showRecommendations ? Icons.remove : Icons.add,
                        color: Colors.white),
                    onPressed: () => setState(
                        () => _showRecommendations = !_showRecommendations),
                  ),
                ],
              ),
              Visibility(
                visible: _showRecommendations,
                child: const Column(
                  children: [
                    SizedBox(height: 12),
                    TrendingMoviesWidget(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(
    Map<String, dynamic> post,
    List<Map<String, dynamic>> allPosts,
  ) {
    final id = post['id'] as String? ?? '';
    final userName = post['user'] as String? ?? 'Unknown';
    final message = post['post'] as String? ?? '';
    final likedBy = (post['likedBy'] as List?)
            ?.where((item) => item != null)
            .map((item) => item.toString())
            .toList() ??
        [];
    final title = post['title'] as String? ?? '';
    final season = post['season'] as String? ?? '';
    final episode = post['episode'] as String? ?? '';
    final media = post['media'] as String? ?? '';
    final mediaType = post['mediaType'] as String? ?? '';
    final userId = post['userId'] as String? ?? '';
    // 2) Lookup user record
    final userRecord = _users.firstWhere(
      (u) => (u['id'] as String?) == userId,
      orElse: () => {'username': userName, 'avatar': ''},
    );
    final username = userRecord['username'] as String? ?? 'Unknown';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final avatarUrl = userRecord['avatar'] as String? ?? '';

    // 3) Like state
    final isLiked = likedBy.contains((_currentUser?['id'] as String?) ?? '');

    // 4) URL validator
    bool isValidImageUrl(String url) =>
        url.startsWith('http') &&
        (url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.png'));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.accentColor.withOpacity(0.1),
              widget.accentColor.withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.accentColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + username
            ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child:
                    Text(initial, style: const TextStyle(color: Colors.white)),
              ),
              title: Text(
                username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                        color: Colors.black45,
                        offset: Offset(1, 1),
                        blurRadius: 2)
                  ],
                ),
              ),
            ),

            // Photo or video
            if (media.isNotEmpty)
              if (mediaType == 'photo' && isValidImageUrl(media))
                CachedNetworkImage(
                  imageUrl: media,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (c, u) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (c, u, e) => Container(
                      height: 300,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 40)),
                )
              else if (mediaType == 'video')
                SizedBox(
                  height: 300,
                  child: VideoPlayer(
                    videoUrl: media,
                    autoPlay: true,
                    onTap: () {
                      final videoPosts = allPosts
                          .where((p) =>
                              (p['mediaType'] as String?) == 'video' &&
                              (p['media'] as String?)?.isNotEmpty == true)
                          .map((p) => Reel(
                                videoUrl: (p['media'] as String?) ?? '',
                                movieTitle: (p['title'] as String?) ?? 'Video',
                                movieDescription: (p['post'] as String?) ?? '',
                              ))
                          .toList();
                      final idx =
                          videoPosts.indexWhere((r) => r.videoUrl == media);
                      if (idx != -1) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FeedReelPlayerScreen(
                                reels: videoPosts, initialIndex: idx),
                          ),
                        );
                      }
                    },
                  ),
                )
              else
                Container(
                    height: 300,
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.image, size: 40))),

            // Text + meta
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message,
                      style:
                          const TextStyle(fontSize: 15, color: Colors.white70)),
                  if (season.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Season: $season, Episode: ${episode.isNotEmpty ? episode : 'N/A'}",
                        style: const TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.white70),
                      ),
                    ),
                  if (title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text("Movie: $title",
                          style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.white70)),
                    ),
                ],
              ),
            ),

            const Divider(color: Colors.white54, height: 1),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Like
                GestureDetector(
                  onTap: () async {
                    final ref =
                        FirebaseFirestore.instance.collection('feeds').doc(id);
                    if (isLiked) {
                      await ref.update({
                        'likedBy': FieldValue.arrayRemove(
                            [(_currentUser?['id'] as String?) ?? ''])
                      });
                    } else {
                      await ref.update({
                        'likedBy': FieldValue.arrayUnion(
                            [(_currentUser?['id'] as String?) ?? ''])
                      });
                    }
                  },
                  child: Row(
                    children: [
                      Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.white70,
                          size: 22),
                      const SizedBox(width: 4),
                      Text(likedBy.length.toString(),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),

                // Comment
                IconButton(
                    icon: const Icon(Icons.comment,
                        color: Colors.white70, size: 22),
                    onPressed: () => _showComments(post)),

                // Share
                IconButton(
                    icon: const Icon(Icons.share,
                        color: Colors.white70, size: 22),
                    onPressed: () => _sharePost(post)),

                // Send / watch party
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white70, size: 22),
                  onPressed: () {
                    final code = _generateWatchCode();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Started Watch Party: Code $code")));
                    _notifications.add(
                        "${(_currentUser?['username'] as String?) ?? 'CurrentUser'} started a watch party with code $code");
                  },
                ),

                // Delete (owner only)
                if (userId == ((_currentUser?['id'] as String?) ?? ''))
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('feeds')
                          .doc(id)
                          .delete();
                      setState(
                          () => _feedPosts.removeWhere((p) => p['id'] == id));
                      await _saveFeedPostsToLocal();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesTab() {
    return Column(
      children: [
        SizedBox(
          height: 100,
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('stories').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Error in stories stream: ${snapshot.error}');
                return const Center(
                    child: Text('Failed to load stories.',
                        style: TextStyle(color: Colors.white)));
              }
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              final stories = snapshot.data!.docs
                  .map((doc) =>
                      {...doc.data() as Map<String, dynamic>, 'id': doc.id})
                  .where((story) =>
                      DateTime.now()
                          .difference(DateTime.parse(story['timestamp'])) <
                      const Duration(hours: 24))
                  .toList();

              final Map<String, List<Map<String, dynamic>>> groupedStories = {};
              for (var story in stories) {
                final userId = story['userId'] as String;
                if (!groupedStories.containsKey(userId))
                  groupedStories[userId] = [];
                groupedStories[userId]!.add(story);
              }

              if (groupedStories.isEmpty) {
                return const Center(
                    child: Text("No stories available.",
                        style: TextStyle(color: Colors.white)));
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: groupedStories.length,
                itemBuilder: (context, index) {
                  final userId = groupedStories.keys.elementAt(index);
                  final userStories = groupedStories[userId]!;
                  final firstStory = userStories.first;
                  final mediaUrl = firstStory['media'] as String?;
                  final isValidPhotoUrl = mediaUrl != null &&
                      mediaUrl.isNotEmpty &&
                      (mediaUrl.startsWith('http') &&
                          (mediaUrl.endsWith('.jpg') ||
                              mediaUrl.endsWith('.png') ||
                              mediaUrl.endsWith('.jpeg')));

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoryScreen(
                            stories: userStories,
                            initialIndex: 0,
                            currentUserId:
                                (_currentUser?['id'] ?? '').toString(),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: firstStory['type'] == 'photo' &&
                                      isValidPhotoUrl
                                  ? DecorationImage(
                                      image: NetworkImage(mediaUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: firstStory['type'] == 'video'
                                  ? Colors.black
                                  : Colors.grey,
                              border: Border.all(
                                  color: Colors.yellow.withOpacity(0.8),
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.yellow.withOpacity(0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1)
                              ],
                            ),
                            child: firstStory['type'] == 'video'
                                ? const Icon(Icons.videocam,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            firstStory['user'] ?? 'Unknown',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                shadows: [
                                  Shadow(
                                      color: Colors.black45,
                                      offset: Offset(1, 1),
                                      blurRadius: 2)
                                ]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: _postStory,
            icon: const Icon(Icons.add_a_photo, size: 20),
            label: const Text("Post Story", style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  String _generateWatchCode() => (100000 + Random().nextInt(900000)).toString();

  void _showComments(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromARGB(255, 17, 25, 40),
      builder: (context) {
        final controller = TextEditingController();
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(post['userId'])
                    .collection('posts')
                    .doc(post['id'])
                    .collection('comments')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('Error in comments stream: ${snapshot.error}');
                    return const Center(
                        child: Text('Failed to load comments.',
                            style: TextStyle(color: Colors.white)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = snapshot.data!.docs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList();
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text("Comments",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        Expanded(
                          child: ListView.builder(
                            itemCount: comments.length,
                            itemBuilder: (_, i) => ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(comments[i]
                                        ['userAvatar'] ??
                                    'https://via.placeholder.com/50'),
                                radius: 20,
                              ),
                              title: Text(
                                comments[i]['username'] ?? 'Unknown',
                                style: TextStyle(
                                    color: widget.accentColor,
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(comments[i]['text'] ?? '',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                            ),
                          ),
                        ),
                        TextField(
                          controller: controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Add a comment",
                            labelStyle: TextStyle(color: Colors.white54),
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54)),
                            focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: () {
                            if (controller.text.isNotEmpty) {
                              try {
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(post['userId'])
                                    .collection('posts')
                                    .doc(post['id'])
                                    .collection('comments')
                                    .add({
                                  'text': controller.text,
                                  'userId': _currentUser?['id'],
                                  'username': _currentUser?['username'],
                                  'userAvatar': _currentUser?['avatar'],
                                  'timestamp': DateTime.now().toIso8601String(),
                                });
                                controller.clear();
                              } catch (e) {
                                debugPrint('Error posting comment: $e');
                              }
                            }
                          },
                          child: const Text("Post",
                              style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _sharePost(Map<String, dynamic> post) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Shared post: ${post['post'] ?? 'Unknown'}")));
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _showFabActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 17, 25, 40),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.message, color: Colors.white),
              title: const Text("New Message",
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                if (_currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NewChatScreen(
                        currentUser: _currentUser!,
                        otherUsers: _users
                            .where((u) => u['email'] != _currentUser!['email'])
                            .toList(),
                        accentColor: widget.accentColor,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("User data not loaded")));
                }
              },
            ),
            if (!_showRecommendations)
              ListTile(
                leading: const Icon(Icons.expand, color: Colors.white),
                title: const Text("Expand Recommendations",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _showRecommendations = true);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildFeedTab(),
      _buildStoriesTab(),
      NotificationsSection(notifications: _notifications),
      StreakSection(
        movieStreak: _movieStreak,
        onStreakUpdated: (newStreak) =>
            setState(() => _movieStreak = newStreak),
      ),
      _currentUser != null
          ? UserProfileScreen(
              user: _currentUser!,
              showAppBar: false,
              accentColor: widget.accentColor)
          : const Center(child: CircularProgressIndicator()),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Social Section",
            style: TextStyle(color: Colors.white, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.message, color: Colors.white, size: 22),
            onPressed: () => _currentUser != null
                ? Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessagesScreen(
                        currentUser: _currentUser!,
                        otherUsers: _users
                            .where((u) => u['email'] != _currentUser!['email'])
                            .toList(),
                      ),
                    ),
                  )
                : ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User data not loaded")),
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 22),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          if (_currentUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  "Hello, ${_currentUser!['username']}",
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 16),
                ),
              ),
            ),
        ],
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
                      child: Theme(
                          data: ThemeData.dark(), child: tabs[_selectedIndex]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.accentColor,
        onPressed: _showFabActions,
        child: const Icon(Icons.add, color: Colors.white, size: 22),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        backgroundColor: Colors.black87,
        selectedItemColor: const Color(0xffffeb00),
        unselectedItemColor: widget.accentColor,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 22), label: "Feeds"),
          BottomNavigationBarItem(
              icon: Icon(Icons.history, size: 22), label: "Stories"),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications, size: 22),
              label: "Notifications"),
          BottomNavigationBarItem(
              icon: Icon(Icons.whatshot, size: 22), label: "Streaks"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 22), label: "Profile"),
        ],
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
  NewChatScreenState createState() => NewChatScreenState();
}

class NewChatScreenState extends State<NewChatScreen> {
  void _startChat(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IndividualChatScreen(
          currentUser: widget.currentUser,
          otherUser: {
            'id': user['id'],
            'username': user['username'],
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "New Chat",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Container(
            color: const Color(0xFF111927),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.1, -0.4),
                radius: 1.2,
                colors: [
                  widget.accentColor.withOpacity(0.4),
                  Colors.black,
                ],
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
                      Colors.transparent,
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
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.otherUsers.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: Colors.white54,
                        ),
                        itemBuilder: (context, index) {
                          final user = widget.otherUsers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: widget.accentColor,
                              child: Text(
                                user['username'][0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              user['username']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            onTap: () => _startChat(user),
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
    );
  }
}
