// models/user_profile_model.dart

class UserProfileModel {
  final String uid;
  final String name;
  final String email;
  final List<String> skills;
  final int experience; // years
  final String preferredRole;

  const UserProfileModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.skills,
    required this.experience,
    required this.preferredRole,
  });

  factory UserProfileModel.empty(String uid, String email) => UserProfileModel(
        uid: uid,
        name: '',
        email: email,
        skills: [],
        experience: 0,
        preferredRole: '',
      );

  factory UserProfileModel.fromMap(Map<String, dynamic> map, String uid) =>
      UserProfileModel(
        uid: uid,
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        skills: List<String>.from(map['skills'] ?? []),
        experience: (map['experience'] ?? 0) is int
            ? map['experience']
            : int.tryParse(map['experience'].toString()) ?? 0,
        preferredRole: map['preferred_role'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'skills': skills,
        'experience': experience,
        'preferred_role': preferredRole,
      };

  UserProfileModel copyWith({
    String? name,
    String? email,
    List<String>? skills,
    int? experience,
    String? preferredRole,
  }) =>
      UserProfileModel(
        uid: uid,
        name: name ?? this.name,
        email: email ?? this.email,
        skills: skills ?? this.skills,
        experience: experience ?? this.experience,
        preferredRole: preferredRole ?? this.preferredRole,
      );
}
