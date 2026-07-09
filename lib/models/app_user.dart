import '../core/utils/firestore_utils.dart';

/// The authenticated user's profile document (collection `users`, keyed by UID).
///
/// `hasCompanyProfile` lets the app decide whether to show the Business Setup
/// Wizard on first launch after login.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.hasCompanyProfile = false,
    this.createdAt,
    this.lastLoginAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final bool hasCompanyProfile;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  AppUser copyWith({
    String? email,
    String? displayName,
    bool? hasCompanyProfile,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      hasCompanyProfile: hasCompanyProfile ?? this.hasCompanyProfile,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      email: asString(map['email']),
      displayName: asString(map['displayName']),
      hasCompanyProfile: asBool(map['hasCompanyProfile']),
      createdAt: tsToDate(map['createdAt']),
      lastLoginAt: tsToDate(map['lastLoginAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'email': email,
        'displayName': displayName,
        'hasCompanyProfile': hasCompanyProfile,
        'createdAt': dateToTs(createdAt),
        'lastLoginAt': dateToTs(lastLoginAt),
      };
}
