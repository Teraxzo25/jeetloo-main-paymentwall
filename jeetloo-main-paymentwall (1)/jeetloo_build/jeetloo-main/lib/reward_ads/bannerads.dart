import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

// ─────────────────────────────────────────────────────────────
// UNITY ADS — compatible with unity_ads_plugin ^0.3.30
// Game ID: 800000457
// ─────────────────────────────────────────────────────────────

class AdmobHelper {
  static const String _gameId = '800000457';
  static const String bannerPlacementId = 'Banner_Android';
  static const String rewardedPlacementId = 'Rewarded_Android';
  static const String interstitialPlacementId = 'Interstitial_Android';

  // ⚠️ testMode: true  → use while developing/testing (shows test ads on any device)
  // ⚠️ testMode: false → use only when releasing to production on Google Play
  static const bool _testMode = true;

  static Future<void> initialize() async {
    await UnityAds.init(
      gameId: _gameId,
      testMode: _testMode,
      onComplete: () => print('✅ Unity Ads initialized (testMode: $_testMode)'),
      onFailed: (error, message) => print('❌ Unity Ads init failed: $message'),
    );
  }
}

class UnityBannerAdWidget extends StatefulWidget {
  const UnityBannerAdWidget({Key? key}) : super(key: key);

  @override
  State<UnityBannerAdWidget> createState() => _UnityBannerAdWidgetState();
}

class _UnityBannerAdWidgetState extends State<UnityBannerAdWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: UnityBannerAd(
        placementId: AdmobHelper.bannerPlacementId,
        onLoad: (placementId) => print('Banner loaded'),
        onClick: (placementId) => print('Banner clicked'),
        onFailed: (placementId, error, message) =>
            print('Banner failed: $message'),
      ),
    );
  }
}
