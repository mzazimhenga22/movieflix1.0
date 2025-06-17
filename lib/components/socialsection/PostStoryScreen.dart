import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io' show File;
import 'dart:typed_data';

class PostStoryScreen extends StatefulWidget {
  final Color accentColor;
  final Map<String, dynamic> currentUser;

  const PostStoryScreen({
    Key? key,
    required this.accentColor,
    required this.currentUser,
  }) : super(key: key);

  @override
  _PostStoryScreenState createState() => _PostStoryScreenState();
}

class _PostStoryScreenState extends State<PostStoryScreen> {
  List<Map<String, dynamic>> mediaItems = [];
  bool isPosting = false;
  final SupabaseClient _supabase = Supabase.instance.client;

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
      final mediaId = DateTime.now().millisecondsSinceEpoch.toString();
      String filePath;
      String contentType;

      if (kIsWeb) {
        if (mediaFile is html.File) {
          final extension = mediaFile.name.split('.').last.toLowerCase();
          filePath = 'media/$mediaId.$extension';
          contentType = mediaFile.type;
          final reader = html.FileReader();
          reader.readAsArrayBuffer(mediaFile);
          await reader.onLoad.first;
          final bytes = reader.result as Uint8List;
          await _supabase.storage.from('feeds').uploadBinary(
                filePath,
                bytes,
                fileOptions: FileOptions(contentType: contentType),
              );
        } else {
          throw Exception('Invalid file type for web');
        }
      } else {
        if (mediaFile is XFile) {
          final file = File(mediaFile.path);
          final extension = mediaFile.path.split('.').last.toLowerCase();
          filePath = 'media/$mediaId.$extension';
          contentType = getMimeType(extension);
          await _supabase.storage.from('feeds').upload(
                filePath,
                file,
                fileOptions: FileOptions(contentType: contentType),
              );
        } else {
          throw Exception('Invalid file type');
        }
      }

      final url = _supabase.storage.from('feeds').getPublicUrl(filePath);
      return url.isNotEmpty ? url : 'https://via.placeholder.com/150';
    } catch (e) {
      debugPrint('Error uploading media: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading media: $e')),
      );
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

  Future<void> _addMedia() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color.fromARGB(255, 17, 25, 40),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo, color: widget.accentColor),
              title: const Text("Upload Photo",
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: widget.accentColor),
              title: const Text("Upload Video",
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice != null) {
      dynamic pickedFile = await pickFile(choice);
      if (pickedFile != null) {
        Map<String, dynamic> newItem = {
          'type': choice,
          'file': pickedFile,
          'captionController': TextEditingController(),
        };
        if (kIsWeb) {
          final file = pickedFile as html.File;
          final url = html.Url.createObjectUrl(file);
          newItem['url'] = url;
        }
        setState(() {
          mediaItems.add(newItem);
        });
      }
    }
  }

  Future<void> _postStories() async {
    if (mediaItems.isEmpty) return;
    setState(() => isPosting = true);
    try {
      for (var item in mediaItems) {
        final uploadedUrl =
            await uploadMedia(item['file'], item['type'], context);
        if (uploadedUrl.isNotEmpty &&
            uploadedUrl != 'https://via.placeholder.com/150') {
          final story = {
            'user': widget.currentUser['username'],
            'userId': widget.currentUser['id'],
            'media': uploadedUrl,
            'type': item['type'],
            'caption': item['captionController'].text,
            'timestamp': DateTime.now().toIso8601String(),
          };
          final docRef = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.currentUser['id'])
              .collection('stories')
              .add(story);
          await FirebaseFirestore.instance.collection('stories').add(story);
          final newPost = {
            'id': docRef.id,
            'user': widget.currentUser['username'],
            'userId': widget.currentUser['id'],
            'post': '${widget.currentUser['username']} posted a story.',
            'type': 'story',
            'likedBy': [],
            'timestamp': DateTime.now().toIso8601String(),
          };
          await FirebaseFirestore.instance.collection('feeds').add(newPost);
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stories posted successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error posting stories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post stories: $e')),
      );
    } finally {
      setState(() => isPosting = false);
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      for (var item in mediaItems) {
        if (item.containsKey('url')) {
          html.Url.revokeObjectUrl(item['url']);
        }
      }
    }
    for (var item in mediaItems) {
      item['captionController'].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:
            const Text('Post Stories', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: mediaItems.isEmpty
                ? const Center(
                    child: Text('Add media to post stories',
                        style: TextStyle(color: Colors.white)))
                : ListView.builder(
                    itemCount: mediaItems.length,
                    itemBuilder: (context, index) {
                      final item = mediaItems[index];
                      return StoryMediaItem(
                        item: item,
                        onRemove: () {
                          setState(() {
                            if (kIsWeb && item.containsKey('url')) {
                              html.Url.revokeObjectUrl(item['url']);
                            }
                            mediaItems.removeAt(index);
                          });
                        },
                      );
                    },
                  ),
          ),
          if (mediaItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: isPosting ? null : _postStories,
                child: isPosting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Post Stories'),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.accentColor,
        onPressed: _addMedia,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class StoryMediaItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRemove;

  const StoryMediaItem({Key? key, required this.item, required this.onRemove})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (item['type'] == 'photo') {
      if (kIsWeb) {
        preview = Image.network(item['url'], fit: BoxFit.cover, height: 150);
      } else {
        preview = Image.file(File((item['file'] as XFile).path),
            fit: BoxFit.cover, height: 150);
      }
    } else {
      preview = Container(
        height: 150,
        color: Colors.grey[800],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam, size: 40, color: Colors.white),
              Text(
                kIsWeb
                    ? (item['file'] as html.File).name
                    : (item['file'] as XFile).name,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        children: [
          Stack(
            children: [
              preview,
              Positioned(
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: item['captionController'],
              decoration: const InputDecoration(
                labelText: 'Caption',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
