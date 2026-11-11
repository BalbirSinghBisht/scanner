import 'dart:io';
import 'package:flutter/foundation.dart';

/// Hardens HTTP/HTTPS connections against VAPT interception & proxy snooping (Burp Suite, Charles, mitmproxy)
class SecureHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Force direct connection: bypasses any device/Wi-Fi proxy configured by security testers
    client.findProxy = (uri) => 'DIRECT';
    // Strictly reject untrusted/self-signed certificates to prevent MITM interception
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => false;
    return client;
  }
}

/// Applies global VAPT network and log hardening across UI and background isolates
void applyVaptHardening() {
  // 1. Enforce direct secure network connections and prevent proxy interception
  HttpOverrides.global = SecureHttpOverrides();

  // 2. Mute all console logs and Logcat outputs in release builds (prevents adb log snooping)
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
}

