import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast_web/sembast_web.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:uuid/uuid.dart';
import 'dart:async';

class AuthDatabase {
  static final AuthDatabase instance = AuthDatabase._init();

  sqflite.Database? _sqfliteDb;
  sembast.Database? _sembastDb;
  final firestore.FirebaseFirestore _firestore =
      firestore.FirebaseFirestore.instance;
  bool _isInitialized = false;
  final Uuid _uuid = Uuid();

  final _userStore = sembast.stringMapStoreFactory.store('users');
  final _profileStore = sembast.stringMapStoreFactory.store('profiles');
  final _messageStore = sembast.stringMapStoreFactory.store('messages');
  final _conversationStore =
      sembast.stringMapStoreFactory.store('conversations');
  final _followersStore = sembast.stringMapStoreFactory.store('followers');

  // Map to hold message subscriptions for each conversation
  Map<String, StreamSubscription> _messageSubscriptions = {};

  // Subscriptions for other collections
  StreamSubscription? _userSubscription;
  StreamSubscription? _profilesSubscription;
  StreamSubscription? _conversationsSubscription;
  StreamSubscription? _followersSubscription;

  AuthDatabase._init();

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await database;
      _isInitialized = true;
      debugPrint('Database initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize database: $e');
      rethrow;
    }
  }

  Future<dynamic> get database async {
    if (kIsWeb) {
      _sembastDb ??= await databaseFactoryWeb.openDatabase('auth.db');
      return _sembastDb!;
    } else {
      _sqfliteDb ??= await _initializeSqflite();
      return _sqfliteDb!;
    }
  }

  Future<sqflite.Database> _initializeSqflite() async {
    try {
      final dbPath = await sqflite.getDatabasesPath();
      final path = join(dbPath, 'auth.db');
      final db = await sqflite.openDatabase(
        path,
        version: 1,
        onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSQLiteDB,
      );
      debugPrint('SQLite database opened at $path');
      final tables = [
        'users',
        'profiles',
        'messages',
        'conversations',
        'followers'
      ];
      for (var table in tables) {
        if (!await _tableExists(db, table)) {
          debugPrint('Warning: Table $table does not exist');
        }
      }
      return db;
    } catch (e) {
      debugPrint('Failed to initialize SQLite database: $e');
      throw Exception('Failed to initialize SQLite database: $e');
    }
  }

  Future<void> _createSQLiteDB(sqflite.Database db, int version) async {
    try {
      const idType = 'TEXT PRIMARY KEY';
      const textType = 'TEXT NOT NULL';

      await db.execute('''
        CREATE TABLE users (
          id $idType,
          username $textType,
          email $textType,
          bio TEXT,
          password $textType,
          auth_provider $textType,
          token TEXT,
          created_at TEXT,
          updated_at TEXT,
          followers_count TEXT DEFAULT '0',
          following_count TEXT DEFAULT '0',
          avatar TEXT DEFAULT 'https://via.placeholder.com/200'
        )
      ''');

      await db.execute('''
        CREATE TABLE profiles (
          id $idType,
          user_id TEXT NOT NULL,
          name $textType,
          avatar $textType,
          backgroundImage TEXT,
          pin TEXT,
          locked INTEGER NOT NULL DEFAULT 0,
          preferences TEXT DEFAULT '',
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');

      await db
          .execute('CREATE INDEX idx_profiles_user_id ON profiles(user_id)');

      await db.execute('''
CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  sender_id TEXT NOT NULL,
  receiver_id TEXT,  -- No foreign key constraint
  conversation_id TEXT NOT NULL,
  message TEXT NOT NULL,
  iv TEXT,
  created_at TEXT,
  is_read INTEGER NOT NULL DEFAULT 0,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  replied_to TEXT,
  type TEXT DEFAULT 'text',
  firestore_id TEXT,
  reactions TEXT DEFAULT '{}',
  delivered_at TEXT,
  read_at TEXT,
  scheduled_at TEXT,
  delete_after TEXT,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
)
      ''');

      await db.execute('''
        CREATE TABLE conversations (
          id $idType,
          data $textType
        )
      ''');

      await db.execute('''
        CREATE TABLE followers (
          follower_id TEXT NOT NULL,
          following_id TEXT NOT NULL,
          PRIMARY KEY (follower_id, following_id),
          FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');

      debugPrint('SQLite tables created successfully');
    } catch (e) {
      debugPrint('Error creating SQLite tables: $e');
      throw Exception('Error creating SQLite tables: $e');
    }
  }

  Future<bool> _tableExists(sqflite.Database db, String tableName) async {
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking table existence for $tableName: $e');
      return false;
    }
  }

  Future<bool> _messageExists(String messageId) async {
    try {
      final firestoreDoc = await _firestore
          .collectionGroup('messages')
          .where('id', isEqualTo: messageId)
          .get();
      if (firestoreDoc.docs.isNotEmpty) return true;

      if (kIsWeb) {
        final record =
            await _messageStore.record(messageId).get(await database);
        return record != null;
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'messages',
          where: 'id = ?',
          whereArgs: [messageId],
        );
        return result.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Failed to check message existence: $e');
      return false;
    }
  }

  Map<String, dynamic> _normalizeMessageData(Map<String, dynamic> message) {
    return {
      'id': message['id']?.toString() ?? '',
      'sender_id': message['sender_id']?.toString() ?? '',
      'receiver_id': message['receiver_id']?.toString() ?? '',
      'message': message['message']?.toString() ?? '',
      'iv': message['iv']?.toString(),
      'created_at':
          message['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'is_read': message['is_read'] is bool
          ? (message['is_read'] ? 1 : 0)
          : (message['is_read']?.toInt() ?? 0),
      'is_pinned': message['is_pinned'] is bool
          ? (message['is_pinned'] ? 1 : 0)
          : (message['is_pinned']?.toInt() ?? 0),
      'replied_to': message['replied_to']?.toString(),
      'type': message['type']?.toString() ?? 'text',
      'firestore_id': message['firestore_id']?.toString(),
      'reactions': message['reactions'] is Map
          ? message['reactions']
          : (message['reactions'] is String
              ? (message['reactions'].isEmpty
                  ? {}
                  : jsonDecode(message['reactions']))
              : {}),
      'delivered_at': message['delivered_at']?.toString(),
      'read_at': message['read_at']?.toString(),
      'scheduled_at': message['scheduled_at']?.toString(),
      'delete_after': message['delete_after']?.toString(),
    };
  }

  Map<String, dynamic> _normalizeUserData(Map<String, dynamic> user) {
    return {
      'id': user['id']?.toString() ?? '',
      'username': user['username']?.toString() ?? '',
      'email': user['email']?.toString() ?? '',
      'bio': user['bio']?.toString() ?? '',
      'password': user['password']?.toString() ?? '',
      'auth_provider': user['auth_provider']?.toString() ?? '',
      'token': user['token']?.toString() ?? '',
      'created_at': user['created_at']?.toString() ?? '',
      'updated_at': user['updated_at']?.toString() ?? '',
      'followers_count': user['followers_count']?.toString() ?? '0',
      'following_count': user['following_count']?.toString() ?? '0',
      'avatar': user['avatar']?.toString() ?? 'https://via.placeholder.com/200',
    };
  }

  // Start real-time syncing for all collections
  Future<void> startSyncingForUser(String userId) async {
    await initialize();
    await _startListeningToUser(userId);
    await _startListeningToProfiles(userId);
    await _startListeningToConversations(userId);
    await _startListeningToFollowers(userId);
  }

  // Stop real-time syncing
  Future<void> stopSyncing() async {
    _userSubscription?.cancel();
    _profilesSubscription?.cancel();
    _conversationsSubscription?.cancel();
    _followersSubscription?.cancel();
    _messageSubscriptions.forEach((_, sub) => sub.cancel());
    _messageSubscriptions.clear();
  }

  Future<void> _startListeningToUser(String userId) async {
    _userSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final userData = snapshot.data()!;
        userData['id'] = snapshot.id;
        await _insertOrUpdateUser(userData);
      } else {
        await _deleteUserLocally(userId);
      }
    });
  }

  Future<void> _startListeningToProfiles(String userId) async {
    _profilesSubscription = _firestore
        .collection('profiles')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        final profileData = change.doc.data()!;
        profileData['id'] = change.doc.id;
        if (change.type == firestore.DocumentChangeType.added ||
            change.type == firestore.DocumentChangeType.modified) {
          await _insertOrUpdateProfile(profileData);
        } else if (change.type == firestore.DocumentChangeType.removed) {
          await _deleteProfileLocally(profileData['id']);
        }
      }
    });
  }

  Future<void> _startListeningToConversations(String userId) async {
    _conversationsSubscription = _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        final conversationData = change.doc.data()!;
        conversationData['id'] = change.doc.id;
        if (change.type == firestore.DocumentChangeType.added ||
            change.type == firestore.DocumentChangeType.modified) {
          await _insertOrUpdateConversation(conversationData);
          if (change.type == firestore.DocumentChangeType.added) {
            _startListeningToMessages(conversationData['id']);
          }
        } else if (change.type == firestore.DocumentChangeType.removed) {
          await _deleteConversationLocally(conversationData['id']);
          _messageSubscriptions[conversationData['id']]?.cancel();
          _messageSubscriptions.remove(conversationData['id']);
        }
      }
    });
  }

  Future<void> _startListeningToMessages(String conversationId) async {
    final subscription = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        final messageData = change.doc.data()!;
        messageData['id'] = change.doc.id;
        if (change.type == firestore.DocumentChangeType.added ||
            change.type == firestore.DocumentChangeType.modified) {
          await _insertOrUpdateMessage(messageData);
        } else if (change.type == firestore.DocumentChangeType.removed) {
          await _deleteMessageLocally(messageData['id']);
        }
      }
    });
    _messageSubscriptions[conversationId] = subscription;
  }

  Future<void> _startListeningToFollowers(String userId) async {
    _followersSubscription =
        _firestore.collection('followers').snapshots().listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        final followerData = change.doc.data()!;
        if (change.type == firestore.DocumentChangeType.added ||
            change.type == firestore.DocumentChangeType.modified) {
          await _insertOrUpdateFollower(
              followerData['follower_id'], followerData['following_id']);
        } else if (change.type == firestore.DocumentChangeType.removed) {
          await _deleteFollowerLocally(
              followerData['follower_id'], followerData['following_id']);
        }
      }
    });
  }

  Future<void> _insertOrUpdateUser(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) throw Exception('User ID cannot be empty');
    final userData = _normalizeUserData(user);
    if (kIsWeb) {
      await _userStore.record(userId).put(await database, userData);
    } else {
      final db = await database as sqflite.Database;
      await db.insert(
        'users',
        userData,
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _deleteUserLocally(String userId) async {
    if (kIsWeb) {
      await _userStore.record(userId).delete(await database);
    } else {
      final db = await database as sqflite.Database;
      await db.delete('users', where: 'id = ?', whereArgs: [userId]);
    }
  }

  Future<void> _insertOrUpdateProfile(Map<String, dynamic> profile) async {
    final profileId = profile['id']?.toString() ?? '';
    if (profileId.isEmpty) throw Exception('Profile ID cannot be empty');
    if (kIsWeb) {
      await _profileStore.record(profileId).put(await database, profile);
    } else {
      final db = await database as sqflite.Database;
      await db.insert(
        'profiles',
        profile,
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _deleteProfileLocally(String profileId) async {
    if (kIsWeb) {
      await _profileStore.record(profileId).delete(await database);
    } else {
      final db = await database as sqflite.Database;
      await db.delete('profiles', where: 'id = ?', whereArgs: [profileId]);
    }
  }

  Future<void> _insertOrUpdateConversation(
      Map<String, dynamic> conversation) async {
    final conversationId = conversation['id']?.toString() ?? '';
    if (conversationId.isEmpty)
      throw Exception('Conversation ID cannot be empty');
    if (kIsWeb) {
      await _conversationStore
          .record(conversationId)
          .put(await database, conversation);
    } else {
      final db = await database as sqflite.Database;
      await db.insert(
        'conversations',
        {'id': conversationId, 'data': jsonEncode(conversation)},
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _deleteConversationLocally(String conversationId) async {
    if (kIsWeb) {
      await _conversationStore.record(conversationId).delete(await database);
    } else {
      final db = await database as sqflite.Database;
      await db.delete('conversations',
          where: 'id = ?', whereArgs: [conversationId]);
    }
  }

  Future<void> _insertOrUpdateMessage(Map<String, dynamic> message) async {
    final messageId = message['id']?.toString() ?? '';
    if (messageId.isEmpty) throw Exception('Message ID cannot be empty');
    final messageData = _normalizeMessageData(message);
    if (kIsWeb) {
      await _messageStore.record(messageId).put(await database, messageData);
    } else {
      final db = await database as sqflite.Database;
      await db.insert(
        'messages',
        {...messageData, 'reactions': jsonEncode(messageData['reactions'])},
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _deleteMessageLocally(String messageId) async {
    if (kIsWeb) {
      await _messageStore.record(messageId).delete(await database);
    } else {
      final db = await database as sqflite.Database;
      await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
    }
  }

  Future<void> _insertOrUpdateFollower(
      String followerId, String followingId) async {
    if (kIsWeb) {
      await _followersStore.add(await database,
          {'follower_id': followerId, 'following_id': followingId});
    } else {
      final db = await database as sqflite.Database;
      await db.insert(
        'followers',
        {'follower_id': followerId, 'following_id': followingId},
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _deleteFollowerLocally(
      String followerId, String followingId) async {
    if (kIsWeb) {
      final finder = sembast.Finder(
        filter: sembast.Filter.and([
          sembast.Filter.equals('follower_id', followerId),
          sembast.Filter.equals('following_id', followingId),
        ]),
      );
      await _followersStore.delete(await database, finder: finder);
    } else {
      final db = await database as sqflite.Database;
      await db.delete(
        'followers',
        where: 'follower_id = ? AND following_id = ?',
        whereArgs: [followerId, followingId],
      );
    }
  }

  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final firestoreResult = await _firestore
          .collection('followers')
          .where('follower_id', isEqualTo: followerId)
          .where('following_id', isEqualTo: followingId)
          .get();
      if (firestoreResult.docs.isNotEmpty) return true;

      if (kIsWeb) {
        final finder = sembast.Finder(
          filter: sembast.Filter.and([
            sembast.Filter.equals('follower_id', followerId),
            sembast.Filter.equals('following_id', followingId),
          ]),
        );
        final record =
            await _followersStore.findFirst(await database, finder: finder);
        return record != null;
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'followers',
          where: 'follower_id = ? AND following_id = ?',
          whereArgs: [followerId, followingId],
        );
        return result.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Failed to check following status: $e');
      throw Exception('Failed to check following status: $e');
    }
  }

  Future<void> followUser(String followerId, String followingId) async {
    try {
      await _firestore
          .collection('followers')
          .doc('$followerId-$followingId')
          .set({
        'follower_id': followerId,
        'following_id': followingId,
        'created_at': DateTime.now().toIso8601String(),
      }, firestore.SetOptions(merge: true));

      await _insertOrUpdateFollower(followerId, followingId);
    } catch (e) {
      debugPrint('Failed to follow user: $e');
      throw Exception('Failed to follow user: $e');
    }
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      await _firestore
          .collection('followers')
          .doc('$followerId-$followingId')
          .delete();

      await _deleteFollowerLocally(followerId, followingId);
    } catch (e) {
      debugPrint('Failed to unfollow user: $e');
      throw Exception('Failed to unfollow user: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    try {
      if (kIsWeb) {
        final finder = sembast.Finder(
            filter: sembast.Filter.equals('following_id', userId));
        final followerRecords =
            await _followersStore.find(await database, finder: finder);
        final followerIds =
            followerRecords.map((r) => r['follower_id'] as String).toList();
        final db = await database;
        final localUserRecords = await Future.wait(
          followerIds.map((id) => _userStore.record(id).get(db)),
        );
        return localUserRecords
            .where((r) => r != null)
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r!)))
            .toList();
      } else {
        final db = await database as sqflite.Database;
        final followerResult = await db
            .query('followers', where: 'following_id = ?', whereArgs: [userId]);
        final followerIds =
            followerResult.map((r) => r['follower_id'] as String).toList();
        if (followerIds.isEmpty) return [];
        final localUserResult = await db.query(
          'users',
          where: 'id IN (${followerIds.map((_) => '?').join(',')})',
          whereArgs: followerIds,
        );
        return localUserResult
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r)))
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to get followers: $e');
      throw Exception('Failed to get followers: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    try {
      if (kIsWeb) {
        final finder = sembast.Finder(
            filter: sembast.Filter.equals('follower_id', userId));
        final followingRecords =
            await _followersStore.find(await database, finder: finder);
        final followingIds =
            followingRecords.map((r) => r['following_id'] as String).toList();
        final db = await database;
        final localUserRecords = await Future.wait(
          followingIds.map((id) => _userStore.record(id).get(db)),
        );
        return localUserRecords
            .where((r) => r != null)
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r!)))
            .toList();
      } else {
        final db = await database as sqflite.Database;
        final followingResult = await db
            .query('followers', where: 'follower_id = ?', whereArgs: [userId]);
        final followingIds =
            followingResult.map((r) => r['following_id'] as String).toList();
        if (followingIds.isEmpty) return [];
        final localUserResult = await db.query(
          'users',
          where: 'id IN (${followingIds.map((_) => '?').join(',')})',
          whereArgs: followingIds,
        );
        return localUserResult
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r)))
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to get following: $e');
      throw Exception('Failed to get following: $e');
    }
  }

  Future<String> createProfile(Map<String, dynamic> profile) async {
    final profileData = {
      'id': profile['id']?.toString() ?? _uuid.v4(),
      'user_id': profile['user_id']?.toString() ?? '',
      'name': profile['name']?.toString() ?? 'Profile',
      'avatar':
          profile['avatar']?.toString() ?? 'https://via.placeholder.com/200',
      'backgroundImage': profile['backgroundImage']?.toString(),
      'pin': profile['pin']?.toString(),
      'locked': profile['locked']?.toInt() ?? 0,
      'preferences': profile['preferences']?.toString() ?? '',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (profileData['user_id'].isEmpty) {
      throw Exception('user_id cannot be empty');
    }

    try {
      final newId = profileData['id'];
      await _firestore
          .collection('profiles')
          .doc(newId)
          .set(profileData, firestore.SetOptions(merge: true));
      await _insertOrUpdateProfile(profileData);
      debugPrint('Profile created with ID: $newId');
      return newId;
    } catch (e) {
      debugPrint('Failed to create profile: $e');
      throw Exception('Failed to create profile: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getProfilesByUserId(String userId) async {
    try {
      if (kIsWeb) {
        final finder = sembast.Finder(
          filter: sembast.Filter.equals('user_id', userId),
          sortOrders: [sembast.SortOrder('created_at')],
        );
        final records =
            await _profileStore.find(await database, finder: finder);
        return records.map((r) {
          final profileData = Map<String, dynamic>.from(r.value);
          profileData['id'] = r.key;
          return profileData;
        }).toList();
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'profiles',
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'created_at ASC',
        );
        return result.map((r) {
          final profileData = Map<String, dynamic>.from(r);
          profileData['id'] = profileData['id'].toString();
          return profileData;
        }).toList();
      }
    } catch (e) {
      debugPrint('Failed to fetch profiles: $e');
      throw Exception('Failed to fetch profiles: $e');
    }
  }

  Future<Map<String, dynamic>?> getProfileById(String profileId) async {
    try {
      if (kIsWeb) {
        final record =
            await _profileStore.record(profileId).get(await database);
        if (record != null) {
          final profileData = Map<String, dynamic>.from(record);
          profileData['id'] = profileId;
          return profileData;
        }
        return null;
      } else {
        final db = await database as sqflite.Database;
        final result =
            await db.query('profiles', where: 'id = ?', whereArgs: [profileId]);
        if (result.isNotEmpty) {
          final profileData = Map<String, dynamic>.from(result.first);
          profileData['id'] = profileData['id'].toString();
          return profileData;
        }
        return null;
      }
    } catch (e) {
      debugPrint('Failed to fetch profile: $e');
      throw Exception('Failed to fetch profile: $e');
    }
  }

  Future<Map<String, dynamic>?> getActiveProfileByUserId(String userId) async {
    try {
      // Step 1: Check local database first
      Map<String, dynamic>? localProfile;

      if (kIsWeb) {
        final finder = sembast.Finder(
          filter: sembast.Filter.and([
            sembast.Filter.equals('user_id', userId),
            sembast.Filter.equals('locked', 0),
          ]),
          sortOrders: [sembast.SortOrder('created_at')],
        );
        final record =
            await _profileStore.findFirst(await database, finder: finder);
        if (record != null) {
          localProfile = Map<String, dynamic>.from(record.value);
          localProfile['id'] = record.key;
        }
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'profiles',
          where: 'user_id = ? AND locked = 0',
          whereArgs: [userId],
          orderBy: 'created_at ASC',
          limit: 1,
        );
        if (result.isNotEmpty) {
          localProfile = Map<String, dynamic>.from(result.first);
          localProfile['id'] = localProfile['id'].toString();
        }
      }

      // Step 2: If found locally, return it
      if (localProfile != null) {
        return localProfile;
      }

      // Step 3: If not found locally, query Firestore
      final snapshot = await _firestore
          .collection('profiles')
          .where('user_id', isEqualTo: userId)
          .where('locked', isEqualTo: 0)
          .orderBy('created_at')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final profileData = snapshot.docs.first.data();
        profileData['id'] = snapshot.docs.first.id;
        // Insert into local database to keep it in sync
        await _insertOrUpdateProfile(profileData);
        return profileData;
      }

      // Step 4: If not found in Firestore either, return null
      return null;
    } catch (e) {
      debugPrint('Failed to fetch active profile: $e');
      throw Exception('Failed to fetch active profile: $e');
    }
  }

  Future<String> updateProfile(Map<String, dynamic> profile) async {
    final profileData = Map<String, dynamic>.from(profile);
    profileData['updated_at'] = DateTime.now().toIso8601String();
    final profileId = profileData['id']?.toString() ?? '';
    if (profileId.isEmpty || profileData['user_id'].isEmpty) {
      throw Exception('Profile ID or user_id cannot be empty');
    }

    try {
      await _firestore
          .collection('profiles')
          .doc(profileId)
          .set(profileData, firestore.SetOptions(merge: true));
      await _insertOrUpdateProfile(profileData);
      return profileId;
    } catch (e) {
      debugPrint('Failed to update profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<int> deleteProfile(String profileId) async {
    try {
      await _firestore.collection('profiles').doc(profileId).delete();
      await _deleteProfileLocally(profileId);
      return 1;
    } catch (e) {
      debugPrint('Failed to delete profile: $e');
      throw Exception('Failed to delete profile: $e');
    }
  }

Future<String> createMessage(Map<String, dynamic> message) async {
  final messageId = message['id']?.toString() ?? _uuid.v4();
  if (await _messageExists(messageId)) return messageId;

  final messageData = _normalizeMessageData({
    ...message,
    'id': messageId,
    'created_at': DateTime.now().toIso8601String(),
  });

  if (messageData['sender_id'].isEmpty) {
    throw Exception('sender_id cannot be empty');
  }

  try {
    final conversationId = messageData['conversation_id'];
    if (conversationId == null || conversationId.isEmpty) {
      throw Exception('conversation_id is required');
    }
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .set({
      'id': messageId,
      'sender_id': messageData['sender_id'],
      'receiver_id': messageData['receiver_id'],
      'conversation_id': conversationId,
      'message': messageData['message'],
      'iv': messageData['iv'],
      'timestamp': firestore.FieldValue.serverTimestamp(),
      'is_read': messageData['is_read'] == 1,
      'is_pinned': messageData['is_pinned'] == 1,
      'replied_to': messageData['replied_to'],
      'type': messageData['type'],
      'reactions': messageData['reactions'] ?? {},
      'delivered_at': messageData['delivered_at'],
      'read_at': messageData['read_at'],
      'scheduled_at': messageData['scheduled_at'],
      'delete_after': messageData['delete_after'],
    }, firestore.SetOptions(merge: true));

    await _insertOrUpdateMessage(messageData);
    return messageId;
  } catch (e) {
    debugPrint('Failed to create message: $e');
    throw Exception('Failed to create message: $e');
  }
}

Future<void> syncMessagesForConversation(String conversationId) async {
  try {
    final snapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp')
        .get();
    for (var doc in snapshot.docs) {
      final messageData = doc.data();
      messageData['id'] = doc.id;
      await _insertOrUpdateMessage(messageData);
    }
  } catch (e) {
    debugPrint('Failed to sync messages for conversation $conversationId: $e');
    throw Exception('Failed to sync messages: $e');
  }
}

  Future<List<Map<String, dynamic>>> getMessagesBetween(
      String userId1, String userId2) async {
    try {
      if (kIsWeb) {
        final finder = sembast.Finder(
          filter: sembast.Filter.or([
            sembast.Filter.and([
              sembast.Filter.equals('sender_id', userId1),
              sembast.Filter.equals('receiver_id', userId2),
            ]),
            sembast.Filter.and([
              sembast.Filter.equals('sender_id', userId2),
              sembast.Filter.equals('receiver_id', userId1),
            ]),
          ]),
          sortOrders: [sembast.SortOrder('created_at')],
        );
        final records =
            await _messageStore.find(await database, finder: finder);
        return records.map((r) {
          final messageData = Map<String, dynamic>.from(r.value);
          messageData['id'] = r.key.toString();
          return _normalizeMessageData(messageData);
        }).toList();
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'messages',
          where:
              '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
          whereArgs: [userId1, userId2, userId2, userId1],
          orderBy: 'created_at ASC',
        );
        return result
            .map((r) => _normalizeMessageData(Map<String, dynamic>.from(r)))
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to fetch messages: $e');
      throw Exception('Failed to fetch messages: $e');
    }
  } 

  Future<List<Map<String, dynamic>>> getMessagesByConversationId(
    String conversationId) async {
  try {
    if (kIsWeb) {
      final finder = sembast.Finder(
        filter: sembast.Filter.equals('conversation_id', conversationId),
        sortOrders: [sembast.SortOrder('created_at')],
      );
      final records = await _messageStore.find(await database, finder: finder);
      return records.map((r) {
        final messageData = Map<String, dynamic>.from(r.value);
        messageData['id'] = r.key.toString();
        return _normalizeMessageData(messageData);
      }).toList();
    } else {
      final db = await database as sqflite.Database;
      final result = await db.query(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC',
      );
      return result
          .map((r) => _normalizeMessageData(Map<String, dynamic>.from(r)))
          .toList();
    }
  } catch (e) {
    debugPrint('Failed to fetch messages for conversation $conversationId: $e');
    throw Exception('Failed to fetch messages: $e');
  }
}

  Future<List<Map<String, dynamic>>> getConversationsForUser(
      String userId) async {
    try {
      if (kIsWeb) {
        final finder = sembast.Finder(
          filter: sembast.Filter.custom((record) {
            final participantsRaw = record['participants'];
            final participants = participantsRaw is List
                ? List<String>.from(participantsRaw.map((e) => e.toString()))
                : <String>[];
            return participants.contains(userId);
          }),
        );
        final records =
            await _conversationStore.find(await database, finder: finder);
        return records.map((r) {
          final convoData = Map<String, dynamic>.from(r.value);
          convoData['id'] = r.key.toString();
          if (convoData['participants'] is List) {
            convoData['participants'] = List<String>.from(
              (convoData['participants'] as List).map((e) => e.toString()),
            );
          } else {
            convoData['participants'] = <String>[];
          }
          return convoData;
        }).toList();
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query('conversations');
        return result
            .map((row) {
              final convo = jsonDecode(row['data'] as String);
              if (convo['participants'] is List) {
                convo['participants'] = List<String>.from(
                  (convo['participants'] as List).map((e) => e.toString()),
                );
              }
              if ((convo['participants'] as List<String>).contains(userId)) {
                convo['id'] = row['id'].toString();
                return convo;
              }
              return null;
            })
            .where((convo) => convo != null)
            .toList()
            .cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Failed to fetch conversations: $e');
      throw Exception('Failed to fetch conversations: $e');
    }
  }

  Future<int> deleteMessage(String messageId) async {
    try {
      final sortedIds = await _firestore
          .collectionGroup('messages')
          .where('id', isEqualTo: messageId)
          .get();
      for (var doc in sortedIds.docs) {
        await doc.reference.delete();
      }
      await _deleteMessageLocally(messageId);
      return 1;
    } catch (e) {
      debugPrint('Failed to delete message: $e');
      throw Exception('Failed to delete message: $e');
    }
  }

  Future<String> updateMessage(Map<String, dynamic> message) async {
    final messageData = _normalizeMessageData(message);
    final messageId = messageData['id']?.toString() ?? '';
    if (messageId.isEmpty) throw Exception('Message ID cannot be empty');

    try {
      final sortedIds = [messageData['sender_id'], messageData['receiver_id']]
        ..sort();
      final conversationId = sortedIds.join('_');
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .set({
        'id': messageId,
        'sender_id': messageData['sender_id'],
        'receiver_id': messageData['receiver_id'],
        'message': messageData['message'],
        'iv': messageData['iv'],
        'timestamp': firestore.FieldValue.serverTimestamp(),
        'is_read': messageData['is_read'] == 1,
        'is_pinned': messageData['is_pinned'] == 1,
        'replied_to': messageData['replied_to'],
        'type': messageData['type'],
        'reactions': messageData['reactions'] ?? {},
        'delivered_at': messageData['delivered_at'],
        'read_at': messageData['read_at'],
        'scheduled_at': messageData['scheduled_at'],
        'delete_after': messageData['delete_after'],
      }, firestore.SetOptions(merge: true));

      await _insertOrUpdateMessage(messageData);
      return messageId;
    } catch (e) {
      debugPrint('Failed to update message: $e');
      throw Exception('Failed to update message: $e');
    }
  }

  Future<void> insertConversation(Map<String, dynamic> conversation) async {
    final conversationData = Map<String, dynamic>.from(conversation);
    final conversationId = conversationData['id']?.toString() ?? _uuid.v4();
    conversationData['id'] = conversationId;
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .set(conversationData, firestore.SetOptions(merge: true));
      await _insertOrUpdateConversation(conversationData);
    } catch (e) {
      debugPrint('Failed to insert conversation: $e');
      throw Exception('Failed to insert conversation: $e');
    }
  }

  Future<void> clearConversationsForUser(String userId) async {
    try {
      if (kIsWeb) {
        final finder = sembast.Finder(
          filter: sembast.Filter.custom((record) {
            final participants = record['participants'] as List<dynamic>?;
            return participants?.contains(userId) ?? false;
          }),
        );
        await _conversationStore.delete(await database, finder: finder);
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query('conversations');
        final idsToDelete = result
            .map((row) => jsonDecode(row['data'] as String))
            .where((convo) =>
                (convo['participants'] as List<dynamic>).contains(userId))
            .map((convo) => convo['id'])
            .toList();
        for (final id in idsToDelete) {
          await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
        }
      }
    } catch (e) {
      debugPrint('Failed to clear conversations: $e');
      throw Exception('Failed to clear conversations: $e');
    }
  }

  Future<int> getUnreadCount(String conversationId, String userId) async {
    try {
      if (kIsWeb) {
        final finder = sembast.Finder(
          filter: sembast.Filter.and([
            sembast.Filter.equals('receiver_id', userId),
            sembast.Filter.equals('is_read', 0),
          ]),
        );
        final records =
            await _messageStore.find(await database, finder: finder);
        return records.length;
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'messages',
          where: 'receiver_id = ? AND is_read = ?',
          whereArgs: [userId, 0],
        );
        return result.length;
      }
    } catch (e) {
      debugPrint('Failed to get unread count: $e');
      throw Exception('Failed to get unread count: $e');
    }
  }

  Future<void> updateConversation(Map<String, dynamic> conversation) async {
    final conversationData = Map<String, dynamic>.from(conversation);
    final conversationId = conversationData['id']?.toString() ?? '';
    if (conversationId.isEmpty)
      throw Exception('Conversation ID cannot be empty');

    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .set(conversationData, firestore.SetOptions(merge: true));
      await _insertOrUpdateConversation(conversationData);
    } catch (e) {
      debugPrint('Failed to update conversation: $e');
      throw Exception('Failed to update conversation: $e');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).delete();
      await _deleteConversationLocally(conversationId);
    } catch (e) {
      debugPrint('Failed to delete conversation: $e');
      throw Exception('Failed to delete conversation: $e');
    }
  }

  Future<void> muteConversation(
      String conversationId, List<String> mutedUsers) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({'muted_users': mutedUsers});
      if (kIsWeb) {
        await _conversationStore
            .record(conversationId)
            .update(await database, {'muted_users': mutedUsers});
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query('conversations',
            where: 'id = ?', whereArgs: [conversationId]);
        if (result.isNotEmpty) {
          final convoData = jsonDecode(result.first['data'] as String);
          convoData['muted_users'] = mutedUsers;
          await db.update(
            'conversations',
            {'id': conversationId, 'data': jsonEncode(convoData)},
            where: 'id = ?',
            whereArgs: [conversationId],
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to mute conversation: $e');
      throw Exception('Failed to mute conversation: $e');
    }
  }

  Future<void> blockConversation(
      String conversationId, List<String> blockedUsers) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({'blocked_users': blockedUsers});
      if (kIsWeb) {
        await _conversationStore
            .record(conversationId)
            .update(await database, {'blocked_users': blockedUsers});
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query('conversations',
            where: 'id = ?', whereArgs: [conversationId]);
        if (result.isNotEmpty) {
          final convoData = jsonDecode(result.first['data'] as String);
          convoData['blocked_users'] = blockedUsers;
          await db.update(
            'conversations',
            {'id': conversationId, 'data': jsonEncode(convoData)},
            where: 'id = ?',
            whereArgs: [conversationId],
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to block conversation: $e');
      throw Exception('Failed to block conversation: $e');
    }
  }

  Future<void> close() async {
    try {
      await stopSyncing();
      if (kIsWeb) {
        await _sembastDb?.close();
        _sembastDb = null;
      } else {
        await _sqfliteDb?.close();
        _sqfliteDb = null;
      }
      _isInitialized = false;
      debugPrint('Database closed');
    } catch (e) {
      debugPrint('Failed to close database: $e');
      throw Exception('Failed to close database: $e');
    }
  }

  Future<String> createUser(Map<String, dynamic> user) async {
    final userData = {
      'id': user['id']?.toString() ?? _uuid.v4(),
      'username': user['username']?.toString() ?? '',
      'email': user['email']?.toString() ?? '',
      'bio': user['bio']?.toString() ?? '',
      'password': user['password']?.toString() ?? '',
      'auth_provider': user['auth_provider']?.toString() ?? 'email',
      'token': user['token']?.toString(),
      'created_at':
          user['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'updated_at':
          user['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      'followers_count': user['followers_count']?.toString() ?? '0',
      'following_count': user['following_count']?.toString() ?? '0',
      'avatar': user['avatar']?.toString() ?? 'https://via.placeholder.com/200',
    };

    final userId =
        userData['id'] as String; // Assert non-null since _uuid.v4() ensures it
    if (userId.isEmpty) throw Exception('User ID cannot be empty');

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .set(userData, firestore.SetOptions(merge: true));
      await _insertOrUpdateUser(userData);
      return userId;
    } catch (e) {
      debugPrint('Failed to create user: $e');
      throw Exception('Failed to create user: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      if (kIsWeb) {
        final finder =
            sembast.Finder(filter: sembast.Filter.equals('email', email));
        final record =
            await _userStore.findFirst(await database, finder: finder);
        return record != null ? _normalizeUserData(record.value) : null;
      } else {
        final db = await database as sqflite.Database;
        final result =
            await db.query('users', where: 'email = ?', whereArgs: [email]);
        return result.isNotEmpty
            ? _normalizeUserData(Map<String, dynamic>.from(result.first))
            : null;
      }
    } catch (e) {
      debugPrint('Failed to get user by email: $e');
      throw Exception('Failed to get user by email: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserById(String id) async {
    try {
      if (kIsWeb) {
        final record = await _userStore.record(id).get(await database);
        return record != null ? _normalizeUserData(record) : null;
      } else {
        final db = await database as sqflite.Database;
        final result =
            await db.query('users', where: 'id = ?', whereArgs: [id]);
        return result.isNotEmpty
            ? _normalizeUserData(Map<String, dynamic>.from(result.first))
            : null;
      }
    } catch (e) {
      debugPrint('Failed to get user by ID $id: $e');
      throw Exception('Failed to get user by ID: $e');
    }
  }

  Future<String> updateUser(Map<String, dynamic> user) async {
    final userData = _normalizeUserData({
      ...user,
      'updated_at': DateTime.now().toIso8601String(),
    });
    final userId = userData['id'];
    if (userId.isEmpty) throw Exception('User ID cannot be empty');

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .set(userData, firestore.SetOptions(merge: true));
      await _insertOrUpdateUser(userData);
      return userId;
    } catch (e) {
      debugPrint('Failed to update user: $e');
      throw Exception('Failed to update user: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      if (kIsWeb) {
        final records = await _userStore.find(await database);
        return records
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r.value)))
            .toList();
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query('users');
        return result
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r)))
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to get all users: $e');
      throw Exception('Failed to get all users: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      if (kIsWeb) {
        final finder = sembast.Finder(
            filter: sembast.Filter.matches('username', '^$query.*'));
        final records = await _userStore.find(await database, finder: finder);
        return records
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r.value)))
            .toList();
      } else {
        final db = await database as sqflite.Database;
        final result = await db
            .query('users', where: 'username LIKE ?', whereArgs: ['$query%']);
        return result
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r)))
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to search users: $e');
      throw Exception('Failed to search users: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserByToken(String token) async {
    try {
      if (kIsWeb) {
        final finder =
            sembast.Finder(filter: sembast.Filter.equals('token', token));
        final record =
            await _userStore.findFirst(await database, finder: finder);
        return record != null ? _normalizeUserData(record.value) : null;
      } else {
        final db = await database as sqflite.Database;
        final result =
            await db.query('users', where: 'token = ?', whereArgs: [token]);
        return result.isNotEmpty
            ? _normalizeUserData(Map<String, dynamic>.from(result.first))
            : null;
      }
    } catch (e) {
      debugPrint('Failed to get user by token: $e');
      return null;
    }
  }

  // Remove unused method
  Future<List<Map<String, dynamic>>> fetchedSMergedMessages(
      String senderId, String receiverId) async {
    throw UnimplementedError(
        'This method is deprecated. Use getMessagesBetween instead.');
  }
}

