// services/profile_service.dart
// Reads and writes user profile data from Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_model.dart';

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection('users');

  /// Fetch profile for a given UID. Returns null if not yet created.
  Future<UserProfileModel?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfileModel.fromMap(
      doc.data() as Map<String, dynamic>,
      uid,
    );
  }

  /// Create or overwrite a user profile in Firestore.
  Future<void> saveProfile(UserProfileModel profile) async {
    await _users.doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  /// Update only specific fields.
  Future<void> updateFields(String uid, Map<String, dynamic> fields) async {
    await _users.doc(uid).update(fields);
  }
}
