import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast_web/sembast_web.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:uuid/uuid.dart';

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
      // Verify tables exist
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
          id $idType,
          sender_id TEXT NOT NULL,
          receiver_id TEXT NOT NULL,
          message $textType,
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
          FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE
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

      if (kIsWeb) {
        await _followersStore.add(await database, {
          'follower_id': followerId,
          'following_id': followingId,
        });
      } else {
        final db = await database as sqflite.Database;
        await db.insert(
          'followers',
          {'follower_id': followerId, 'following_id': followingId},
          conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
        );
      }
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
    } catch (e) {
      debugPrint('Failed to unfollow user: $e');
      throw Exception('Failed to unfollow user: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    try {
      final firestoreFollowerDocs = await _firestore
          .collection('followers')
          .where('following_id', isEqualTo: userId)
          .get();
      final followerIdsFromFirestore = firestoreFollowerDocs.docs
          .map((doc) => doc['follower_id'] as String)
          .toList();
      final firestoreUsers = await Future.wait(
        followerIdsFromFirestore
            .map((id) => _firestore.collection('users').doc(id).get()),
      );
      final firestoreUserMaps = firestoreUsers
          .where((doc) => doc.exists)
          .map((doc) => _normalizeUserData(doc.data()!))
          .toList();

      List<String> localFollowerIds;
      List<Map<String, dynamic>> localUserMaps;
      if (kIsWeb) {
        final db = await database;
        final finder = sembast.Finder(
            filter: sembast.Filter.equals('following_id', userId));
        final followerRecords = await _followersStore.find(db, finder: finder);
        localFollowerIds =
            followerRecords.map((r) => r['follower_id'] as String).toList();
        final localUserRecords = await Future.wait(
          localFollowerIds.map((id) => _userStore.record(id).get(db)),
        );
        localUserMaps = localUserRecords
            .where((r) => r != null)
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r!)))
            .toList();
      } else {
        final db = await database as sqflite.Database;
        final followerResult = await db
            .query('followers', where: 'following_id = ?', whereArgs: [userId]);
        localFollowerIds =
            followerResult.map((r) => r['follower_id'] as String).toList();
        if (localFollowerIds.isNotEmpty) {
          final localUserResult = await db.query(
            'users',
            where: 'id IN (${localFollowerIds.map((_) => '?').join(',')})',
            whereArgs: localFollowerIds,
          );
          localUserMaps = localUserResult
              .map((r) => _normalizeUserData(Map<String, dynamic>.from(r)))
              .toList();
        } else {
          localUserMaps = [];
        }
      }

      final allUsersMap = <String, Map<String, dynamic>>{};
      for (var user in firestoreUserMaps) {
        final userId = user['id'] as String;
        allUsersMap[userId] = user;
      }
      for (var user in localUserMaps) {
        final userId = user['id'] as String;
        if (!allUsersMap.containsKey(userId)) {
          allUsersMap[userId] = _normalizeUserData(user);
        }
      }
      return allUsersMap.values.toList();
    } catch (e) {
      debugPrint('Failed to get followers: $e');
      throw Exception('Failed to get followers: $e');
    }
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

  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    try {
      final firestoreFollowingDocs = await _firestore
          .collection('followers')
          .where('follower_id', isEqualTo: userId)
          .get();
      final followingIdsFromFirestore = firestoreFollowingDocs.docs
          .map((doc) => doc['following_id'] as String)
          .toList();
      final firestoreUsers = await Future.wait(
        followingIdsFromFirestore
            .map((id) => _firestore.collection('users').doc(id).get()),
      );
      final firestoreUserMaps = firestoreUsers
          .where((doc) => doc.exists)
          .map((doc) => _normalizeUserData(doc.data()!))
          .toList();

      List<String> localFollowingIds;
      List<Map<String, dynamic>> localUserMaps;
      if (kIsWeb) {
        final db = await database;
        final finder = sembast.Finder(
            filter: sembast.Filter.equals('follower_id', userId));
        final followingRecords = await _followersStore.find(db, finder: finder);
        localFollowingIds =
            followingRecords.map((r) => r['following_id'] as String).toList();
        final localUserRecords = await Future.wait(
          localFollowingIds.map((id) => _userStore.record(id).get(db)),
        );
        localUserMaps = localUserRecords
            .where((r) => r != null)
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r!)))
            .toList();
      } else {
        final db = await database as sqflite.Database;
        final followingResult = await db
            .query('followers', where: 'follower_id = ?', whereArgs: [userId]);
        localFollowingIds =
            followingResult.map((r) => r['following_id'] as String).toList();
        if (localFollowingIds.isNotEmpty) {
          final localUserResult = await db.query(
            'users',
            where: 'id IN (${localFollowingIds.map((_) => '?').join(',')})',
            whereArgs: localFollowingIds,
          );
          localUserMaps = localUserResult
              .map((r) => _normalizeUserData(Map<String, dynamic>.from(r)))
              .toList();
        } else {
          localUserMaps = [];
        }
      }

      final allUsersMap = <String, Map<String, dynamic>>{};
      for (var user in firestoreUserMaps) {
        final userId = user['id'] as String;
        allUsersMap[userId] = user;
      }
      for (var user in localUserMaps) {
        final userId = user['id'] as String;
        if (!allUsersMap.containsKey(userId)) {
          allUsersMap[userId] = _normalizeUserData(user);
        }
      }
      return allUsersMap.values.toList();
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
      debugPrint('Creating profile with data: $profileData');
      final newId = profileData['id'];
      if (kIsWeb) {
        await _profileStore.add(await database, profileData);
        await _firestore
            .collection('profiles')
            .doc(newId)
            .set(profileData, firestore.SetOptions(merge: true));
      } else {
        final db = await database as sqflite.Database;
        await db.insert('profiles', profileData,
            conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        await _firestore
            .collection('profiles')
            .doc(newId)
            .set(profileData, firestore.SetOptions(merge: true));
      }
      debugPrint('Profile created with ID: $newId');
      return newId;
    } catch (e) {
      debugPrint('Failed to create profile: $e');
      throw Exception('Failed to create profile: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getProfilesByUserId(String userId) async {
    try {
      debugPrint('Fetching profiles for userId: $userId');
      final firestoreResult = await _firestore
          .collection('profiles')
          .where('user_id', isEqualTo: userId)
          .get();
      final firestoreProfiles = firestoreResult.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      List<Map<String, dynamic>> localProfiles;
      if (kIsWeb) {
        final finder = sembast.Finder(
            filter: sembast.Filter.equals('user_id', userId),
            sortOrders: [sembast.SortOrder('created_at')]);
        final records =
            await _profileStore.find(await database, finder: finder);
        localProfiles = records.map((r) {
          final profileData = Map<String, dynamic>.from(r.value);
          profileData['id'] = r.key;
          return profileData;
        }).toList();
      } else {
        final db = await database as sqflite.Database;
        if (!await _tableExists(db, 'profiles')) {
          debugPrint('Profiles table does not exist in SQLite');
          throw Exception('Profiles table not found');
        }
        final result = await db.query(
          'profiles',
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'created_at ASC',
        );
        localProfiles = result.map((r) {
          final profileData = Map<String, dynamic>.from(r);
          profileData['id'] = profileData['id'].toString();
          return profileData;
        }).toList();
      }

      final allProfilesMap = <String, Map<String, dynamic>>{};
      for (var profile in firestoreProfiles) {
        final profileId = profile['id']?.toString() ?? '';
        if (profileId.isNotEmpty) {
          allProfilesMap[profileId] = profile;
        }
      }
      for (var profile in localProfiles) {
        final profileId = profile['id']?.toString() ?? '';
        if (profileId.isNotEmpty) {
          allProfilesMap[profileId] = {
            ...allProfilesMap[profileId] ?? {},
            ...profile,
          };
        }
      }

      final profiles = allProfilesMap.values.toList();
      debugPrint('Fetched ${profiles.length} profiles for userId: $userId');
      return profiles;
    } catch (e) {
      debugPrint('Failed to fetch profiles: $e');
      throw Exception('Failed to fetch profiles: $e');
    }
  }

  Future<Map<String, dynamic>?> getProfileById(String profileId) async {
    try {
      debugPrint('Fetching profile with ID: $profileId');
      final firestoreDoc =
          await _firestore.collection('profiles').doc(profileId).get();
      if (firestoreDoc.exists) {
        final data = firestoreDoc.data()!;
        data['id'] = firestoreDoc.id;
        return data;
      }

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
        if (!await _tableExists(db, 'profiles')) {
          debugPrint('Profiles table does not exist in SQLite');
          return null;
        }
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
      debugPrint('Fetching active profile for userId: $userId');
      final firestoreResult = await _firestore
          .collection('profiles')
          .where('user_id', isEqualTo: userId)
          .where('locked', isEqualTo: 0)
          .orderBy('created_at')
          .limit(1)
          .get();
      if (firestoreResult.docs.isNotEmpty) {
        final data = firestoreResult.docs.first.data();
        data['id'] = firestoreResult.docs.first.id;
        return data;
      }

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
          final profileData = Map<String, dynamic>.from(record.value);
          profileData['id'] = record.key;
          return profileData;
        }
        return null;
      } else {
        final db = await database as sqflite.Database;
        if (!await _tableExists(db, 'profiles')) {
          debugPrint('Profiles table does not exist in SQLite');
          return null;
        }
        final result = await db.query(
          'profiles',
          where: 'user_id = ? AND locked = 0',
          whereArgs: [userId],
          orderBy: 'created_at ASC',
          limit: 1,
        );
        if (result.isNotEmpty) {
          final profileData = Map<String, dynamic>.from(result.first);
          profileData['id'] = profileData['id'].toString();
          return profileData;
        }
        return null;
      }
    } catch (e) {
      debugPrint('Failed to fetch active profile: $e');
      throw Exception('Failed to fetch active profile: $e');
    }
  }

  Future<String> updateProfile(Map<String, dynamic> profile) async {
    final profileData = Map<String, dynamic>.from(profile);
    profileData['user_id'] = profileData['user_id']?.toString() ?? '';
    profileData['updated_at'] = DateTime.now().toIso8601String();

    if (profileData['user_id'].isEmpty) {
      throw Exception('user_id cannot be empty');
    }

    try {
      final profileId = profileData['id']?.toString() ?? '';
      if (profileId.isEmpty) {
        throw Exception('profile id cannot be empty');
      }
      debugPrint('Updating profile with ID: $profileId');
      await _firestore
          .collection('profiles')
          .doc(profileId)
          .set(profileData, firestore.SetOptions(merge: true));
      if (kIsWeb) {
        await _profileStore
            .record(profileId)
            .update(await database, profileData);
      } else {
        final db = await database as sqflite.Database;
        await db.update(
          'profiles',
          profileData,
          where: 'id = ?',
          whereArgs: [profileId],
        );
      }
      return profileId;
    } catch (e) {
      debugPrint('Failed to update profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<int> deleteProfile(String profileId) async {
    try {
      debugPrint('Deleting profile with ID: $profileId');
      await _firestore.collection('profiles').doc(profileId).delete();
      if (kIsWeb) {
        await _profileStore.record(profileId).delete(await database);
        return 1;
      } else {
        final db = await database as sqflite.Database;
        return await db
            .delete('profiles', where: 'id = ?', whereArgs: [profileId]);
      }
    } catch (e) {
      debugPrint('Failed to delete profile: $e');
      throw Exception('Failed to delete profile: $e');
    }
  }

  Future<String> createMessage(Map<String, dynamic> message) async {
    final messageId = message['id']?.toString() ?? _uuid.v4();
    if (await _messageExists(messageId)) {
      debugPrint('Message with ID $messageId already exists');
      return messageId;
    }

    final messageData = _normalizeMessageData({
      ...message,
      'id': messageId,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (messageData['sender_id'].isEmpty ||
        messageData['receiver_id'].isEmpty) {
      throw Exception('sender_id and receiver_id cannot be empty');
    }

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

      if (kIsWeb) {
        await _messageStore.record(messageId).put(await database, messageData);
      } else {
        final db = await database as sqflite.Database;
        await db.insert(
            'messages',
            {
              ...messageData,
              'reactions': jsonEncode(messageData['reactions']),
            },
            conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      }

      debugPrint('Message created with ID: $messageId');
      return messageId;
    } catch (e) {
      debugPrint('Failed to create message: $e');
      throw Exception('Failed to create message: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchedSMergedMessages(
      String senderId, String receiverId) async {
    try {
      debugPrint(
          'Fetching messages for sender: $senderId, receiver: $receiverId');
      final messages = await _firestore
          .collection('messages')
          .where('sender_id', isEqualTo: senderId)
          .where('receiver_id', isEqualTo: receiverId)
          .orderBy('created_at', descending: false)
          .get();
      return messages.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch messages: $e');
      throw Exception('Failed to fetch messages: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMessagesBetween(
      String userId1, String userId2) async {
    try {
      final sortedIds = [userId1, userId2]..sort();
      final conversationId = sortedIds.join('_');
      final firestoreResult = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      final firestoreMessages = firestoreResult.docs.map((doc) {
        final data = doc.data();
        return _normalizeMessageData({
          'id': doc.id,
          'sender_id': data['sender_id']?.toString() ?? '',
          'receiver_id': data['receiver_id']?.toString() ?? '',
          'message': data['message']?.toString() ?? '',
          'iv': data['iv']?.toString(),
          'created_at': (data['timestamp'] as firestore.Timestamp?)
                  ?.toDate()
                  .toIso8601String() ??
              DateTime.now().toIso8601String(),
          'is_read': data['is_read'] == true ? 1 : 0,
          'is_pinned': data['is_pinned'] == true ? 1 : 0,
          'replied_to': data['replied_to']?.toString(),
          'type': data['type']?.toString(),
          'firestore_id': doc.id,
          'reactions': data['reactions'] ?? {},
          'delivered_at':
              (data['delivered_at'] as firestore.Timestamp?)?.toDate(),
          'read_at': (data['read_at'] as firestore.Timestamp?)?.toDate(),
          'scheduled_at': data['scheduled_at'],
          'delete_after': '',
        });
      }).toList();

      List<Map<String, dynamic>> localMessages;
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
        localMessages = records.map((r) {
          final messageData = Map<String, dynamic>.from(r.value);
          messageData['id'] = r.key.toString();
          return _normalizeMessageData(messageData);
        }).toList();
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'messages',
          where:
              '(sender_id)?.toString() = ? AND (receiver_id)?.toString() = ? OR ((sender_id)?.toString() = ? AND (receiver_id)?.toString() = ?)',
          whereArgs: [userId1, userId2, userId2, userId1],
          orderBy: 'created_at ASC',
        );
        localMessages = result.map((r) {
          final Map<String, dynamic> messageData = Map<String, dynamic>.from(r);
          messageData['id'] = messageData['id'].toString();
          return _normalizeMessageData(messageData);
        }).toList();
      }

      final allMessagesMap = <String, Map<String, dynamic>>{};
      for (var msg in firestoreMessages) {
        final msgId = msg['id'] as String;
        allMessagesMap[msgId] = msg;
      }
      for (var msg in localMessages) {
        final msgId = msg['id'].toString();
        if (!allMessagesMap.containsKey(msgId)) {
          allMessagesMap[msgId] = msg;
        }
      }

      final mergedMessages = allMessagesMap.values.toList()
        ..sort((a, b) => DateTime.parse(a['created_at'])
            .compareTo(DateTime.parse(b['created_at'])));

      debugPrint(
          'Fetched ${mergedMessages.length} messages between $userId1 and $userId2');
      return mergedMessages;
    } catch (e) {
      debugPrint('Failed to fetch messages: $e');
      throw Exception('Failed to fetch messages: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getConversationsForUser(
      String userId) async {
    try {
      debugPrint('Fetching conversations for userId: $userId'); // Debug log
      if (kIsWeb) {
        final finder = sembast.Finder(
          filter: sembast.Filter.custom((record) {
            final participantsRaw = record['participants'];
            final participants = participantsRaw is List
                ? List<String>.from(participantsRaw.map((e) => e.toString()))
                : <String>[];
            debugPrint(
                'Participants in conversation: $participants'); // Debug log
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
                debugPrint(
                    'Participants in conversation: ${convo['participants']}'); // Debug log
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

      if (kIsWeb) {
        await _messageStore.record(messageId).delete(await database);
        return 1;
      } else {
        final db = await database as sqflite.Database;
        return await db
            .delete('messages', where: 'id = ?', whereArgs: [messageId]);
      }
    } catch (e) {
      debugPrint('Failed to delete message: $e');
      throw Exception('Failed to delete message: $e');
    }
  }

  Future<String> updateMessage(Map<String, dynamic> message) async {
    final messageData = _normalizeMessageData(message);
    try {
      final messageId = messageData['id']?.toString() ?? '';
      if (messageId.isEmpty) {
        throw Exception('message id cannot be empty');
      }

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

      if (kIsWeb) {
        await _messageStore
            .record(messageId)
            .update(await database, messageData);
      } else {
        final db = await database as sqflite.Database;
        await db.update(
          'messages',
          {
            ...messageData,
            'reactions': jsonEncode(messageData['reactions']),
          },
          where: 'id = ?',
          whereArgs: [messageId],
        );
      }
      return messageId;
    } catch (e) {
      debugPrint('Failed to update message: $e');
      throw Exception('Failed to update message: $e');
    }
  }

  Future<void> insertConversation(Map<String, dynamic> conversation) async {
    final conversationData = Map<String, dynamic>.from(conversation);
    try {
      if (kIsWeb) {
        await _conversationStore.add(await database, conversationData);
      } else {
        final db = await database as sqflite.Database;
        await db.insert(
          'conversations',
          {
            'id': conversationData['id']?.toString() ?? _uuid.v4(),
            'data': jsonEncode(conversationData)
          },
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      }
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
      final firestoreResult = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('receiver_id', isEqualTo: userId)
          .where('is_read', isEqualTo: false)
          .get();
      final firestoreCount = firestoreResult.docs.length;

      int localCount = 0;
      if (kIsWeb) {
        final finder = sembast.Finder(
          filter: sembast.Filter.and([
            sembast.Filter.equals('receiver_id', userId),
            sembast.Filter.equals('is_read', 0),
          ]),
        );
        final records =
            await _messageStore.find(await database, finder: finder);
        localCount = records.length;
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'messages',
          where: 'receiver_id = ? AND is_read = ?',
          whereArgs: [userId, 0],
        );
        localCount = result.length;
      }

      final totalCount = firestoreCount + localCount;
      debugPrint(
          'Unread count for conversation $conversationId and user $userId: $totalCount');
      return totalCount;
    } catch (e) {
      debugPrint('Failed to get unread count: $e');
      throw Exception('Failed to get unread count: $e');
    }
  }

  Future<void> updateConversation(Map<String, dynamic> conversation) async {
    final conversationData = Map<String, dynamic>.from(conversation);
    final conversationId = conversationData['id']?.toString() ?? '';
    if (conversationId.isEmpty) {
      throw Exception('Conversation ID cannot be empty');
    }

    try {
      debugPrint('Updating conversation with ID: $conversationId');
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .set(conversationData, firestore.SetOptions(merge: true));

      if (kIsWeb) {
        await _conversationStore
            .record(conversationId)
            .update(await database, conversationData);
      } else {
        final db = await database as sqflite.Database;
        await db.update(
          'conversations',
          {
            'id': conversationId,
            'data': jsonEncode(conversationData),
          },
          where: 'id = ?',
          whereArgs: [conversationId],
        );
      }
      debugPrint('Conversation updated: $conversationId');
    } catch (e) {
      debugPrint('Failed to update conversation: $e');
      throw Exception('Failed to update conversation: $e');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      debugPrint('Deleting conversation with ID: $conversationId');
      await _firestore.collection('conversations').doc(conversationId).delete();

      if (kIsWeb) {
        await _conversationStore.record(conversationId).delete(await database);
      } else {
        final db = await database as sqflite.Database;
        await db.delete(
          'conversations',
          where: 'id = ?',
          whereArgs: [conversationId],
        );
      }
      debugPrint('Conversation deleted: $conversationId');
    } catch (e) {
      debugPrint('Failed to delete conversation: $e');
      throw Exception('Failed to delete conversation: $e');
    }
  }

  Future<void> muteConversation(
      String conversationId, List<String> mutedUsers) async {
    try {
      debugPrint('Muting conversation $conversationId for users: $mutedUsers');
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
        final result = await db.query(
          'conversations',
          where: 'id = ?',
          whereArgs: [conversationId],
        );
        if (result.isNotEmpty) {
          final convoData = jsonDecode(result.first['data'] as String);
          convoData['muted_users'] = mutedUsers;
          await db.update(
            'conversations',
            {
              'id': conversationId,
              'data': jsonEncode(convoData),
            },
            where: 'id = ?',
            whereArgs: [conversationId],
          );
        }
      }
      debugPrint('Conversation muted: $conversationId');
    } catch (e) {
      debugPrint('Failed to mute conversation: $e');
      throw Exception('Failed to mute conversation: $e');
    }
  }

  Future<void> blockConversation(
      String conversationId, List<String> blockedUsers) async {
    try {
      debugPrint(
          'Blocking conversation $conversationId for users: $blockedUsers');
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
        final result = await db.query(
          'conversations',
          where: 'id = ?',
          whereArgs: [conversationId],
        );
        if (result.isNotEmpty) {
          final convoData = jsonDecode(result.first['data'] as String);
          convoData['blocked_users'] = blockedUsers;
          await db.update(
            'conversations',
            {
              'id': conversationId,
              'data': jsonEncode(convoData),
            },
            where: 'id = ?',
            whereArgs: [conversationId],
          );
        }
      }
      debugPrint('Conversation blocked: $conversationId');
    } catch (e) {
      debugPrint('Failed to block conversation: $e');
      throw Exception('Failed to block conversation: $e');
    }
  }

  Future<void> close() async {
    try {
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
    try {
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
        'avatar':
            user['avatar']?.toString() ?? 'https://via.placeholder.com/200',
      };

      final definedColumns = [
        'id',
        'username',
        'email',
        'bio',
        'password',
        'auth_provider',
        'token',
        'created_at',
        'updated_at',
        'followers_count',
        'following_count',
        'avatar',
      ];
      final filteredUserData = Map.fromEntries(
        userData.entries.where((entry) => definedColumns.contains(entry.key)),
      );

      final userId = filteredUserData['id'];
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID cannot be empty');
      }

      debugPrint('Creating user with data: $filteredUserData');
      if (kIsWeb) {
        await _userStore.add(await database, filteredUserData);
        await _firestore
            .collection('users')
            .doc(userId)
            .set(filteredUserData, firestore.SetOptions(merge: true));
        debugPrint('User created with ID: $userId');
        return userId;
      } else {
        final db = await database as sqflite.Database;
        await db.insert(
          'users',
          filteredUserData,
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
        await _firestore
            .collection('users')
            .doc(userId)
            .set(filteredUserData, firestore.SetOptions(merge: true));
        debugPrint('User created with ID: $userId');
        return userId;
      }
    } catch (e) {
      debugPrint('Failed to create user: $e');
      throw Exception('Failed to create user: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final firestoreResult = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (firestoreResult.docs.isNotEmpty) {
        return _normalizeUserData(firestoreResult.docs.first.data());
      }

      if (kIsWeb) {
        final finder =
            sembast.Finder(filter: sembast.Filter.equals('email', email));
        final record =
            await _userStore.findFirst(await database, finder: finder);
        return record != null ? _normalizeUserData(record.value) : null;
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'users',
          where: 'email = ?',
          whereArgs: [email],
        );
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
      debugPrint('Fetching user with ID: $id');
      final firestoreDoc = await _firestore.collection('users').doc(id).get();
      if (firestoreDoc.exists) {
        final data = firestoreDoc.data()!;
        data['id'] = firestoreDoc.id;
        debugPrint('User found in Firestore: ${data['id']}');
        return _normalizeUserData(data);
      } else {
        debugPrint('User not found in Firestore: $id');
      }

      if (kIsWeb) {
        final record = await _userStore.record(id).get(await database);
        if (record != null) {
          debugPrint('User found in Sembast: $id');
          return _normalizeUserData(record);
        } else {
          debugPrint('User not found in Sembast: $id');
          return null;
        }
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (result.isNotEmpty) {
          debugPrint('User found in SQLite: $id');
          return _normalizeUserData(Map<String, dynamic>.from(result.first));
        } else {
          debugPrint('User not found in SQLite: $id');
          return null;
        }
      }
    } catch (e) {
      debugPrint('Failed to get user by ID $id: $e');
      throw Exception('Failed to get user by ID: $e');
    }
  }

  Future<String> updateUser(Map<String, dynamic> user) async {
    try {
      final userData = {
        'id': user['id']?.toString() ?? '',
        'username': user['username']?.toString() ?? '',
        'email': user['email']?.toString() ?? '',
        'bio': user['bio']?.toString() ?? '',
        'password': user['password']?.toString() ?? '',
        'auth_provider': user['auth_provider']?.toString() ?? '',
        'token': user['token']?.toString(),
        'created_at': user['created_at']?.toString(),
        'updated_at': DateTime.now().toIso8601String(),
        'followers_count': user['followers_count']?.toString() ?? '0',
        'following_count': user['following_count']?.toString() ?? '0',
        'avatar':
            user['avatar']?.toString() ?? 'https://via.placeholder.com/200',
      };
      final String userId = userData['id']!;
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty');
      }

      final definedColumns = [
        'id',
        'username',
        'email',
        'bio',
        'password',
        'auth_provider',
        'token',
        'created_at',
        'updated_at',
        'followers_count',
        'following_count',
        'avatar',
      ];
      final filteredUserData = Map.fromEntries(
        userData.entries.where((entry) => definedColumns.contains(entry.key)),
      );

      debugPrint('Updating user: $userId');
      await _firestore
          .collection('users')
          .doc(userId)
          .set(filteredUserData, firestore.SetOptions(merge: true));
      if (kIsWeb) {
        await _userStore
            .record(userId)
            .update(await database, filteredUserData);
      } else {
        final db = await database as sqflite.Database;
        await db.update(
          'users',
          filteredUserData,
          where: 'id = ?',
          whereArgs: [userId],
        );
      }
      debugPrint('User updated: $userId');
      return userId;
    } catch (e) {
      debugPrint('Failed to update user: $e');
      throw Exception('Failed to update user: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final firestoreResult = await _firestore.collection('users').get();
      final firestoreUsers = firestoreResult.docs
          .map((doc) => _normalizeUserData(doc.data()))
          .toList();

      List<Map<String, dynamic>> localUsers;
      if (kIsWeb) {
        final records = await _userStore.find(await database);
        localUsers = records
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r.value)))
            .toList();
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query('users');
        localUsers = result
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r)))
            .toList();
      }

      final allUsersMap = <String, Map<String, dynamic>>{};
      for (var user in firestoreUsers) {
        final userId = user['id'] as String;
        allUsersMap[userId] = user;
      }
      for (var user in localUsers) {
        final userId = user['id'] as String;
        if (!allUsersMap.containsKey(userId)) {
          allUsersMap[userId] = user;
        }
      }

      debugPrint('Fetched ${allUsersMap.length} users');
      return allUsersMap.values.toList();
    } catch (e) {
      debugPrint('Failed to get all users: $e');
      throw Exception('Failed to get all users: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final firestoreResult = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .get();
      final firestoreUsers = firestoreResult.docs
          .map((doc) => _normalizeUserData(doc.data()))
          .toList();

      List<Map<String, dynamic>> localUsers;
      if (kIsWeb) {
        final finder = sembast.Finder(
            filter: sembast.Filter.matches('username', '^$query.*'));
        final records = await _userStore.find(await database, finder: finder);
        localUsers = records
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r.value)))
            .toList();
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'users',
          where: 'username LIKE ?',
          whereArgs: ['$query%'],
        );
        localUsers = result
            .map((r) => _normalizeUserData(Map<String, dynamic>.from(r)))
            .toList();
      }

      final allUsersMap = <String, Map<String, dynamic>>{};
      for (var user in firestoreUsers) {
        final userId = user['id'] as String;
        allUsersMap[userId] = user;
      }
      for (var user in localUsers) {
        final userId = user['id'] as String;
        if (!allUsersMap.containsKey(userId)) {
          allUsersMap[userId] = user;
        }
      }

      debugPrint('Fetched ${allUsersMap.length} users for query: $query');
      return allUsersMap.values.toList();
    } catch (e) {
      debugPrint('Failed to search users: $e');
      throw Exception('Failed to search users: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserByToken(String token) async {
    try {
      final firestoreResult = await _firestore
          .collection('users')
          .where('token', isEqualTo: token)
          .limit(1)
          .get();
      if (firestoreResult.docs.isNotEmpty) {
        return _normalizeUserData(firestoreResult.docs.first.data());
      }

      if (kIsWeb) {
        final finder =
            sembast.Finder(filter: sembast.Filter.equals('token', token));
        final record =
            await _userStore.findFirst(await database, finder: finder);
        return record != null ? _normalizeUserData(record.value) : null;
      } else {
        final db = await database as sqflite.Database;
        final result = await db.query(
          'users',
          where: 'token = ?',
          whereArgs: [token],
        );
        return result.isNotEmpty
            ? _normalizeUserData(Map<String, dynamic>.from(result.first))
            : null;
      }
    } catch (e) {
      debugPrint('Failed to get user by token: $e');
      return null;
    }
  }
}
