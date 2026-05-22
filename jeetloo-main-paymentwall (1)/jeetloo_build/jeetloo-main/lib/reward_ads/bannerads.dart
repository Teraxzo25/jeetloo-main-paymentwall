import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

// ─────────────────────────────────────────────────────────────
// UNITY ADS HELPER — compatible with unity_ads_plugin ^4.0.1
// Game ID: 800000457
// Banner:       Banner_Android
// Rewarded:     Rewarded_Android
// Interstitial: Interstitial_Android
// ─────────────────────────────────────────────────────────────

class AdmobHelper {
  static const String _gameId = '800000457';
  static const String bannerPlacementId = 'Banner_Android';
  static const String rewardedPlacementId = 'Rewarded_Android';
  static const String interstitialPlacementId = 'Interstitial_Android';

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await UnityAds.init(
      gameId: _gameId,
      testMode: false,
      onComplete: () {
        _initialized = true;
        print('Unity Ads initialized');
      },
      onFailed: (error, message) =>
          print('Unity Ads init failed: $error $message'),
    );
  }
}
