import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

// ─────────────────────────────────────────────────────────────
// UNITY ADS HELPER
// Game ID: 800000457
// Banner: Banner_Android
// Rewarded: Rewarded_Android
// Interstitial: Interstitial_Android
// ─────────────────────────────────────────────────────────────

class AdmobHelper {
  static const String _gameId = '800000457';
  static const String bannerPlacementId = 'Banner_Android';
  static const String rewardedPlacementId = 'Rewarded_Android';
  static const String interstitialPlacementId = 'Interstitial_Android';

  static bool _initialized = false;

  // Initialize Unity Ads
  static Future<void> initialize() async {
    if (_initialized) return;
    await UnityAds.init(
      gameId: _gameId,
      testMode: false,
      onComplete: () => _initialized = true,
      onFailed: (error, message) =>
          print('Unity Ads init failed: $error $message'),
    );
  }

  // Load interstitial ad
  static void loadInterstitial() {
    UnityAds.load(
      placementId: interstitialPlacementId,
      onComplete: (placementId) => print('Interstitial loaded'),
      onFailed: (placementId, error, message) =>
          print('Interstitial load failed: $message'),
    );
  }

  // Show interstitial ad
  static void showInterstitial() {
    UnityAds.showVideoAd(
      placementId: interstitialPlacementId,
      onComplete: (placementId) => print('Interstitial complete'),
      onFailed: (placementId, error, message) =>
          print('Interstitial show failed: $message'),
      onStart: (placementId) => print('Interstitial started'),
      onClick: (placementId) => print('Interstitial clicked'),
      onSkipped: (placementId) => print('Interstitial skipped'),
    );
  }

  // Show rewarded ad
  static void showRewarded({required Function() onRewarded}) {
    UnityAds.showVideoAd(
      placementId: rewardedPlacementId,
      onComplete: (placementId) => onRewarded(),
      onFailed: (placementId, error, message) =>
          print('Rewarded show failed: $message'),
      onStart: (placementId) => print('Rewarded started'),
      onClick: (placementId) => print('Rewarded clicked'),
      onSkipped: (placementId) => print('Rewarded skipped'),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// UNITY BANNER AD WIDGET
// Drop this anywhere in the widget tree to show a banner
// ─────────────────────────────────────────────────────────────

class UnityBannerAd extends StatefulWidget {
  const UnityBannerAd({Key? key}) : super(key: key);

  @override
  _UnityBannerAdState createState() => _UnityBannerAdState();
}

class _UnityBannerAdState extends State<UnityBannerAd> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: UnityBannerAd(
        placementId: AdmobHelper.bannerPlacementId,
        onLoad: (placementId) => setState(() => _loaded = true),
        onClick: (placementId) => print('Banner clicked'),
        onFailed: (placementId, error, message) =>
            print('Banner failed: $message'),
      ),
    );
  }
}
