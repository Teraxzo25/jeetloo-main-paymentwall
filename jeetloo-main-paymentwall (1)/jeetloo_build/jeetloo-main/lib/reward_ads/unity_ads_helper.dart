import 'package:unity_ads_plugin/unity_ads_plugin.dart';

// ─────────────────────────────────────────────────────────────
// UNITY ADS HELPER
// Game ID: 800000457
// ─────────────────────────────────────────────────────────────

class UnityAdsHelper {
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
      testMode: false, // set to true for testing
      onComplete: () {
        _initialized = true;
      },
      onFailed: (error, message) {
        print('Unity Ads init failed: $message');
      },
    );
  }

  // Load interstitial ad
  static void loadInterstitial({
    VoidCallback? onLoaded,
    Function(String)? onFailed,
  }) {
    UnityAds.load(
      placementId: interstitialPlacementId,
      onComplete: (placementId) => onLoaded?.call(),
      onFailed: (placementId, error, message) => onFailed?.call(message),
    );
  }

  // Show interstitial ad
  static void showInterstitial({
    VoidCallback? onComplete,
    VoidCallback? onSkipped,
    Function(String)? onFailed,
  }) {
    UnityAds.showVideoAd(
      placementId: interstitialPlacementId,
      onComplete: (placementId) => onComplete?.call(),
      onSkipped: (placementId) => onSkipped?.call(),
      onFailed: (placementId, error, message) => onFailed?.call(message),
    );
  }

  // Load rewarded ad
  static void loadRewarded({
    VoidCallback? onLoaded,
    Function(String)? onFailed,
  }) {
    UnityAds.load(
      placementId: rewardedPlacementId,
      onComplete: (placementId) => onLoaded?.call(),
      onFailed: (placementId, error, message) => onFailed?.call(message),
    );
  }

  // Show rewarded ad
  static void showRewarded({
    VoidCallback? onRewarded,
    VoidCallback? onSkipped,
    Function(String)? onFailed,
  }) {
    UnityAds.showVideoAd(
      placementId: rewardedPlacementId,
      onComplete: (placementId) => onRewarded?.call(),
      onSkipped: (placementId) => onSkipped?.call(),
      onFailed: (placementId, error, message) => onFailed?.call(message),
    );
  }
}
