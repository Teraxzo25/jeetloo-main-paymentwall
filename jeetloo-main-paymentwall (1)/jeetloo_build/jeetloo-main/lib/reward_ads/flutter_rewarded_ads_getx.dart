import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

// ─────────────────────────────────────────────────────────────
// REWARDED ADS CONTROLLER — powered by Unity Ads
// NOTE: Unity Ads is already initialized in main.dart via
// AdmobHelper.initialize(). This controller only loads & shows.
// Game ID: 800000457
// ─────────────────────────────────────────────────────────────

class RewardedAdsController extends GetxController {
  var rewardPoints = 0.obs;
  var isAdLoading = false.obs;
  var isAdReady = false.obs;

  Function(int points)? onRewardEarnedCallback;

  static const String _rewardedPlacementId = 'Rewarded_Android';

  @override
  void onInit() {
    super.onInit();
    // Small delay to ensure Unity Ads has finished initializing in main.dart
    Future.delayed(const Duration(seconds: 2), () => loadAd());
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
        print('❌ Rewarded ad failed to load [$error]: $message');
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
        'Please wait a moment and try again',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isAdReady.value = false;

    UnityAds.showVideoAd(
      placementId: _rewardedPlacementId,
      onComplete: (placementId) {
        print('🎉 Rewarded ad completed');
        const int rewardAmount = 10;
        rewardPoints.value += rewardAmount;
        onRewardEarnedCallback?.call(rewardAmount);
        loadAd(); // preload next
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
        loadAd();
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

  void setOnRewardEarnedCallback(Function(int points) callback) {
    onRewardEarnedCallback = callback;
  }

  void resetPoints() {
    rewardPoints.value = 0;
  }
}
