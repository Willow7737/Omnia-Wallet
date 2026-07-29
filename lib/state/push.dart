import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_gateway.dart';
import 'notices.dart';
import 'providers.dart';

/// Device push, end to end: register this handset, show what arrives, and
/// route where a tap should go.
///
/// Every entry point here is guarded by [_available]. Firebase needs
/// `android/app/google-services.json`, which is a credential nobody can commit
/// and not everybody building this app will have — so its absence turns push
/// off rather than crashing the app or failing the build. See `docs/PUSH.md`.
class PushService {
  PushService(this._ref);

  final Ref _ref;

  static const String _channelId = 'omnia_replies';

  /// Set once [start] has got as far as a working Firebase app.
  bool _available = false;
  bool _started = false;
  String? _token;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final List<StreamSubscription<dynamic>> _subs = [];

  SupabaseGateway get _gateway => _ref.read(supabaseGatewayProvider);

  /// Whether push is usable on this build. False on a build without Firebase
  /// credentials, and on platforms the app does not configure it for.
  bool get isAvailable => _available;

  /// Called once at launch. Safe to call again; only the first does anything.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      // No google-services.json, or a malformed one. Everything else in the
      // app keeps working — the in-app notification feed does not depend on
      // Firebase at all.
      debugPrint('Push disabled — Firebase did not initialise: $e');
      return;
    }

    await _createChannel();
    await _requestPermission();

    // A token can arrive before sign-in and be rotated at any time, so both
    // paths lead to the same place rather than only reading it once.
    _subs.add(FirebaseMessaging.instance.onTokenRefresh.listen(_onToken));
    _subs.add(_gateway.signedIn.listen((_) => syncRegistration()));
    await syncRegistration();

    // Foreground. Android deliberately does not display a notification while
    // the app is on screen, so this draws one; without it a reply arriving
    // while you are reading produces nothing at all.
    _subs.add(FirebaseMessaging.onMessage.listen(_showForeground));

    // Background tap, and the cold-start case where the tap is what launched
    // the app.
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _openFromMessage(initial);
  }

  Future<void> _createChannel() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      // FCM asks for these itself; asking twice shows the reader two prompts.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _open(payload);
      },
    );

    // Must match the id in AndroidManifest.xml, or a background notification
    // is filed under a channel the reader cannot find in system settings.
    const channel = AndroidNotificationChannel(
      _channelId,
      'Replies',
      description: 'When somebody replies to you.',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermission() async {
    // On Android 13+ this is the runtime POST_NOTIFICATIONS prompt; below it,
    // and on iOS, it is the platform's own permission sheet.
    await FirebaseMessaging.instance.requestPermission();
  }

  /// Point this handset at whoever is signed in now.
  ///
  /// Called at launch and on every sign-in. The upsert is keyed on the token,
  /// so signing in as somebody else moves the registration across rather than
  /// leaving the previous account subscribed to this phone.
  Future<void> syncRegistration() async {
    if (!_available || !_gateway.isSignedIn) return;
    try {
      final token = _token ?? await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _onToken(token);
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  Future<void> _onToken(String token) async {
    _token = token;
    if (!_gateway.isSignedIn) return;
    try {
      await _gateway.registerDevice(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  /// Stop this handset receiving the account's notifications.
  ///
  /// Called on sign-out. A shared phone must not keep buzzing with the
  /// previous person's replies.
  Future<void> unregister() async {
    final token = _token;
    if (!_available || token == null) return;
    try {
      await _gateway.unregisterDevice(token);
    } catch (e) {
      debugPrint('Push unregister failed: $e');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    // The feed is the other half of this: a push tells you now, the feed is
    // what you scroll back through later.
    unawaited(_ref.read(noticesProvider.notifier).syncRemote());

    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      // A stable id per conversation, so three replies to the same post
      // replace each other rather than stacking three rows deep.
      (message.data['link'] ?? message.messageId ?? '').hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Replies',
          channelDescription: 'When somebody replies to you.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['link'] as String? ?? '',
    );
  }

  void _openFromMessage(RemoteMessage message) {
    unawaited(_ref.read(noticesProvider.notifier).syncRemote());
    _open(message.data['link'] as String? ?? '');
  }

  /// Hand the tap to whoever is listening — the app shell, which owns the
  /// router. Doing the navigation here would mean this service needed a
  /// BuildContext, and it runs before there is one.
  void _open(String link) {
    _ref.read(pushOpenProvider.notifier).state = link.isEmpty ? null : link;
  }

  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }
}

/// The link of the most recent notification tap, for the shell to act on and
/// then clear. Null when there is nothing pending.
final pushOpenProvider = StateProvider<String?>((ref) => null);

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.onDispose(service.dispose);
  return service;
});
