import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import '../../../core/network/transfer_channel.dart';

/// Represents a captured mobile notification to be mirrored on desktop.
class MirroredNotification {
  final String appName;
  final String title;
  final String body;
  final DateTime postedAt;

  MirroredNotification({
    required this.appName,
    required this.title,
    required this.body,
    required this.postedAt,
  });

  Map<String, dynamic> toJson() => {
        'type': 'notification',
        'app': appName,
        'title': title,
        'body': body,
        'postedAt': postedAt.toIso8601String(),
      };

  factory MirroredNotification.fromJson(Map<String, dynamic> json) =>
      MirroredNotification(
        appName: json['app'],
        title: json['title'],
        body: json['body'],
        postedAt: DateTime.parse(json['postedAt']),
      );
}

/// On Android, notification *capture* requires a native
/// NotificationListenerService (declared in AndroidManifest.xml /
/// MainActivity.kt — see android/README in this package) which streams
/// captured notifications down to Dart over a MethodChannel. This class
/// is the Dart-side bridge plus the desktop-side renderer.
class NotificationMirrorService {
  static const _channel = MethodChannel('neardrop/notifications');

  final TransferChannel transferChannel;
  StreamController<MirroredNotification>? _capturedController;

  NotificationMirrorService({required this.transferChannel}) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _capturedController = StreamController<MirroredNotification>.broadcast();
      _channel.setMethodCallHandler(_onNativeNotification);
    }
  }

  /// Mobile side: native listener calls this via MethodChannel whenever a
  /// new notification is posted on the device.
  Future<void> _onNativeNotification(MethodCall call) async {
    if (call.method != 'onNotificationPosted') return;
    final map = Map<String, dynamic>.from(call.arguments as Map);
    final notif = MirroredNotification(
      appName: map['appName'] ?? 'Unknown',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      postedAt: DateTime.now(),
    );
    _capturedController?.add(notif);
    await _sendToDesktop(notif);
  }

  Future<void> _sendToDesktop(MirroredNotification notif) async {
    final payload = jsonEncode(notif.toJson());
    await transferChannel.sendChunk(utf8.encode(payload));
  }

  /// Desktop side: listens to the channel and renders a native system
  /// notification (via local_notifier) for every mirrored item.
  void startDesktopListener() {
    transferChannel.incomingChunks.listen((data) async {
      try {
        final map = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
        if (map['type'] != 'notification') return;
        final notif = MirroredNotification.fromJson(map);

        final n = LocalNotification(
          title: '${notif.appName}: ${notif.title}',
          body: notif.body,
        );
        await n.show();
      } catch (_) {
        // Not a notification frame, ignore.
      }
    });
  }

  Future<bool> requestAndroidPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    final granted = await _channel.invokeMethod<bool>('requestPermission');
    return granted ?? false;
  }

  void dispose() {
    _capturedController?.close();
  }
}
