import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import 'package:quick_scanner/routes_list.dart';

class DeepLinkService {
  static bool get hasPending => _pendingDeepLink != null;
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static Uri? _pendingDeepLink;
  static bool _appReady = false;

  static Future<void> init() async {
    // Cold start: link that launched the app
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _onLink(initial);
    } catch (e) {
      debugPrint("Initial link error => $e");
    }

    // Links while app is running
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      _onLink,
      onError: (e) => debugPrint("DeepLink Stream Error => $e"),
    );
  }

  /// Call this ONCE when splash/init is finished and routes are ready.
  static void markReady() {
    _appReady = true;
    _handlePending();
  }

  static void _onLink(Uri uri) {
    debugPrint("Link received => $uri");
    _pendingDeepLink = uri; // latest link wins, duplicates are overwritten
    if (_appReady) _handlePending();
  }

  static void _handlePending() {
    final uri = _pendingDeepLink;
    if (uri == null) return;
    _pendingDeepLink = null;

    final segments = uri.pathSegments;
    final i = segments.indexOf("reset-password");

    if (i != -1 && i + 1 < segments.length) {
      Get.offAllNamed(
        RouteList.resetPassword,
        arguments: {
          "token": segments[i + 1],
          "email": uri.queryParameters["email"] ?? "",
        },
      );
    }
  }
}
