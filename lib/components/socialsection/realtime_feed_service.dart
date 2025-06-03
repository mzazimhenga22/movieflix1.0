// realtime_feed_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class RealtimeFeedService {
  static final RealtimeFeedService instance = RealtimeFeedService._internal();
  RealtimeFeedService._internal();

  final _feedPostsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> get feedPostsStream =>
      _feedPostsController.stream;

  List<Map<String, dynamic>> _feedPosts = [];

  void updateFeedPosts(List<Map<String, dynamic>> posts) {
    _feedPosts = posts;
    _feedPostsController.add(_feedPosts);
  }

  void addPost(Map<String, dynamic> post) {
    _feedPosts.add(post);
    _feedPostsController.add(_feedPosts);
  }

  void dispose() {
    _feedPostsController.close();
  }
}
