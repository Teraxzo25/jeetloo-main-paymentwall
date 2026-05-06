import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdsController extends GetxController {
  // Observable variables
  var rewardPoints = 0.obs;
  var isAdLoading = false.obs;
  var isAdReady = false.obs;

  RewardedAd? _rewardedAd;

  // Callback for when reward is earned
  late Function(int points)? onRewardEarnedCallback;

  // Ad unit IDs (replace with real ones for production)
  final String adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917' // Android test ad
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS test ad

  @override
  void onInit() {
    super.onInit();
    loadAd();
  }

  @override
  void onClose() {
    _rewardedAd?.dispose();
    super.onClose();
  }

  /// Load a rewarded ad
  void loadAd() {
    isAdLoading.value = true;
    isAdReady.value = false;

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ Rewarded ad loaded successfully');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              print('Ad showing full screen');
            },
            onAdImpression: (ad) {
              print('Ad impression recorded');
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ Ad failed to show: $error');
              ad.dispose();
              _rewardedAd = null;
              loadAd();
            },
            onAdDismissedFullScreenContent: (ad) {
              print('Ad dismissed');
              ad.dispose();
              _rewardedAd = null;
              loadAd(); // Preload next ad
            },
            onAdClicked: (ad) {
              print('Ad clicked');
            },
          );

          _rewardedAd = ad;
          isAdLoading.value = false;
          isAdReady.value = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('❌ RewardedAd failed to load: $error');
          isAdLoading.value = false;
          isAdReady.value = false;

          // Retry after 30 seconds
          Future.delayed(const Duration(seconds: 30), () {
            if (!isAdReady.value) {
              loadAd();
            }
          });
        },
      ),
    );
  }

  /// Show rewarded ad
  void showAd() {
    if (_rewardedAd == null) {
      Get.snackbar(
        'Ad Not Ready',
        'Please wait for the ad to load',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
        int rewardAmount = rewardItem.amount.toInt();
        rewardPoints.value += rewardAmount;

        print('🎉 Reward earned: $rewardAmount');

        // ✅ Trigger the callback
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
      },
    );
  }

  /// Assign the callback from the UI
  void setOnRewardEarnedCallback(Function(int points) callback) {
    onRewardEarnedCallback = callback;
  }

  /// Optional: Reset reward points (UI use only)
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
