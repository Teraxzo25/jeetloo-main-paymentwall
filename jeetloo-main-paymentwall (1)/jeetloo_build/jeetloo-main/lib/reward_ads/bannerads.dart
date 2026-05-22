import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

// ─────────────────────────────────────────────────────────────
// UNITY ADS HELPER
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

  static Future<void> initialize() async {
    await UnityAds.init(
      gameId: _gameId,
      testMode: false,
      onComplete: () => print('Unity Ads initialized'),
      onFailed: (error, message) => print('Unity Ads failed: $message'),
    );
  }
}

// Banner Ad Widget
class UnityBannerAdWidget extends StatelessWidget {
  const UnityBannerAdWidget({Key? key}) : super(key: key);

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
