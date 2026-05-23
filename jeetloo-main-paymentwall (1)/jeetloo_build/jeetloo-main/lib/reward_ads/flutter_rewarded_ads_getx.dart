import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

// ─────────────────────────────────────────────────────────────
// REWARDED ADS CONTROLLER — Unity Ads
// ─────────────────────────────────────────────────────────────

class RewardedAdsController extends GetxController {
  var rewardPoints = 0.obs;
  var isAdReady = false.obs;

  static const String _placementId = 'Rewarded_Android';

  late Function(int points)? onRewardEarnedCallback;

  @override
  void onInit() {
    super.onInit();
    _loadAd();
  }

  void _loadAd() {
    UnityAds.load(
      placementId: _placementId,
      onComplete: (placementId) {
        print('Rewarded ad loaded');
        isAdReady.value = true;
      },
      onFailed: (placementId, error, message) {
        print('Rewarded ad failed to load: $message');
        isAdReady.value = false;
      },
    );
  }

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

    UnityAds.showVideoAd(
      placementId: _placementId,
      onComplete: (placementId) {
        rewardPoints.value += 50;
        if (onRewardEarnedCallback != null) {
          onRewardEarnedCallback!(50);
        }
        Get.snackbar(
          'Reward Earned!',
          'You earned 50 points!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        isAdReady.value = false;
        _loadAd();
      },
      onFailed: (placementId, error, message) {
        print('Rewarded ad failed to show: $message');
        _loadAd();
      },
      onStart: (placementId) => print('Rewarded ad started'),
      onClick: (placementId) => print('Rewarded ad clicked'),
      onSkipped: (placementId) {
        print('Rewarded ad skipped');
        _loadAd();
      },
    );
  }

  void setOnRewardEarnedCallback(Function(int points) callback) {
    onRewardEarnedCallback = callback;
  }

  void resetPoints() {
    rewardPoints.value = 0;
  }
}
