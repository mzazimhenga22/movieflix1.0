import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sembast/sembast.dart' as sembast;
import 'package:sqflite/sqflite.dart' as sqflite;

class Users {
  final FirebaseFirestore _firestore;
  final sqflite.Database? _sqfliteDb;
  final sembast.DatabaseFactory? _dbFactory;
  final sembast.StoreRef _userStore;
  sembast.Database? _sembastDb;

  Users({
    required FirebaseFirestore firestore,
    sqflite.Database? database,
    sembast.DatabaseFactory? dbFactory,
    sembast.StoreRef? userStore,
  })  : _firestore = firestore,
        _sqfliteDb = database,
        _dbFactory = dbFactory,
        _userStore = userStore ?? sembast.StoreRef.main();

  String _coerceToString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  Map<String, dynamic> _normalizeUserData(Map<String, dynamic> user) {
    return {
      'id': _coerceToString(user['id']),
      'username': _coerceToString(user['username']),
      'email': _coerceToString(user['email']),
      'bio': _coerceToString(user['bio']),
      'password': _coerceToString(user['password']),
      'auth_provider': _coerceToString(user['auth_provider']),
      'token': _coerceToString(user['token']),
      'created_at': _coerceToString(user['created_at']),
      'updated_at': _coerceToString(user['updated_at']),
      'followers_count': _coerceToString(user['followers_count'] ?? '0'),
      'following_count': _coerceToString(user['following_count'] ?? '0'),
      'profile_id': _coerceToString(user['profile_id']),
      'avatar': _coerceToString(user['avatar']),
      'profile_name': _coerceToString(user['profile_name']),
    };
  }

  Future<dynamic> get database async {
    if (kIsWeb) {
      _sembastDb ??= await _dbFactory!.openDatabase('auth.db');
      return _sembastDb!;
    } else {
      if (_sqfliteDb == null) {
        throw Exception('SQLite database not provided');
      }
      return _sqfliteDb!;
    }
  }

