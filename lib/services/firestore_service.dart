import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subject.dart';
import '../models/app_settings.dart';

class FirestoreService {
  FirestoreService._internal();
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _subjectsRef(
    String uid,
    String semester,
  ) {
    final safeSemester = semester.replaceAll('/', '_').trim();
    return _db
        .collection('users')
        .doc(uid)
        .collection('semesters')
        .doc(safeSemester.isEmpty ? 'Semester_1' : safeSemester)
        .collection('subjects');
  }

  CollectionReference<Map<String, dynamic>> _deletedRef(
    String uid,
    String semester,
  ) {
    final safeSemester = semester.replaceAll('/', '_').trim();
    return _db
        .collection('users')
        .doc(uid)
        .collection('semesters')
        .doc(safeSemester.isEmpty ? 'Semester_1' : safeSemester)
        .collection('deleted_subjects');
  }

  DocumentReference<Map<String, dynamic>> _settingsRef(String uid) {
    return _db.collection('users').doc(uid).collection('meta').doc('settings');
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return _db.collection('users').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return _db.collection('users').doc(uid).collection('meta').doc('profile');
  }

  Future<List<Subject>> loadSubjects(String uid, String semester) async {
    final snap = await _subjectsRef(uid, semester).get();
    final list = <Subject>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      data.putIfAbsent('id', () => doc.id);
      list.add(Subject.fromMap(data));
    }
    return list;
  }

  Future<List<Subject>> syncSubjects(
    String uid,
    String semester,
    List<Subject> local,
  ) async {
    final deleted = await _deletedRef(uid, semester).get();
    final deletedMap = <String, int>{};
    for (final d in deleted.docs) {
      final raw = d.data()['deletedAt'];
      if (raw is int) {
        deletedMap[d.id] = raw;
      } else if (raw is num) {
        deletedMap[d.id] = raw.toInt();
      } else {
        deletedMap[d.id] = 0;
      }
    }

    final remote = await loadSubjects(uid, semester);
    final merged = _merge(local, remote, deletedMap);
    final batch = _db.batch();
    final ref = _subjectsRef(uid, semester);
    for (final subject in merged) {
      batch.set(ref.doc(subject.id), subject.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
    return merged;
  }

  Future<void> deleteSubject(String uid, String semester, String subjectId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    batch.delete(_subjectsRef(uid, semester).doc(subjectId));
    batch.set(_deletedRef(uid, semester).doc(subjectId), {'deletedAt': now});
    await batch.commit();
  }

  Future<void> deleteSemesterData(String uid, String semester) async {
    final subjects = await _subjectsRef(uid, semester).get();
    if (subjects.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in subjects.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    final deleted = await _deletedRef(uid, semester).get();
    if (deleted.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in deleted.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    final safeSemester = semester.replaceAll('/', '_').trim();
    final semRef = _db
        .collection('users')
        .doc(uid)
        .collection('semesters')
        .doc(safeSemester.isEmpty ? 'Semester_1' : safeSemester);
    await semRef.delete().catchError((_) {});
  }

  Future<AppSettings?> loadSettings(String uid) async {
    try {
      final doc = await _settingsRef(uid).get();
      if (!doc.exists) return null;
      return AppSettings.fromMap(doc.data());
    } catch (e) {
      debugPrint('loadSettings failed: $e');
      return null;
    }
  }

  Future<void> saveSettings(String uid, AppSettings settings) async {
    try {
      await _settingsRef(uid).set(settings.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('saveSettings failed: $e');
    }
  }

  Future<bool> upsertUserMetadata(User user) async {
    final payload = {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'phoneNumber': user.phoneNumber,
      'photoURL': user.photoURL,
      'emailVerified': user.emailVerified,
      'providerIds': user.providerData.map((e) => e.providerId).toList(),
      'createdAt': user.metadata.creationTime?.millisecondsSinceEpoch,
      'lastSignInAt': user.metadata.lastSignInTime?.millisecondsSinceEpoch,
      'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    try {
      await _userRef(user.uid).set({
        ...payload,
        'authToken': FieldValue.delete(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('upsertUserMetadata root failed: $e');
      try {
        await _profileRef(user.uid).set({
          'account': payload,
        }, SetOptions(merge: true));
        return true;
      } catch (e2) {
        debugPrint('upsertUserMetadata fallback failed: $e2');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> loadUserProfile(String uid) async {
    try {
      final doc = await _userRef(uid).get();
      final root = doc.data();
      if (root != null) return root;
    } catch (e) {
      debugPrint('loadUserProfile root failed: $e');
    }
    try {
      final meta = await _profileRef(uid).get();
      return meta.data();
    } catch (e) {
      debugPrint('loadUserProfile fallback failed: $e');
    }
    return null;
  }

  Future<bool> saveUserProfile(
    String uid, {
    required String fullName,
    required String phone,
    required String bio,
  }) async {
    try {
      await _userRef(uid).set({
        'profile': {
          'fullName': fullName,
          'phone': phone,
          'bio': bio,
        },
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('saveUserProfile root failed: $e');
      try {
        await _profileRef(uid).set({
          'profile': {
            'fullName': fullName,
            'phone': phone,
            'bio': bio,
          },
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
        return true;
      } catch (e2) {
        debugPrint('saveUserProfile fallback failed: $e2');
      }
      return false;
    }
  }

  List<Subject> _merge(
    List<Subject> local,
    List<Subject> remote,
    Map<String, int> deleted,
  ) {
    final map = <String, Subject>{};
    for (final s in local) {
      final deletedAt = deleted[s.id] ?? -1;
      if (deletedAt > s.updatedAt) continue;
      map[s.id] = s;
    }
    for (final s in remote) {
      final deletedAt = deleted[s.id] ?? -1;
      if (deletedAt > s.updatedAt) continue;
      final existing = map[s.id];
      if (existing == null || s.updatedAt > existing.updatedAt) {
        map[s.id] = s;
      }
    }
    return map.values.toList();
  }
}
