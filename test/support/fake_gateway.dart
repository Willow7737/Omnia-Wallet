import 'package:flutter/foundation.dart';
import 'package:omnia_wallet/data/supabase_gateway.dart';

/// A [SupabaseGateway] that does nothing, for tests to extend.
///
/// Every test that touches auth needs a stand-in, and each one only cares
/// about two or three members. Implementing the interface afresh in each file
/// meant that adding a method to the seam broke four unrelated test files at
/// once; overriding a default breaks none of them.
class FakeGatewayBase implements SupabaseGateway {
  FakeGatewayBase({this.authenticated = true});

  bool authenticated;

  /// What [fetchProfile] hands back.
  RemoteProfile? profile = const RemoteProfile();

  /// What [fetchNotifications] hands back.
  List<RemoteNotice> notifications = const [];

  final List<({String? displayName, String? avatarUrl})> savedProfiles = [];
  int uploads = 0;
  int profileFetches = 0;
  int notificationFetches = 0;
  int markedRead = 0;
  int cleared = 0;
  final List<({String token, String platform})> registeredDevices = [];
  final List<String> unregisteredDevices = [];

  @override
  bool get isAvailable => true;

  @override
  bool get isSignedIn => authenticated;

  @override
  String? get userId => authenticated ? 'uid-1' : null;

  @override
  String? get userEmail => 'user@example.com';

  @override
  String? get userName => 'Willow';

  @override
  Future<String> accessToken() async => 'token';

  @override
  Future<void> signInWithSocial(SocialProvider provider) async {}

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Stream<void> get signedIn => const Stream<void>.empty();

  @override
  Stream<void> tableChanges(String table) => const Stream<void>.empty();

  @override
  Future<RemoteProfile?> fetchProfile() async {
    profileFetches++;
    return profile;
  }

  @override
  Future<void> saveProfile({
    String? displayName,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    savedProfiles.add((displayName: displayName, avatarUrl: avatarUrl));
    profile = RemoteProfile(
      displayName: displayName ?? profile?.displayName,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? profile?.avatarUrl),
    );
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    uploads++;
    return 'https://example.test/avatars/uid-1/$uploads.$fileExtension';
  }

  @override
  Future<List<RemoteNotice>> fetchNotifications({int limit = 50}) async {
    notificationFetches++;
    return authenticated ? notifications : const [];
  }

  @override
  Future<void> markNotificationsRead() async => markedRead++;

  @override
  Future<void> clearNotifications() async => cleared++;

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    registeredDevices.add((token: token, platform: platform));
  }

  @override
  Future<void> unregisterDevice(String token) async {
    unregisteredDevices.add(token);
  }
}