  Future<String> createUser(Map<String, dynamic> user) async {
    final userData = <String, dynamic>{
      'username': _coerceToString(user['username']),
      'email': _coerceToString(user['email']),
      'bio': _coerceToString(user['bio']),
      'password': _coerceToString(user['password']),
      'auth_provider': _coerceToString(user['auth_provider'] ?? 'firebase'),
      'token': _coerceToString(user['token']),
      'created_at': _coerceToString(
          user['created_at'] ?? DateTime.now().toIso8601String()),
      'updated_at': _coerceToString(
          user['updated_at'] ?? DateTime.now().toIso8601String()),
      'followers_count': _coerceToString(user['followers_count'] ?? '0'),
      'following_count': _coerceToString(user['following_count'] ?? '0'),
      'avatar':
          _coerceToString(user['avatar'] ?? 'https://via.placeholder.com/200'),
    };

    if (userData['username']!.isEmpty) {
      throw Exception('Username is required');
    }
    if (userData['email']!.isEmpty) {
      throw Exception('Email is required');
    }

    try {
      String newId;
      if (kIsWeb) {
        newId =
            await (_userStore as sembast.StoreRef<String, Map<String, dynamic>>)
                .add(await database, userData);
        userData['id'] = newId;
        await _firestore.collection('users').doc(newId).set(userData);
      } else {
        newId = DateTime.now().millisecondsSinceEpoch.toString();
        userData['id'] = newId;
        await (await database as sqflite.Database).insert(
          'users',
          userData,
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
        await _firestore.collection('users').doc(newId).set(userData);
      }
      return newId;
    } catch (e) {
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
        final doc = firestoreResult.docs.first;
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id.toString();
        return _normalizeUserData(data);
      }

      if (kIsWeb) {
        final finder = sembast.Finder(
          filter: sembast.Filter.equals('email', email),
        );
        final record =
            await (_userStore as sembast.StoreRef<String, Map<String, dynamic>>)
                .findFirst(await database, finder: finder);
        if (record != null) {
          final userData = Map<String, dynamic>.from(record.value);
          userData['id'] = record.key.toString();
          return _normalizeUserData(userData);
        }
        return null;
      } else {
        final result = await (await database as sqflite.Database).query(
          'users',
          where: 'email = ?',
          whereArgs: [email],
        );
        if (result.isNotEmpty) {
          final userData = Map<String, dynamic>.from(result.first);
          userData['id'] = _coerceToString(userData['id']);
          return _normalizeUserData(userData);
        }
        return null;
      }
    } catch (e) {
      throw Exception('Failed to fetch user by email: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserById(String id) async {
    try {
      final firestoreDoc = await _firestore.collection('users').doc(id).get();
      if (firestoreDoc.exists) {
        final data = Map<String, dynamic>.from(firestoreDoc.data()!);
        data['id'] = firestoreDoc.id.toString();
        return _normalizeUserData(data);
      }

      if (kIsWeb) {
        final record =
            await (_userStore as sembast.StoreRef<String, Map<String, dynamic>>)
                .record(id)
                .get(await database);
        if (record != null) {
          final userData = Map<String, dynamic>.from(record);
          userData['id'] = id.toString();
          return _normalizeUserData(userData);
        }
        return null;
      } else {
        final result = await (await database as sqflite.Database).query(
          'users',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (result.isNotEmpty) {
          final userData = Map<String, dynamic>.from(result.first);
          userData['id'] = _coerceToString(userData['id']);
          return _normalizeUserData(userData);
        }
        return null;
      }
    } catch (e) {
      throw Exception('Failed to fetch user by id: $e');
    }
  }

  Future<String> updateUser(Map<String, dynamic> user) async {
    final userData = <String, dynamic>{
      'id': _coerceToString(user['id']),
      'username': _coerceToString(user['username']),
      'email': _coerceToString(user['email']),
      'bio': _coerceToString(user['bio']),
      'password': _coerceToString(user['password']),
      'auth_provider': _coerceToString(user['auth_provider']),
      'token': _coerceToString(user['token']),
      'created_at': _coerceToString(user['created_at']),
      'updated_at': _coerceToString(
          user['updated_at'] ?? DateTime.now().toIso8601String()),
      'followers_count': _coerceToString(user['followers_count'] ?? '0'),
      'following_count': _coerceToString(user['following_count'] ?? '0'),
      'avatar': _coerceToString(user['avatar']),
    };

    try {
      final userId = userData['id']!;
      await _firestore.collection('users').doc(userId).update(userData);
      if (kIsWeb) {
        await (_userStore as sembast.StoreRef<String, Map<String, dynamic>>)
            .record(userId)
            .update(await database, userData);
      } else {
        await (await database as sqflite.Database).update(
          'users',
          userData,
          where: 'id = ?',
          whereArgs: [userId],
        );
      }
      return userId;
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final firestoreUsers = await _firestore.collection('users').get();
      final firestoreUserList = firestoreUsers.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id.toString();
        return _normalizeUserData(data);
      }).toList();

      List<Map<String, dynamic>> localUsers;
      if (kIsWeb) {
        final records =
            await (_userStore as sembast.StoreRef<String, Map<String, dynamic>>)
                .find(await database);
        localUsers = records.map((r) {
          final userData = Map<String, dynamic>.from(r.value);
          final normalizedData = userData
              .map((key, value) => MapEntry(key, _coerceToString(value)));
          normalizedData['id'] = r.key.toString();
          return _normalizeUserData(normalizedData);
        }).toList();
      } else {
        final result = await (await database as sqflite.Database).rawQuery('''
          SELECT u.*,
                 CAST(u.followers_count AS TEXT) AS followers_count,
                 CAST(u.following_count AS TEXT) AS following_count,
                 p.id AS profile_id,
                 p.avatar AS profile_avatar,
                 p.name AS profile_name
          FROM users u
          LEFT JOIN profiles p ON u.id = p.user_id
        ''');
        localUsers = result.map((r) {
          final userData = Map<String, dynamic>.from(r);
          userData['id'] = _coerceToString(userData['id']);
          return _normalizeUserData(userData);
        }).toList();
      }

      final allUsersMap = <String, Map<String, dynamic>>{};
      for (var user in firestoreUserList) {
        allUsersMap[user['id']] = user;
      }
      for (var local in localUsers) {
        final userId = local['id'];
        allUsersMap[userId] = _normalizeUserData({
          ...allUsersMap[userId] ?? {},
          ...local,
        });
      }

      return allUsersMap.values.toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final normalizedQuery = query.toLowerCase().trim();
    try {
      final firestoreUsers = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: normalizedQuery)
          .where('username', isLessThanOrEqualTo: normalizedQuery + '\uf8ff')
          .get();
      final firestoreUserList = firestoreUsers.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id.toString();
        return _normalizeUserData(data);
      }).toList();

      List<Map<String, dynamic>> localUsers;
      if (kIsWeb) {
        final records =
            await (_userStore as sembast.StoreRef<String, Map<String, dynamic>>)
                .find(await database);
        localUsers = records.map((r) {
          final userData = Map<String, dynamic>.from(r.value);
          final normalizedData = userData
              .map((key, value) => MapEntry(key, _coerceToString(value)));
          normalizedData['id'] = r.key.toString();
          return _normalizeUserData(normalizedData);
        }).toList();
      } else {
        final result = await (await database as sqflite.Database).rawQuery('''
          SELECT u.*,
                 CAST(u.followers_count AS TEXT) AS followers_count,
                 CAST(u.following_count AS TEXT) AS following_count,
                 p.id AS profile_id,
                 p.avatar AS profile_avatar,
                 p.name AS profile_name
          FROM users u
          LEFT JOIN profiles p ON u.id = p.user_id
        ''');
        localUsers = result.map((r) {
          final userData = Map<String, dynamic>.from(r);
          userData['id'] = _coerceToString(userData['id']);
          return _normalizeUserData(userData);
        }).toList();
      }

      final allUsersMap = <String, Map<String, dynamic>>{};
      for (var user in firestoreUserList) {
        allUsersMap[user['id']] = user;
      }
      for (var local in localUsers) {
        final userId = local['id'];
        allUsersMap[userId] = _normalizeUserData({
          ...allUsersMap[userId] ?? {},
          ...local,
        });
      }

      return allUsersMap.values.where((user) {
        final normalizedUser = _normalizeUserData(user);
        final username = (normalizedUser['username'] ?? '').toLowerCase();
        final email = (normalizedUser['email'] ?? '').toLowerCase();
        return username.contains(normalizedQuery) ||
            email.contains(normalizedQuery);
      }).toList();
    } catch (e) {
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
        final doc = firestoreResult.docs.first;
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id.toString();
        return _normalizeUserData(data);
      }

      if (kIsWeb) {
        final finder = sembast.Finder(
          filter: sembast.Filter.equals('token', token),
        );
        final record =
            await (_userStore as sembast.StoreRef<String, Map<String, dynamic>>)
                .findFirst(await database, finder: finder);
        if (record != null) {
          final userData = Map<String, dynamic>.from(record.value);
          userData['id'] = record.key.toString();
          return _normalizeUserData(userData);
        }
        return null;
      } else {
        final result = await (await database as sqflite.Database).query(
          'users',
          where: 'token = ?',
          whereArgs: [token],
        );
        if (result.isNotEmpty) {
          final userData = Map<String, dynamic>.from(result.first);
          userData['id'] = _coerceToString(userData['id']);
          return _normalizeUserData(userData);
        }
        return null;
      }
    } catch (e) {
      throw Exception('Failed to fetch user by token: $e');
    }
  }
}
