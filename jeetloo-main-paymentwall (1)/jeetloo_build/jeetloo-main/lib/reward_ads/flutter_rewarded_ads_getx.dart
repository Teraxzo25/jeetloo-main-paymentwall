import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

// ─────────────────────────────────────────────────────────────
// REWARDED ADS CONTROLLER — powered by Unity Ads
// Replaces the old google_mobile_ads implementation.
// home.dart uses this with NO changes needed there.
// Game ID: 800000457
// ─────────────────────────────────────────────────────────────

class RewardedAdsController extends GetxController {
  // Observable variables (same API as before)
  var rewardPoints = 0.obs;
  var isAdLoading = false.obs;
  var isAdReady = false.obs;

  // Callback for when reward is earned
  Function(int points)? onRewardEarnedCallback;

  static const String _rewardedPlacementId = 'Rewarded_Android';

  @override
  void onInit() {
    super.onInit();
    _initAndLoad();
  }

  /// Initialise Unity Ads then load the rewarded placement
  Future<void> _initAndLoad() async {
    await UnityAds.init(
      gameId: '800000457',
      testMode: false, // set to true while testing
      onComplete: () {
        print('✅ Unity Ads initialised');
        loadAd();
      },
      onFailed: (error, message) {
        print('❌ Unity Ads init failed: $message');
      },
    );
  }

  /// Load a rewarded ad
  void loadAd() {
    isAdLoading.value = true;
    isAdReady.value = false;

    UnityAds.load(
      placementId: _rewardedPlacementId,
      onComplete: (placementId) {
        print('✅ Rewarded ad loaded: $placementId');
        isAdLoading.value = false;
        isAdReady.value = true;
      },
      onFailed: (placementId, error, message) {
        print('❌ Rewarded ad failed to load: $message');
        isAdLoading.value = false;
        isAdReady.value = false;

        // Retry after 30 seconds
        Future.delayed(const Duration(seconds: 30), () {
          if (!isAdReady.value) loadAd();
        });
      },
    );
  }

  /// Show rewarded ad
  void showAd() {
    if (!isAdReady.value) {
      Get.snackbar(
        'Ad Not Ready',
        'Please wait for the ad to load',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isAdReady.value = false; // mark as used while showing

    UnityAds.showVideoAd(
      placementId: _rewardedPlacementId,
      onComplete: (placementId) {
        print('🎉 Rewarded ad completed: $placementId');
        const int rewardAmount = 10; // adjust points per ad view as needed
        rewardPoints.value += rewardAmount;

        if (onRewardEarnedCallback != null) {
          onRewardEarnedCallback!(rewardAmount);
        }

        Get.snackbar(
          'Reward Earned!',
          'You earned $rewardAmount points!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );

        loadAd(); // Preload next ad
      },
      onSkipped: (placementId) {
        print('⏭ Rewarded ad skipped');
        Get.snackbar(
          'Ad Skipped',
          'Watch the full ad to earn points',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        loadAd(); // Reload for next attempt
      },
      onFailed: (placementId, error, message) {
        print('❌ Rewarded ad failed to show: $message');
        Get.snackbar(
          'Ad Error',
          'Something went wrong. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        loadAd();
      },
      onStart: (placementId) => print('▶ Ad started'),
      onClick: (placementId) => print('👆 Ad clicked'),
    );
  }

  /// Assign the callback from the UI (called by home.dart)
  void setOnRewardEarnedCallback(Function(int points) callback) {
    onRewardEarnedCallback = callback;
  }

  /// Optional: Reset reward points
  void resetPoints() {
    rewardPoints.value = 0;
    Get.snackbar(
      'Points Reset',
      'Your reward points have been reset to 0',
      backgroundColor: Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
